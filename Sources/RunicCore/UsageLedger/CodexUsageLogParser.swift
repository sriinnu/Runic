import Foundation

struct CodexUsageSessionFile {
    let url: URL
    let sessionID: String?
    let modifiedAt: Date?
}

struct CodexUsageParsedFile {
    let entries: [UsageLedgerEntry]
    let watermark: UsageRelaySourceWatermark
}

struct CodexUsageLogParser {
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
        let file: CodexUsageSessionFile
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

    func parseFile(
        _ file: CodexUsageSessionFile,
        minDate: Date?,
        dayKey: String?,
        seenKeys: inout Set<String>) throws -> CodexUsageParsedFile
    {
        var state = ParseState()
        var entries: [UsageLedgerEntry] = []
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
        // A live, multi-day Codex session writes to its rollout file continuously,
        // so the file almost always GROWS during a read. That is safe for an
        // append-only log: we parsed a valid prefix and the appended tail is
        // captured on the next scan (a torn final line just fails to decode and is
        // skipped). Rejecting on any change stranded long-running sessions, so only
        // treat a SHRINK — truncation or rewrite — as a genuinely torn read.
        if let before = sourceMetadata.sizeBytes,
           let after = latestMetadata.sizeBytes,
           after < before
        {
            throw CodexUsageLogSource.CodexUsageLogError.readFailed(
                "Codex usage log truncated while scanning: \(sourceMetadata.path)")
        }
        return CodexUsageParsedFile(
            entries: entries,
            watermark: self.sourceWatermark(for: sourceMetadata, dayKey: dayKey))
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
        UsageRelaySourceWatermark(
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
