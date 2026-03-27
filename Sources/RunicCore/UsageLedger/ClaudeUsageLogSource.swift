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
    private let maxAgeDays: Int?
    private let now: Date
    private let log: RunicLogger

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        basePaths: [URL]? = nil,
        maxAgeDays: Int? = 3,
        now: Date = Date(),
        log: RunicLogger = RunicLog.logger("claude-usage-ledger"))
    {
        self.environment = environment
        self.fileManager = fileManager
        self.basePaths = basePaths
        self.maxAgeDays = maxAgeDays
        self.now = now
        self.log = log
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        let projectsDirs = try self.resolveProjectsDirectories()
        if projectsDirs.isEmpty {
            throw ClaudeUsageLogError.noProjectsDirectory
        }

        // Only scan files modified since our last scan (incremental).
        // On first run, scans the last `maxAgeDays` worth of files.
        let cache = LedgerCache.shared
        let lastScan = await cache.lastScanDate(provider: "claude")
        let incrementalCutoff = lastScan ?? self.minDate() ?? self.now.addingTimeInterval(-86400)
        let minDate = self.minDate()

        let allFiles = self.findUsageFiles(in: projectsDirs, minDate: minDate)

        // Filter to only files modified since last scan (plus today's files which may have grown).
        let todayStart = Calendar.current.startOfDay(for: self.now)
        let filesToScan = allFiles.filter { file in
            guard let modDate = (try? self.fileManager
                .attributesOfItem(atPath: file.url.path))?[.modificationDate] as? Date
            else {
                return true
            }
            return modDate >= incrementalCutoff || modDate >= todayStart
        }

        if filesToScan.isEmpty {
            return []
        }

        self.log
            .info(
                "Scanning \(filesToScan.count) of \(allFiles.count) JSONL files (incremental since \(incrementalCutoff))")

        // Parse files concurrently (max 16 at a time).
        let maxConcurrency = 16
        let fileEntries = await withTaskGroup(
            of: [UsageLedgerEntry].self,
            returning: [UsageLedgerEntry].self)
        { group in
            var all: [UsageLedgerEntry] = []
            var inflight = 0
            for file in filesToScan {
                if inflight >= maxConcurrency {
                    if let batch = await group.next() {
                        all.append(contentsOf: batch)
                        inflight -= 1
                    }
                }
                group.addTask {
                    self.parseFile(file, minDate: minDate)
                }
                inflight += 1
            }
            for await batch in group {
                all.append(contentsOf: batch)
            }
            return all
        }

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
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                cacheCreationTokens: entry.cacheCreationTokens,
                cacheReadTokens: entry.cacheReadTokens)
            if seenKeys.insert(key).inserted {
                entries.append(entry)
            }
        }

        // Aggregate into daily summaries and persist to cache.
        let dailyFormatter = DateFormatter()
        dailyFormatter.dateFormat = "yyyy-MM-dd"
        dailyFormatter.timeZone = .current

        var dailyBuckets: [String: (
            input: Int,
            output: Int,
            cacheCreate: Int,
            cacheRead: Int,
            cost: Double,
            requests: Int,
            models: Set<String>)] = [:]
        for entry in entries {
            let key = dailyFormatter.string(from: entry.timestamp)
            var bucket = dailyBuckets[key] ?? (0, 0, 0, 0, 0, 0, [])
            bucket.input += entry.inputTokens
            bucket.output += entry.outputTokens
            bucket.cacheCreate += entry.cacheCreationTokens
            bucket.cacheRead += entry.cacheReadTokens
            bucket.cost += entry.costUSD ?? 0
            bucket.requests += 1
            if let model = entry.model { bucket.models.insert(model) }
            dailyBuckets[key] = bucket
        }

        let cachedDailies = dailyBuckets.map { key, bucket in
            CachedDaily(
                dayKey: key,
                inputTokens: bucket.input,
                outputTokens: bucket.output,
                cacheCreationTokens: bucket.cacheCreate,
                cacheReadTokens: bucket.cacheRead,
                costUSD: bucket.cost > 0 ? bucket.cost : nil,
                requestCount: bucket.requests,
                modelsUsed: Array(bucket.models))
        }

        let todayKey = await LedgerCache.dayKey(for: self.now)
        await cache.mergeDailies(provider: "claude", newDailies: cachedDailies, scanDate: self.now, todayKey: todayKey)

        return entries
    }

    /// Parse a single JSONL file, returning usage entries.
    private func parseFile(_ file: UsageFile, minDate: Date?) -> [UsageLedgerEntry] {
        var entries: [UsageLedgerEntry] = []
        do {
            let data = try Data(contentsOf: file.url)
            guard let content = String(data: data, encoding: .utf8) else { return [] }
            var seenKeys = Set<String>()
            let lines = content.split(whereSeparator: \.isNewline)
            for line in lines {
                if let entry = self.parseLine(line, file: file, minDate: minDate, seenKeys: &seenKeys) {
                    entries.append(entry)
                }
            }
        } catch {
            self.log.warning("Claude usage log read failed", metadata: [
                "file": file.url.path,
                "error": error.localizedDescription,
            ])
        }
        return entries
    }

    private struct UsageFile {
        let url: URL
        let projectID: String?
        let projectName: String?
        let sessionID: String?
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

    private func parseLine(
        _ line: Substring,
        file: UsageFile,
        minDate: Date?,
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
            let computedCost = payload.costUSD ?? payload.message.model.flatMap { model in
                CostUsagePricing.claudeCostUSD(
                    model: model,
                    inputTokens: input,
                    cacheReadInputTokens: cacheRead,
                    cacheCreationInputTokens: cacheCreation,
                    outputTokens: output)
            }
            let key = self.dedupeKey(
                requestID: payload.requestId,
                messageID: payload.message.id,
                sessionID: sessionID,
                timestamp: timestamp,
                inputTokens: input,
                outputTokens: output,
                cacheCreationTokens: cacheCreation,
                cacheReadTokens: cacheRead)
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
                source: .claudeLog)
        } catch {
            return nil
        }
    }

    private func dedupeKey(
        requestID: String?,
        messageID: String?,
        sessionID: String?,
        timestamp: Date,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int) -> String
    {
        if let requestID, !requestID.isEmpty {
            return "req:\(requestID)"
        }
        if let messageID, !messageID.isEmpty {
            return "msg:\(messageID)"
        }
        return "ts:\(timestamp.timeIntervalSince1970)|\(sessionID ?? "-")|\(inputTokens)|\(outputTokens)|\(cacheCreationTokens)|\(cacheReadTokens)"
    }

    private func minDate() -> Date? {
        guard let maxAgeDays, maxAgeDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: self.now)
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
