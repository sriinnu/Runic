import Foundation

public struct CodexUsageLogSource: UsageLedgerSource, @unchecked Sendable {
    public enum CodexUsageLogError: LocalizedError, Sendable {
        case noSessionsDirectory
        case readFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noSessionsDirectory:
                "No Codex sessions directory found."
            case let .readFailed(reason):
                "Failed to read Codex usage logs: \(reason)"
            }
        }
    }

    private struct SessionFile {
        let url: URL
        let sessionID: String?
        let modifiedAt: Date?
    }

    private struct SourceFileMetadata: Equatable {
        let path: String
        let modifiedAt: Date?
        let sizeBytes: Int64?
    }

    private struct CodexTotals {
        var input: Int
        var cached: Int
        var output: Int
    }

    private struct DedupeTokens {
        let input: Int
        let output: Int
        let cacheRead: Int
    }

    private struct ParseState {
        var currentModel: String?
        var currentProjectID: String?
        var currentProjectName: String?
        var previousTotals: CodexTotals?
    }

    private struct ParseContext {
        let file: SessionFile
        let minDate: Date?
        let sourceFingerprint: String
    }

    private struct ParsedLine {
        let object: [String: Any]
        let type: String
        let timestamp: Date
        let payload: [String: Any]?
    }

    private struct ProjectContext {
        let id: String?
        let name: String?
    }

    private struct TokenRecord {
        let timestamp: Date
        let sessionID: String?
        let projectID: String?
        let projectName: String?
        let model: String
        let tokens: CodexTotals
        let requestID: String?
        let version: String?
    }

    private static let projectIDKeys = [
        "project_id",
        "projectId",
        "workspace_id",
        "workspaceId",
        "workspace_slug",
        "workspaceSlug",
    ]

    private static let projectNameKeys = [
        "project_name",
        "projectName",
        "workspace_name",
        "workspaceName",
        "workspace_title",
        "workspaceTitle",
        "project_title",
        "projectTitle",
    ]

    private static let projectPathKeys = [
        "workspace_path",
        "workspacePath",
        "project_path",
        "projectPath",
        "repo_path",
        "repoPath",
        "root_path",
        "rootPath",
        "cwd",
        "working_directory",
        "workingDirectory",
    ]

    private let environment: [String: String]
    private let fileManager: FileManager
    private let sessionsRoot: URL?
    private let now: Date
    private let log: RunicLogger
    private let cache: LedgerCache
    private let scanMode: UsageLedgerLogScanMode

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        sessionsRoot: URL? = nil,
        maxAgeDays: Int? = 3,
        now: Date = Date(),
        log: RunicLogger = RunicLog.logger("codex-usage-ledger"),
        cache: LedgerCache = .shared,
        scanMode: UsageLedgerLogScanMode = .refreshToday)
    {
        self.environment = environment
        self.fileManager = fileManager
        self.sessionsRoot = sessionsRoot
        self.now = now
        self.log = log
        self.cache = cache
        self.scanMode = scanMode
        _ = maxAgeDays // Retained for source compatibility; scanMode controls history reads.
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        let root = try self.resolveSessionsRoot()
        let todayKey = LedgerCache.dayKey(for: self.now)
        let window = self.scanWindow(todayKey: todayKey)

        // Relay contract: normal refresh never reopens historical provider
        // JSONLs. Explicit rebuild mode is the repair path that opts into
        // historical reads and commits empty day snapshots for missing raw data.
        let cache = self.cache
        let filesToScan = self.listSessionFiles(
            root: root,
            minDate: window.minDate,
            maxAgeDays: window.fileMaxAgeDays)

        if filesToScan.isEmpty {
            await cache.mergeEntries(
                provider: "codex",
                entries: [],
                scanDate: self.now,
                todayKey: window.relayTodayKey,
                coveredMaxAgeDays: window.coveredMaxAgeDays,
                sourceWatermarks: window.completionWatermarks)
            return []
        }

        var entries: [UsageLedgerEntry] = []
        var seenKeys = Set<String>()
        var sourceWatermarks = window.completionWatermarks
        var readFailures: [String] = []

        for file in filesToScan {
            do {
                let watermark = try self.parseFile(
                    file,
                    minDate: window.minDate,
                    dayKey: window.fileWatermarkDayKey,
                    seenKeys: &seenKeys,
                    entries: &entries)
                sourceWatermarks.append(watermark)
            } catch {
                self.log.warning("Codex usage log read failed", metadata: [
                    "file": file.url.path,
                    "error": error.localizedDescription,
                ])
                readFailures.append(file.url.path)
            }
        }

        if !readFailures.isEmpty {
            throw CodexUsageLogError.readFailed(readFailures.joined(separator: ", "))
        }

        await cache.mergeEntries(
            provider: "codex",
            entries: entries,
            scanDate: self.now,
            todayKey: window.relayTodayKey,
            coveredMaxAgeDays: window.coveredMaxAgeDays,
            sourceWatermarks: sourceWatermarks)

        return entries
    }

    private struct ScanWindow {
        let minDate: Date
        let fileMaxAgeDays: Int?
        let relayTodayKey: String?
        let coveredMaxAgeDays: Int?
        let completionWatermarks: [UsageRelaySourceWatermark]
        let fileWatermarkDayKey: String?
    }

    private func scanWindow(todayKey: String) -> ScanWindow {
        let calendar = Calendar.current
        switch self.scanMode {
        case .refreshToday:
            return ScanWindow(
                minDate: calendar.startOfDay(for: self.now),
                fileMaxAgeDays: 1,
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
                    sourceKind: "codex-jsonl-rebuild",
                    sourceID: "rebuild:codex:\(dayKey)",
                    sourceFingerprint: "rebuild:codex:\(dayKey):\(Int(self.now.timeIntervalSince1970))")
            }
            return ScanWindow(
                minDate: start,
                fileMaxAgeDays: days,
                relayTodayKey: nil,
                coveredMaxAgeDays: days,
                completionWatermarks: watermarks,
                fileWatermarkDayKey: nil)
        }
    }

    private func resolveSessionsRoot() throws -> URL {
        if let sessionsRoot, self.fileManager.directoryExists(at: sessionsRoot) {
            return sessionsRoot.standardizedFileURL
        }

        let env = self.environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true).appendingPathComponent("sessions", isDirectory: true)
            if self.fileManager.directoryExists(at: url) {
                return url.standardizedFileURL
            }
        }

        let home = self.fileManager.homeDirectoryForCurrentUser
        let url = home
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        if self.fileManager.directoryExists(at: url) {
            return url.standardizedFileURL
        }

        throw CodexUsageLogError.noSessionsDirectory
    }

    private func listSessionFiles(root: URL, minDate: Date?, maxAgeDays: Int?) -> [SessionFile] {
        var results: [SessionFile] = []

        let calendar = Calendar.current
        if let maxAgeDays, maxAgeDays > 0 {
            let scanDays = max(1, maxAgeDays)
            let start = calendar.startOfDay(for: self.now)

            for offset in 0..<scanDays {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: start) else { continue }
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                let year = String(format: "%04d", components.year ?? 1970)
                let month = String(format: "%02d", components.month ?? 1)
                let day = String(format: "%02d", components.day ?? 1)

                let dayDir = root
                    .appendingPathComponent(year, isDirectory: true)
                    .appendingPathComponent(month, isDirectory: true)
                    .appendingPathComponent(day, isDirectory: true)

                guard let items = try? self.fileManager.contentsOfDirectory(
                    at: dayDir,
                    includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles])
                else {
                    continue
                }

                for item in items where item.pathExtension.lowercased() == "jsonl" {
                    let values = try? item.resourceValues(forKeys: [.contentModificationDateKey])
                    let modifiedAt = values?.contentModificationDate
                    if let minDate, let modifiedAt, modifiedAt < minDate { continue }
                    let sessionID = item.deletingPathExtension().lastPathComponent
                    results.append(SessionFile(url: item, sessionID: sessionID, modifiedAt: modifiedAt))
                }
            }
        } else {
            let enumerator = self.fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles])
            while let item = enumerator?.nextObject() as? URL {
                guard item.pathExtension.lowercased() == "jsonl" else { continue }
                let values = try? item.resourceValues(forKeys: [.contentModificationDateKey])
                let modifiedAt = values?.contentModificationDate
                if let minDate, let modifiedAt, modifiedAt < minDate { continue }
                let sessionID = item.deletingPathExtension().lastPathComponent
                results.append(SessionFile(url: item, sessionID: sessionID, modifiedAt: modifiedAt))
            }
        }

        return results
    }

    private func parseFile(
        _ file: SessionFile,
        minDate: Date?,
        dayKey: String?,
        seenKeys: inout Set<String>,
        entries: inout [UsageLedgerEntry]) throws
        -> UsageRelaySourceWatermark
    {
        var state = ParseState()
        let sourceMetadata = self.sourceMetadata(for: file.url)
        let context = ParseContext(
            file: file,
            minDate: minDate,
            sourceFingerprint: self.sourceFingerprint(for: sourceMetadata))
        let maxLineBytes = 256 * 1024
        let prefixBytes = 32 * 1024

        _ = try CostUsageJsonl.scan(
            fileURL: file.url,
            offset: 0,
            maxLineBytes: maxLineBytes,
            prefixBytes: prefixBytes,
            onLine: { line in
                self.consumeLine(
                    line,
                    context: context,
                    state: &state,
                    seenKeys: &seenKeys,
                    entries: &entries)
            })
        let latestMetadata = self.sourceMetadata(for: file.url)
        guard latestMetadata == sourceMetadata else {
            throw CodexUsageLogError.readFailed("Codex usage log changed while scanning: \(sourceMetadata.path)")
        }
        return self.sourceWatermark(for: sourceMetadata, dayKey: dayKey)
    }

    private func consumeLine(
        _ line: CostUsageJsonl.Line,
        context: ParseContext,
        state: inout ParseState,
        seenKeys: inout Set<String>,
        entries: inout [UsageLedgerEntry])
    {
        guard let parsed = self.parseLine(line, minDate: context.minDate) else { return }
        if parsed.type == "turn_context" {
            self.applyTurnContext(parsed.payload, state: &state)
            return
        }

        guard let record = self.tokenRecord(from: parsed, context: context, state: &state) else { return }
        let cachedClamp = min(record.tokens.cached, record.tokens.input)
        let key = self.dedupeKey(
            requestID: record.requestID,
            sessionID: record.sessionID,
            timestamp: record.timestamp,
            tokens: .init(
                input: record.tokens.input,
                output: record.tokens.output,
                cacheRead: cachedClamp))
        if seenKeys.contains(key) { return }
        seenKeys.insert(key)

        let cost = CostUsagePricing.codexCostUSD(
            model: record.model,
            inputTokens: record.tokens.input,
            cachedInputTokens: cachedClamp,
            outputTokens: record.tokens.output)

        entries.append(UsageLedgerEntry(
            provider: .codex,
            timestamp: record.timestamp,
            sessionID: record.sessionID,
            projectID: record.projectID,
            projectName: record.projectName,
            model: record.model,
            inputTokens: record.tokens.input,
            outputTokens: record.tokens.output,
            cacheCreationTokens: 0,
            cacheReadTokens: cachedClamp,
            costUSD: cost,
            requestID: record.requestID,
            messageID: nil,
            version: record.version,
            source: .codexLog,
            tokenProvenance: MetricProvenance(
                confidence: .inferred,
                source: .localLog,
                detail: "Codex JSONL cumulative counters converted to deltas"),
            costProvenance: cost == nil ? nil : MetricProvenance(
                confidence: .estimated,
                source: .pricingTable,
                detail: "Codex model pricing table"),
            sourceFingerprint: context.sourceFingerprint))
    }

    private func parseLine(_ line: CostUsageJsonl.Line, minDate: Date?) -> ParsedLine? {
        guard self.shouldParse(line) else { return nil }
        guard
            let object = (try? JSONSerialization.jsonObject(with: line.bytes)) as? [String: Any],
            let type = object["type"] as? String,
            let tsText = object["timestamp"] as? String,
            let timestamp = self.parseTimestamp(tsText)
        else {
            return nil
        }
        if let minDate, timestamp < minDate { return nil }
        return ParsedLine(
            object: object,
            type: type,
            timestamp: timestamp,
            payload: object["payload"] as? [String: Any])
    }

    private func shouldParse(_ line: CostUsageJsonl.Line) -> Bool {
        guard !line.bytes.isEmpty, !line.wasTruncated else { return false }
        let isEvent = line.bytes.containsAscii(#""type":"event_msg""#)
        let isContext = line.bytes.containsAscii(#""type":"turn_context""#)
        guard isEvent || isContext else { return false }
        return isContext || line.bytes.containsAscii(#""token_count""#)
    }

    private func applyTurnContext(_ payload: [String: Any]?, state: inout ParseState) {
        guard let payload else { return }
        if let model = payload["model"] as? String {
            state.currentModel = model
        } else if let info = payload["info"] as? [String: Any],
                  let model = info["model"] as? String
        {
            state.currentModel = model
        }

        let payloadProject = payload["project"] as? [String: Any]
        if let projectID = self.firstString(from: payload, keys: Self.projectIDKeys)
            ?? self.firstString(from: payloadProject, keys: ["id"] + Self.projectIDKeys)
            ?? self.firstString(from: payload, keys: Self.projectPathKeys)
        {
            state.currentProjectID = projectID
        }
        if let projectName = self.firstString(from: payload, keys: Self.projectNameKeys)
            ?? self.firstString(from: payloadProject, keys: ["name", "title"] + Self.projectNameKeys)
        {
            state.currentProjectName = projectName
        }
    }

    private func tokenRecord(
        from parsed: ParsedLine,
        context: ParseContext,
        state: inout ParseState) -> TokenRecord?
    {
        guard parsed.type == "event_msg" else { return nil }
        guard (parsed.payload?["type"] as? String) == "token_count" else { return nil }
        guard let info = parsed.payload?["info"] as? [String: Any] else { return nil }
        guard let tokens = self.tokenDeltas(from: info, previousTotals: &state.previousTotals) else { return nil }

        let project = self.projectContext(info: info, payload: parsed.payload, object: parsed.object, state: state)
        if let projectID = project.id {
            state.currentProjectID = projectID
        }
        if let projectName = project.name {
            state.currentProjectName = projectName
        }

        return TokenRecord(
            timestamp: parsed.timestamp,
            sessionID: self.sessionID(info: info, payload: parsed.payload, object: parsed.object)
                ?? context.file.sessionID,
            projectID: project.id,
            projectName: project.name,
            model: self.modelName(info: info, payload: parsed.payload, object: parsed.object, state: state),
            tokens: tokens,
            requestID: self.requestID(info: info, payload: parsed.payload, object: parsed.object),
            version: self.firstString(from: info, keys: ["client_version", "version"])
                ?? self.firstString(from: parsed.object, keys: ["version"]))
    }

    private func tokenDeltas(from info: [String: Any], previousTotals: inout CodexTotals?) -> CodexTotals? {
        if let total = info["total_token_usage"] as? [String: Any] {
            let current = CodexTotals(
                input: self.toInt(total["input_tokens"]),
                cached: self.toInt(total["cached_input_tokens"] ?? total["cache_read_input_tokens"]),
                output: self.toInt(total["output_tokens"]))
            let delta = Self.deltaTotals(current: current, previous: previousTotals)
            previousTotals = current
            return delta.input == 0 && delta.cached == 0 && delta.output == 0 ? nil : delta
        }

        guard let last = info["last_token_usage"] as? [String: Any] else { return nil }
        let delta = CodexTotals(
            input: max(0, self.toInt(last["input_tokens"])),
            cached: max(0, self.toInt(last["cached_input_tokens"] ?? last["cache_read_input_tokens"])),
            output: max(0, self.toInt(last["output_tokens"])))
        return delta.input == 0 && delta.cached == 0 && delta.output == 0 ? nil : delta
    }

    private func modelName(
        info: [String: Any],
        payload: [String: Any]?,
        object: [String: Any],
        state: ParseState) -> String
    {
        (info["model"] as? String)
            ?? (info["model_name"] as? String)
            ?? (payload?["model"] as? String)
            ?? (object["model"] as? String)
            ?? state.currentModel
            ?? "gpt-5"
    }

    private func sessionID(
        info: [String: Any],
        payload: [String: Any]?,
        object: [String: Any]) -> String?
    {
        self.firstString(from: info, keys: ["session_id", "sessionId"])
            ?? self.firstString(from: payload, keys: ["session_id", "sessionId"])
            ?? self.firstString(from: object, keys: ["session_id", "sessionId"])
    }

    private func requestID(
        info: [String: Any],
        payload: [String: Any]?,
        object: [String: Any]) -> String?
    {
        self.firstString(from: info, keys: ["request_id", "requestId", "event_id", "eventId"])
            ?? self.firstString(from: payload, keys: ["request_id", "requestId"])
            ?? self.firstString(from: object, keys: ["request_id", "requestId"])
    }

    private func projectContext(
        info: [String: Any],
        payload: [String: Any]?,
        object: [String: Any],
        state: ParseState) -> ProjectContext
    {
        let infoProject = info["project"] as? [String: Any]
        let payloadProject = payload?["project"] as? [String: Any]
        let rootProject = object["project"] as? [String: Any]
        let workspacePath = self.firstString(from: info, keys: Self.projectPathKeys)
            ?? self.firstString(from: payload, keys: Self.projectPathKeys)
            ?? self.firstString(from: object, keys: Self.projectPathKeys)
            ?? self.firstString(from: infoProject, keys: Self.projectPathKeys)
            ?? self.firstString(from: payloadProject, keys: Self.projectPathKeys)
            ?? self.firstString(from: rootProject, keys: Self.projectPathKeys)
        let projectID = self.firstString(from: info, keys: Self.projectIDKeys)
            ?? self.firstString(from: payload, keys: Self.projectIDKeys)
            ?? self.firstString(from: object, keys: Self.projectIDKeys)
            ?? self.firstString(from: infoProject, keys: ["id"] + Self.projectIDKeys)
            ?? self.firstString(from: payloadProject, keys: ["id"] + Self.projectIDKeys)
            ?? self.firstString(from: rootProject, keys: ["id"] + Self.projectIDKeys)
            ?? workspacePath
            ?? state.currentProjectID
        let projectName = self.firstString(from: info, keys: Self.projectNameKeys)
            ?? self.firstString(from: payload, keys: Self.projectNameKeys)
            ?? self.firstString(from: object, keys: Self.projectNameKeys)
            ?? self.firstString(from: infoProject, keys: ["name", "title"] + Self.projectNameKeys)
            ?? self.firstString(from: payloadProject, keys: ["name", "title"] + Self.projectNameKeys)
            ?? self.firstString(from: rootProject, keys: ["name", "title"] + Self.projectNameKeys)
            ?? state.currentProjectName
        return ProjectContext(id: projectID, name: projectName)
    }

    private func sourceWatermark(for metadata: SourceFileMetadata, dayKey: String?) -> UsageRelaySourceWatermark {
        return UsageRelaySourceWatermark(
            dayKey: dayKey,
            sourceKind: "codex-jsonl",
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

    private func parseTimestamp(_ value: String) -> Date? {
        let box = codexISOFormatterBox
        box.lock.lock()
        defer { box.lock.unlock() }
        return box.iso.date(from: value) ?? box.fractional.date(from: value)
    }

    private func toInt(_ value: Any?) -> Int {
        if let num = value as? NSNumber { return num.intValue }
        return 0
    }

    private static func deltaTotals(current: CodexTotals, previous: CodexTotals?) -> CodexTotals {
        guard let previous else { return current }
        return CodexTotals(
            input: current.input >= previous.input ? current.input - previous.input : current.input,
            cached: current.cached >= previous.cached ? current.cached - previous.cached : current.cached,
            output: current.output >= previous.output ? current.output - previous.output : current.output)
    }

    private func firstString(from dict: [String: Any]?, keys: [String]) -> String? {
        guard let dict else { return nil }
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func dedupeKey(
        requestID: String?,
        sessionID: String?,
        timestamp: Date,
        tokens: DedupeTokens) -> String
    {
        if let requestID, !requestID.isEmpty {
            return "req:\(requestID)"
        }
        return [
            "ts:\(timestamp.timeIntervalSince1970)",
            sessionID ?? "-",
            "\(tokens.input)",
            "\(tokens.output)",
            "\(tokens.cacheRead)",
        ].joined(separator: "|")
    }
}

private final class CodexISO8601FormatterBox: @unchecked Sendable {
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

private let codexISOFormatterBox = CodexISO8601FormatterBox()

extension FileManager {
    fileprivate func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return self.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
