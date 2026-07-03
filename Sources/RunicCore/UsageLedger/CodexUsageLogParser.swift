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
    let resumeStore: LedgerScanResumeStore

    init(resumeStore: LedgerScanResumeStore = .shared) {
        self.resumeStore = resumeStore
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

        init() {}

        /// Rehydrate the mid-file parse state captured by a previous scan so a
        /// resumed read continues the legacy cumulative-delta path (and the
        /// streamed turn context) exactly where the last read stopped.
        init(cursor: LedgerScanResumeStore.CodexCursor?) {
            guard let cursor else { return }
            self.currentModel = cursor.currentModel
            self.currentProjectID = cursor.currentProjectID
            self.currentProjectName = cursor.currentProjectName
            if let input = cursor.previousTotalsInput,
               let cached = cursor.previousTotalsCached,
               let output = cursor.previousTotalsOutput
            {
                self.previousTotals = CodexTotals(input: input, cached: cached, output: output)
            }
        }

        var cursor: LedgerScanResumeStore.CodexCursor {
            LedgerScanResumeStore.CodexCursor(
                currentModel: self.currentModel,
                currentProjectID: self.currentProjectID,
                currentProjectName: self.currentProjectName,
                previousTotalsInput: self.previousTotals?.input,
                previousTotalsCached: self.previousTotals?.cached,
                previousTotalsOutput: self.previousTotals?.output)
        }
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
        let sourceMetadata = self.sourceMetadata(for: file.url)
        let context = ParseContext(
            file: file,
            minDate: minDate,
            sourceFingerprint: self.sourceFingerprint(for: sourceMetadata))
        let maxLineBytes = 256 * 1024
        let prefixBytes = 32 * 1024
        let resumeKey = "codex|\(sourceMetadata.path)"

        // Byte-offset resume: skip the already-parsed prefix of an append-only
        // rollout and carry forward the entries parsed by earlier scans, so a
        // multi-GB live session is not re-read from byte 0 every refresh. Any
        // mismatch (rotation, truncation, wider scan window) falls back to a
        // full re-read via `resumableState`.
        var startOffset: Int64 = 0
        var carriedEntries: [UsageLedgerEntry] = []
        let fingerprint: (hash: UInt64, length: Int)?
        if let prior = self.resumeStore.resumableState(
            forKey: resumeKey,
            url: file.url,
            currentSizeBytes: sourceMetadata.sizeBytes,
            minDate: minDate)
        {
            startOffset = prior.resumeOffset
            carriedEntries = prior.entries
            state = ParseState(cursor: prior.codexCursor)
            fingerprint = (prior.fingerprint, prior.fingerprintLength)
        } else {
            fingerprint = LedgerScanResumeStore.prefixFingerprint(url: file.url)
        }

        // Re-register carried entries so (a) each is emitted exactly once per
        // scan even across files, and (b) a re-parsed torn final line (the
        // resume offset stops at the last newline) dedupes against them.
        // Totals invariant: emitted = carried-in-window + newly-parsed tail ==
        // what a from-scratch scan of the whole file would produce.
        var entries: [UsageLedgerEntry] = []
        var retainedEntries: [UsageLedgerEntry] = []
        retainedEntries.reserveCapacity(carriedEntries.count)
        for carried in carriedEntries {
            if let minDate, carried.timestamp < minDate { continue }
            retainedEntries.append(carried)
            let key = self.dedupeKey(forEntry: carried)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            entries.append(carried)
        }

        var newEntries: [UsageLedgerEntry] = []
        let resumeOffset: Int64
        do {
            resumeOffset = try CostUsageJsonl.scan(
                fileURL: file.url,
                offset: startOffset,
                maxLineBytes: maxLineBytes,
                prefixBytes: prefixBytes,
                onLine: { line in
                    self.consumeLine(
                        line,
                        context: context,
                        state: &state,
                        seenKeys: &seenKeys,
                        entries: &newEntries)
                })
        } catch {
            self.resumeStore.removeState(forKey: resumeKey)
            throw error
        }
        entries.append(contentsOf: newEntries)
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
            self.resumeStore.removeState(forKey: resumeKey)
            throw CodexUsageLogSource.CodexUsageLogError.readFailed(
                "Codex usage log truncated while scanning: \(sourceMetadata.path)")
        }

        if let fingerprint, let latestSize = latestMetadata.sizeBytes {
            self.resumeStore.setState(
                LedgerScanResumeStore.FileState(
                    fingerprint: fingerprint.hash,
                    fingerprintLength: fingerprint.length,
                    sizeBytes: latestSize,
                    resumeOffset: resumeOffset,
                    minDate: minDate,
                    entries: retainedEntries + newEntries,
                    codexCursor: state.cursor),
                forKey: resumeKey)
        } else {
            self.resumeStore.removeState(forKey: resumeKey)
        }
        return CodexUsageParsedFile(
            entries: entries,
            watermark: self.sourceWatermark(for: sourceMetadata, dayKey: dayKey))
    }

    /// Reconstructs the dedupe key for an already-built entry. Codex entries
    /// store input as the NON-cached remainder (cached tokens are split out),
    /// so the raw input the key was originally built from is
    /// `inputTokens + cacheReadTokens`.
    private func dedupeKey(forEntry entry: UsageLedgerEntry) -> String {
        self.dedupeKey(
            requestID: entry.requestID,
            sessionID: entry.sessionID,
            timestamp: entry.timestamp,
            tokens: DedupeTokens(
                input: entry.inputTokens + entry.cacheReadTokens,
                output: entry.outputTokens,
                cacheRead: entry.cacheReadTokens))
    }

    private func consumeLine(
        _ line: CostUsageJsonl.Line,
        context: ParseContext,
        state: inout ParseState,
        seenKeys: inout Set<String>,
        entries: inout [UsageLedgerEntry])
    {
        guard let parsed = self.parseLine(line) else { return }
        if parsed.type == "turn_context" {
            self.applyTurnContext(parsed.payload, state: &state)
            return
        }

        guard let record = self.tokenRecord(from: parsed, context: context, state: &state) else { return }
        // Pre-window lines must still flow through tokenRecord so the cumulative
        // cursor (state.previousTotals) advances past them — otherwise the first
        // in-window legacy total_token_usage line has no prior totals and books
        // the file's ENTIRE history as one delta. They advance the cursor but are
        // never emitted.
        if let minDate = context.minDate, record.timestamp < minDate { return }
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
            // OpenAI reports cached tokens as a SUBSET of input_tokens (the cost
            // path already prices input - cached at the full rate). Ledger entries
            // sum input/output/cache as DISJOINT classes, so store only the
            // non-cached remainder as input.
            inputTokens: record.tokens.input - cachedClamp,
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

    private func parseLine(_ line: CostUsageJsonl.Line) -> ParsedLine? {
        guard self.shouldParse(line) else { return nil }
        guard
            let object = (try? JSONSerialization.jsonObject(with: line.bytes)) as? [String: Any],
            let type = object["type"] as? String,
            let tsText = object["timestamp"] as? String,
            let timestamp = self.parseTimestamp(tsText)
        else {
            return nil
        }
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
        // Prefer last_token_usage — the self-contained per-request delta. A modern
        // codex rollout interleaves MULTIPLE cumulative total_token_usage streams
        // (parallel sub-agents/conversations) in one file, so the running total
        // jumps backwards between requests and cumulative deltas explode into the
        // billions/trillions. last_token_usage also needs no prior state, so a
        // windowed scan that starts mid-session (minDate) can't over-count the
        // first kept line. Only fall back to cumulative deltas for legacy lines
        // that predate last_token_usage.
        if let last = info["last_token_usage"] as? [String: Any] {
            // Keep the cumulative cursor current so a (rare) later total-only line in
            // the same file computes a correct incremental delta instead of folding
            // in turns already captured here.
            if let total = info["total_token_usage"] as? [String: Any] {
                previousTotals = CodexTotals(
                    input: self.toInt(total["input_tokens"]),
                    cached: self.toInt(total["cached_input_tokens"] ?? total["cache_read_input_tokens"]),
                    output: self.toInt(total["output_tokens"]))
            }
            let delta = CodexTotals(
                input: max(0, self.toInt(last["input_tokens"])),
                cached: max(0, self.toInt(last["cached_input_tokens"] ?? last["cache_read_input_tokens"])),
                output: max(0, self.toInt(last["output_tokens"])))
            return delta.input == 0 && delta.cached == 0 && delta.output == 0 ? nil : delta
        }

        guard let total = info["total_token_usage"] as? [String: Any] else { return nil }
        let current = CodexTotals(
            input: self.toInt(total["input_tokens"]),
            cached: self.toInt(total["cached_input_tokens"] ?? total["cache_read_input_tokens"]),
            output: self.toInt(total["output_tokens"]))
        let delta = Self.deltaTotals(current: current, previous: previousTotals)
        previousTotals = current
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
