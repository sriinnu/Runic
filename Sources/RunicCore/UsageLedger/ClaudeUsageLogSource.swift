import Foundation

public struct ClaudeUsageLogSource: UsageLedgerSource, @unchecked Sendable {
    public enum ClaudeUsageLogError: LocalizedError, Sendable {
        case noProjectsDirectory
        case readFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noProjectsDirectory:
                "No Claude projects directory found."
            case let .readFailed(reason):
                "Failed to read Claude usage logs: \(reason)"
            }
        }
    }

    private let environment: [String: String]
    private let fileManager: FileManager
    private let basePaths: [URL]?
    private let now: Date
    private let log: RunicLogger
    private let cache: LedgerCache
    private let scanMode: UsageLedgerLogScanMode

    private struct DedupeTokens {
        let input: Int
        let output: Int
        let cacheCreation: Int
        let cacheRead: Int
    }

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        basePaths: [URL]? = nil,
        maxAgeDays: Int? = 3,
        now: Date = Date(),
        log: RunicLogger = RunicLog.logger("claude-usage-ledger"),
        cache: LedgerCache = .shared,
        scanMode: UsageLedgerLogScanMode = .refreshToday)
    {
        self.environment = environment
        self.fileManager = fileManager
        self.basePaths = basePaths
        self.now = now
        self.log = log
        self.cache = cache
        self.scanMode = scanMode
        _ = maxAgeDays // Retained for source compatibility; scanMode controls history reads.
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        let projectsDirs = try self.resolveProjectsDirectories()
        if projectsDirs.isEmpty {
            throw ClaudeUsageLogError.noProjectsDirectory
        }

        // Relay contract: normal refresh never reopens historical provider
        // JSONLs. Explicit rebuild mode is the repair path that opts into
        // historical reads and commits empty day snapshots for missing raw data.
        let cache = self.cache
        let todayKey = LedgerCache.dayKey(for: self.now)
        let window = self.scanWindow(todayKey: todayKey)
        let allFiles = self.findUsageFiles(in: projectsDirs, minDate: window.fileMinModificationDate)

        // Claude keeps long-lived project JSONLs. Normal refresh opens only
        // files touched today, then line-filters by timestamp so old rows stay
        // historical relay data.
        let filesToScan = if window.requireTouchedAfterMinDate {
            allFiles.filter { file in
                guard let modDate = (try? self.fileManager
                    .attributesOfItem(atPath: file.url.path))?[.modificationDate] as? Date
                else {
                    return true
                }
                return modDate >= window.minDate
            }
        } else {
            allFiles
        }

        if filesToScan.isEmpty {
            await cache.mergeEntries(
                provider: "claude",
                entries: [],
                scanDate: self.now,
                todayKey: window.relayTodayKey,
                coveredMaxAgeDays: window.coveredMaxAgeDays,
                sourceWatermarks: window.completionWatermarks)
            return []
        }

        self.log
            .info(
                "Scanning \(filesToScan.count) of \(allFiles.count) JSONL files touched today")

        // Parse files concurrently (max 16 at a time).
        let maxConcurrency = 16
        let parsedFiles = try await withThrowingTaskGroup(
            of: ParsedUsageFile.self,
            returning: [ParsedUsageFile].self)
        { group in
            var all: [ParsedUsageFile] = []
            var inflight = 0
            for file in filesToScan {
                if inflight >= maxConcurrency {
                    if let parsed = try await group.next() {
                        all.append(parsed)
                        inflight -= 1
                    }
                }
                group.addTask {
                    try self.parseFile(file, minDate: window.minDate, dayKey: window.fileWatermarkDayKey)
                }
                inflight += 1
            }
            while let parsed = try await group.next() {
                all.append(parsed)
            }
            return all
        }
        let fileEntries = parsedFiles.flatMap(\.entries)

        // Deduplicate across files using the same composite key as per-file dedup.
        var seenKeys = Set<String>()
        var entries: [UsageLedgerEntry] = []
        entries.reserveCapacity(fileEntries.count)
        for entry in fileEntries {
            let key = self.dedupeKey(
                requestID: entry.requestID,
                messageID: entry.messageID,
                sessionID: entry.sessionID,
                timestamp: entry.timestamp,
                tokens: .init(
                    input: entry.inputTokens,
                    output: entry.outputTokens,
                    cacheCreation: entry.cacheCreationTokens,
                    cacheRead: entry.cacheReadTokens))
            if seenKeys.insert(key).inserted {
                entries.append(entry)
            }
        }

        let sourceWatermarks = window.completionWatermarks + parsedFiles.map(\.watermark)
        await cache.mergeEntries(
            provider: "claude",
            entries: entries,
            scanDate: self.now,
            todayKey: window.relayTodayKey,
            coveredMaxAgeDays: window.coveredMaxAgeDays,
            sourceWatermarks: sourceWatermarks)

        return entries
    }

    /// Parse a single JSONL file, returning usage entries.
    private func parseFile(_ file: UsageFile, minDate: Date?, dayKey: String?) throws -> ParsedUsageFile {
        var entries: [UsageLedgerEntry] = []
        var seenKeys = Set<String>()
        let sourceMetadata = self.sourceMetadata(for: file.url)
        let sourceFingerprint = self.sourceFingerprint(for: sourceMetadata)

        func consume(_ lineData: Data) {
            guard !lineData.isEmpty,
                  let line = String(data: lineData, encoding: .utf8)?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                  !line.isEmpty
            else { return }
            if let entry = self.parseLine(
                line[...],
                file: file,
                minDate: minDate,
                sourceFingerprint: sourceFingerprint,
                seenKeys: &seenKeys)
            {
                entries.append(entry)
            }
        }

        do {
            try CostUsageJsonl.scan(
                fileURL: file.url,
                maxLineBytes: 512 * 1024,
                prefixBytes: 512 * 1024)
            { line in
                guard !line.wasTruncated else { return }
                consume(line.bytes)
            }
        } catch {
            throw ClaudeUsageLogError.readFailed("\(file.url.path): \(error.localizedDescription)")
        }
        let latestMetadata = self.sourceMetadata(for: file.url)
        guard latestMetadata == sourceMetadata else {
            throw ClaudeUsageLogError.readFailed("Claude usage log changed while scanning: \(sourceMetadata.path)")
        }
        return ParsedUsageFile(
            entries: entries,
            watermark: self.sourceWatermark(for: sourceMetadata, dayKey: dayKey))
    }

    private struct UsageFile {
        let url: URL
        let projectID: String?
        let projectName: String?
        let sessionID: String?
    }

    private struct ParsedUsageFile {
        let entries: [UsageLedgerEntry]
        let watermark: UsageRelaySourceWatermark
    }

    private struct SourceFileMetadata: Equatable {
        let path: String
        let modifiedAt: Date?
        let sizeBytes: Int64?
    }

    private struct ScanWindow {
        let minDate: Date
        let fileMinModificationDate: Date?
        let requireTouchedAfterMinDate: Bool
        let relayTodayKey: String?
        let coveredMaxAgeDays: Int?
        let completionWatermarks: [UsageRelaySourceWatermark]
        let fileWatermarkDayKey: String?
    }

    private func scanWindow(todayKey: String) -> ScanWindow {
        let calendar = Calendar.current
        switch self.scanMode {
        case .refreshToday:
            let todayStart = calendar.startOfDay(for: self.now)
            return ScanWindow(
                minDate: todayStart,
                fileMinModificationDate: todayStart,
                requireTouchedAfterMinDate: true,
                relayTodayKey: todayKey,
                coveredMaxAgeDays: nil,
                completionWatermarks: [],
                fileWatermarkDayKey: todayKey)
        case let .rebuildHistory(maxAgeDays):
            let days = max(1, maxAgeDays)
            let todayStart = calendar.startOfDay(for: self.now)
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart
            let dayKeys = (0..<days).compactMap { offset -> String? in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                return LedgerCache.dayKey(for: date)
            }
            let watermarks = dayKeys.map { dayKey in
                UsageRelaySourceWatermark(
                    dayKey: dayKey,
                    sourceKind: "claude-jsonl-rebuild",
                    sourceID: "rebuild:claude:\(dayKey)",
                    sourceFingerprint: "rebuild:claude:\(dayKey):\(Int(self.now.timeIntervalSince1970))")
            }
            return ScanWindow(
                minDate: start,
                fileMinModificationDate: nil,
                requireTouchedAfterMinDate: false,
                relayTodayKey: nil,
                coveredMaxAgeDays: days,
                completionWatermarks: watermarks,
                fileWatermarkDayKey: nil)
        }
    }

    private func resolveProjectsDirectories() throws -> [URL] {
        if let basePaths { return self.normalizePaths(basePaths) }

        let envPaths = self.environment["CLAUDE_CONFIG_DIR"]?.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        var candidates: [URL] = []
        if !envPaths.isEmpty {
            candidates = envPaths.map { self.expandTilde(path: String($0)) }
        } else {
            let home = self.fileManager.homeDirectoryForCurrentUser
            candidates = [
                home.appendingPathComponent(".config/claude", isDirectory: true),
                home.appendingPathComponent(".claude", isDirectory: true),
            ]
        }

        return candidates
            .map { $0.appendingPathComponent("projects", isDirectory: true) }
            .filter { self.fileManager.directoryExists(at: $0) }
    }

    private func normalizePaths(_ urls: [URL]) -> [URL] {
        urls.map(\.standardizedFileURL)
            .filter { self.fileManager.directoryExists(at: $0) }
            .map { $0.appendingPathComponent("projects", isDirectory: true) }
            .filter { self.fileManager.directoryExists(at: $0) }
    }

    private func findUsageFiles(in projectsDirs: [URL], minDate: Date?) -> [UsageFile] {
        var results: [UsageFile] = []

        for projectsDir in projectsDirs {
            let enumerator = self.fileManager.enumerator(
                at: projectsDir,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles])

            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.pathExtension == "jsonl" else { continue }
                if let minDate {
                    let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modifiedAt = values?.contentModificationDate, modifiedAt < minDate { continue }
                }
                let pathComponents = fileURL.pathComponents
                guard let projectsIndex = pathComponents.lastIndex(of: "projects"),
                      projectsIndex + 2 < pathComponents.count
                else {
                    results.append(UsageFile(url: fileURL, projectID: nil, projectName: nil, sessionID: nil))
                    continue
                }
                let projectID = pathComponents[projectsIndex + 1]
                let projectName = self.derivedProjectName(from: projectID)
                let sessionID = pathComponents[projectsIndex + 2]
                results.append(UsageFile(
                    url: fileURL,
                    projectID: projectID,
                    projectName: projectName,
                    sessionID: sessionID))
            }
        }

        return results
    }

    private func sourceWatermark(for metadata: SourceFileMetadata, dayKey: String?) -> UsageRelaySourceWatermark {
        return UsageRelaySourceWatermark(
            dayKey: dayKey,
            sourceKind: "claude-jsonl",
            sourceID: metadata.path,
            sourceFingerprint: self.sourceFingerprint(for: metadata),
            path: metadata.path,
            modifiedAt: metadata.modifiedAt,
            sizeBytes: metadata.sizeBytes)
    }

    private func sourceFingerprint(for metadata: SourceFileMetadata) -> String {
        let modifiedMillis = metadata.modifiedAt.map { Int64($0.timeIntervalSince1970 * 1000) } ?? -1
        return "\(metadata.path)|\(metadata.sizeBytes ?? -1)|\(modifiedMillis)"
    }

    private func sourceMetadata(for url: URL) -> SourceFileMetadata {
        let standardized = url.standardizedFileURL
        let values = try? standardized.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return SourceFileMetadata(
            path: standardized.path,
            modifiedAt: values?.contentModificationDate,
            sizeBytes: values?.fileSize.map { Int64($0) })
    }

    private func parseLine(
        _ line: Substring,
        file: UsageFile,
        minDate: Date?,
        sourceFingerprint: String,
        seenKeys: inout Set<String>) -> UsageLedgerEntry?
    {
        let text = String(line)
        guard let data = text.data(using: .utf8) else { return nil }
        do {
            let payload = try JSONDecoder().decode(ClaudeUsageLogLine.self, from: data)
            if payload.isApiErrorMessage == true { return nil }
            guard let timestamp = parseTimestamp(payload.timestamp) else { return nil }
            if let minDate, timestamp < minDate { return nil }
            let usage = payload.message.usage
            let input = max(0, usage.inputTokens)
            let output = max(0, usage.outputTokens)
            let cacheCreation = max(0, usage.cacheCreationInputTokens ?? 0)
            let cacheRead = max(0, usage.cacheReadInputTokens ?? 0)
            let total = input + output + cacheCreation + cacheRead
            guard total > 0 else { return nil }

            let sessionID = payload.sessionId ?? file.sessionID
            let pricingCost = payload.message.model.flatMap { model in
                CostUsagePricing.claudeCostUSD(
                    model: model,
                    inputTokens: input,
                    cacheReadInputTokens: cacheRead,
                    cacheCreationInputTokens: cacheCreation,
                    outputTokens: output)
            }
            let computedCost = payload.costUSD ?? pricingCost
            let costProvenance: MetricProvenance? = if payload.costUSD != nil {
                MetricProvenance(
                    confidence: .providerReported,
                    source: .localLog,
                    detail: "Claude JSONL cost field")
            } else if pricingCost != nil {
                MetricProvenance(
                    confidence: .estimated,
                    source: .pricingTable,
                    detail: "Claude token pricing fallback")
            } else {
                nil
            }
            let key = self.dedupeKey(
                requestID: payload.requestId,
                messageID: payload.message.id,
                sessionID: sessionID,
                timestamp: timestamp,
                tokens: .init(
                    input: input,
                    output: output,
                    cacheCreation: cacheCreation,
                    cacheRead: cacheRead))
            if seenKeys.contains(key) { return nil }
            seenKeys.insert(key)

            return UsageLedgerEntry(
                provider: .claude,
                timestamp: timestamp,
                sessionID: sessionID,
                projectID: file.projectID,
                projectName: file.projectName,
                model: payload.message.model,
                inputTokens: input,
                outputTokens: output,
                cacheCreationTokens: cacheCreation,
                cacheReadTokens: cacheRead,
                costUSD: computedCost,
                requestID: payload.requestId,
                messageID: payload.message.id,
                version: payload.version,
                source: .claudeLog,
                tokenProvenance: MetricProvenance(
                    confidence: .exact,
                    source: .localLog,
                    detail: "Claude JSONL message.usage"),
                costProvenance: costProvenance,
                sourceFingerprint: sourceFingerprint)
        } catch {
            return nil
        }
    }

    private func dedupeKey(
        requestID: String?,
        messageID: String?,
        sessionID: String?,
        timestamp: Date,
        tokens: DedupeTokens) -> String
    {
        if let requestID, !requestID.isEmpty {
            return "req:\(requestID)"
        }
        if let messageID, !messageID.isEmpty {
            return "msg:\(messageID)"
        }
        return [
            "ts:\(timestamp.timeIntervalSince1970)",
            sessionID ?? "-",
            "\(tokens.input)",
            "\(tokens.output)",
            "\(tokens.cacheCreation)",
            "\(tokens.cacheRead)",
        ].joined(separator: "|")
    }

    private func parseTimestamp(_ value: String) -> Date? {
        let box = claudeISOFormatterBox
        box.lock.lock()
        defer { box.lock.unlock() }
        return box.iso.date(from: value) ?? box.fractional.date(from: value)
    }

    private func derivedProjectName(from projectID: String) -> String? {
        let trimmed = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let decoded = trimmed.removingPercentEncoding ?? trimmed
        let normalized = decoded.replacingOccurrences(of: "\\", with: "/")

        if normalized.contains("/") {
            let leaf = URL(fileURLWithPath: normalized).lastPathComponent
            if !leaf.isEmpty {
                return leaf
            }
        }
        return normalized
    }

    private func expandTilde(path: String) -> URL {
        if path.hasPrefix("~/") {
            let home = self.fileManager.homeDirectoryForCurrentUser
            let trimmed = String(path.dropFirst(2))
            return home.appendingPathComponent(trimmed, isDirectory: true)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}

private struct ClaudeUsageLogLine: Decodable {
    struct Message: Decodable {
        struct Usage: Decodable {
            let inputTokens: Int
            let outputTokens: Int
            let cacheCreationInputTokens: Int?
            let cacheReadInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
        }

        let usage: Usage
        let model: String?
        let id: String?
    }

    let timestamp: String
    let sessionId: String?
    let version: String?
    let message: Message
    let costUSD: Double?
    let requestId: String?
    let isApiErrorMessage: Bool?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case sessionId
        case version
        case message
        case costUSD
        case requestId
        case isApiErrorMessage
    }
}

private final class ClaudeISO8601FormatterBox: @unchecked Sendable {
    let lock = NSLock()
    let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private let claudeISOFormatterBox = ClaudeISO8601FormatterBox()

extension FileManager {
    fileprivate func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return self.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
