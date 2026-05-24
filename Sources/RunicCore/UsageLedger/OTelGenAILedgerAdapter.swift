import Foundation

public struct OTelGenAIIngestionOptions: Sendable, Codable, Hashable {
    public var enabled: Bool
    public var allowExperimentalSemanticConventions: Bool
    public var defaultProvider: UsageProvider?
    public var source: UsageLedgerEntry.Source

    public init(
        enabled: Bool = false,
        allowExperimentalSemanticConventions: Bool = true,
        defaultProvider: UsageProvider? = nil,
        source: UsageLedgerEntry.Source = .openTelemetry)
    {
        self.enabled = enabled
        self.allowExperimentalSemanticConventions = allowExperimentalSemanticConventions
        self.defaultProvider = defaultProvider
        self.source = source
    }

    public static let disabled = OTelGenAIIngestionOptions(enabled: false)
}

public enum OTelGenAILedgerAdapterError: LocalizedError, Sendable, Equatable {
    case invalidUTF8
    case invalidJSON(String)

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            "OTel payload is not valid UTF-8."
        case let .invalidJSON(message):
            "OTel JSON parse failed: \(message)"
        }
    }
}

public enum OTelGenAILedgerAdapter {
    public static func parseData(
        _ data: Data,
        options: OTelGenAIIngestionOptions = .disabled) throws -> [UsageLedgerEntry]
    {
        guard options.enabled else { return [] }
        guard !data.isEmpty else { return [] }

        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return self.parseJSONObject(object, options: options)
        } catch {
            guard let text = String(data: data, encoding: .utf8) else {
                throw OTelGenAILedgerAdapterError.invalidUTF8
            }
            return try self.parseJSONLines(text, options: options)
        }
    }

    public static func parseJSONLines(
        _ text: String,
        options: OTelGenAIIngestionOptions = .disabled) throws -> [UsageLedgerEntry]
    {
        guard options.enabled else { return [] }
        let lines = text.split(whereSeparator: \.isNewline)
        guard !lines.isEmpty else { return [] }

        var results: [UsageLedgerEntry] = []
        results.reserveCapacity(lines.count)
        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard let data = line.data(using: .utf8) else {
                throw OTelGenAILedgerAdapterError.invalidUTF8
            }
            do {
                let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                results.append(contentsOf: self.parseJSONObject(object, options: options))
            } catch {
                throw OTelGenAILedgerAdapterError.invalidJSON("line \(index + 1): \(error.localizedDescription)")
            }
        }
        return results
    }

    public static func parseJSONObject(
        _ object: Any,
        options: OTelGenAIIngestionOptions = .disabled) -> [UsageLedgerEntry]
    {
        guard options.enabled else { return [] }

        if let array = object as? [Any] {
            return array.flatMap { self.parseJSONObject($0, options: options) }
        }
        guard let record = object as? [String: Any] else { return [] }
        if let resourceSpans = record["resourceSpans"] as? [Any] {
            return self.parseResourceSpans(resourceSpans, options: options)
        }
        return self.parseFlatRecord(record, options: options).map { [$0] } ?? []
    }

    private static func parseResourceSpans(
        _ resourceSpans: [Any],
        options: OTelGenAIIngestionOptions) -> [UsageLedgerEntry]
    {
        var entries: [UsageLedgerEntry] = []

        for resourceSpanAny in resourceSpans {
            guard let resourceSpan = resourceSpanAny as? [String: Any] else { continue }
            let resourceAttributes = self.parseAttributesPayload(resourceSpan["resource"])

            let scopeSpans = (resourceSpan["scopeSpans"] as? [Any]) ?? []
            for scopeSpanAny in scopeSpans {
                guard let scopeSpan = scopeSpanAny as? [String: Any] else { continue }
                let spans = (scopeSpan["spans"] as? [Any]) ?? []
                for spanAny in spans {
                    guard let span = spanAny as? [String: Any] else { continue }
                    let spanAttributes = self.parseAttributesPayload(span["attributes"])
                    var merged: [String: Any] = resourceAttributes
                    merged.merge(spanAttributes, uniquingKeysWith: { _, rhs in rhs })

                    if let name = span["name"] as? String, !name.isEmpty {
                        merged["operation.name"] = name
                    }
                    if let end = span["endTimeUnixNano"] {
                        merged["endTimeUnixNano"] = end
                    }
                    if let start = span["startTimeUnixNano"] {
                        merged["startTimeUnixNano"] = start
                    }
                    if let traceID = span["traceId"] as? String, !traceID.isEmpty {
                        merged["trace.id"] = traceID
                    }
                    if let spanID = span["spanId"] as? String, !spanID.isEmpty {
                        merged["span.id"] = spanID
                    }

                    if let entry = self.makeLedgerEntry(from: merged, options: options) {
                        entries.append(entry)
                    }
                }
            }
        }

        return entries
    }

    private static func parseFlatRecord(
        _ record: [String: Any],
        options: OTelGenAIIngestionOptions) -> UsageLedgerEntry?
    {
        var attributes = self.parseAttributesPayload(record["attributes"])
        for (key, value) in record {
            if attributes[key] == nil, self.isScalar(value) {
                attributes[key] = value
            }
        }

        if let resource = record["resource"] as? [String: Any] {
            let resourceAttributes = self.parseAttributesPayload(resource["attributes"])
            attributes.merge(resourceAttributes, uniquingKeysWith: { lhs, _ in lhs })
        }

        return self.makeLedgerEntry(from: attributes, options: options)
    }

    private static func makeLedgerEntry(
        from attributes: [String: Any],
        options: OTelGenAIIngestionOptions) -> UsageLedgerEntry?
    {
        let model = self.stringValue(
            for: [
                "gen_ai.request.model",
                "gen_ai.response.model",
                "llm.model",
                "ai.model",
                "model",
            ],
            in: attributes)

        let provider: UsageProvider? = {
            if let rawSystem = self.stringValue(
                for: [
                    "gen_ai.system",
                    "llm.provider",
                    "provider",
                ],
                in: attributes),
                let mapped = self.mapProvider(rawSystem)
            {
                return mapped
            }
            if let model, let inferred = self.inferProvider(fromModel: model) {
                return inferred
            }
            return options.defaultProvider
        }()

        guard let provider else { return nil }

        let inputTokens = max(0, self.intValue(
            for: [
                "gen_ai.usage.input_tokens",
                "gen_ai.usage.prompt_tokens",
                "gen_ai.usage.promptTokens",
                "ai.usage.promptTokens",
                "ai.usage.prompt_tokens",
                "llm.usage.prompt_tokens",
                "usage.prompt_tokens",
                "usage.input_tokens",
                "usage.promptTokens",
                "prompt_eval_count",
                "input_tokens",
                "prompt_tokens",
            ],
            in: attributes) ?? 0)

        let parsedOutputTokens = self.intValue(
            for: [
                "gen_ai.usage.output_tokens",
                "gen_ai.usage.completion_tokens",
                "gen_ai.usage.completionTokens",
                "ai.usage.completionTokens",
                "ai.usage.completion_tokens",
                "llm.usage.completion_tokens",
                "usage.completion_tokens",
                "usage.output_tokens",
                "usage.completionTokens",
                "eval_count",
                "output_tokens",
                "completion_tokens",
            ],
            in: attributes)
        let parsedTotalTokens = self.intValue(
            for: [
                "gen_ai.usage.total_tokens",
                "gen_ai.usage.totalTokens",
                "ai.usage.totalTokens",
                "ai.usage.total_tokens",
                "llm.usage.total_tokens",
                "usage.total_tokens",
                "usage.totalTokens",
                "total_tokens",
            ],
            in: attributes)
        let outputTokens = max(
            0,
            parsedOutputTokens
                ?? parsedTotalTokens.map { max(0, $0 - inputTokens) }
                ?? 0)

        let cacheCreationTokens = max(0, self.intValue(
            for: [
                "gen_ai.usage.cache_creation_input_tokens",
                "gen_ai.usage.cache_write_tokens",
                "gen_ai.usage.cacheWriteTokens",
                "ai.usage.cacheWriteTokens",
                "usage.cache_write_tokens",
                "usage.cache_creation_input_tokens",
                "prompt_cache_miss_tokens",
                "cache_creation_tokens",
            ],
            in: attributes) ?? 0)

        let cacheReadTokens = max(0, self.intValue(
            for: [
                "gen_ai.usage.cache_read_input_tokens",
                "gen_ai.usage.cache_read_tokens",
                "gen_ai.usage.cacheReadTokens",
                "ai.usage.cacheReadTokens",
                "usage.cache_read_tokens",
                "usage.cache_read_input_tokens",
                "prompt_cache_hit_tokens",
                "cache_read_tokens",
            ],
            in: attributes) ?? 0)

        let timestamp = self.dateValue(
            for: [
                "endTimeUnixNano",
                "end_time_unix_nano",
                "time_unix_nano",
                "timeUnixNano",
                "timestamp",
                "time",
            ],
            in: attributes) ?? Date()

        let projectID = self.stringValue(
            for: [
                "gen_ai.project.id",
                "project.id",
                "project_id",
            ],
            in: attributes)

        let projectName = self.stringValue(
            for: [
                "gen_ai.project.name",
                "project.name",
                "project_name",
            ],
            in: attributes)

        let sessionID = self.stringValue(
            for: [
                "gen_ai.conversation.id",
                "session.id",
                "session_id",
                "thread.id",
            ],
            in: attributes)

        let requestID = self.stringValue(
            for: [
                "gen_ai.request.id",
                "request.id",
                "request_id",
                "span.id",
            ],
            in: attributes)

        let messageID = self.stringValue(
            for: [
                "gen_ai.message.id",
                "message.id",
                "message_id",
            ],
            in: attributes)

        let version = self.stringValue(
            for: [
                "gen_ai.system.version",
                "library.version",
                "sdk.version",
            ],
            in: attributes)

        let costUSD = self.doubleValue(
            for: [
                "gen_ai.usage.cost",
                "gen_ai.usage.cost_usd",
                "gen_ai.usage.costUSD",
                "ai.usage.costUSD",
                "ai.usage.cost_usd",
                "usage.cost",
                "usage.cost_usd",
                "usage.costUSD",
                "cost.usd",
                "cost_usd",
                "total_cost",
            ],
            in: attributes)
        let operationKind = self.operationKind(from: attributes)

        return UsageLedgerEntry(
            provider: provider,
            timestamp: timestamp,
            sessionID: sessionID,
            projectID: projectID,
            projectName: projectName,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            costUSD: costUSD,
            requestID: requestID,
            messageID: messageID,
            version: version,
            source: options.source,
            operationKind: operationKind,
            tokenProvenance: MetricProvenance(
                confidence: .providerReported,
                source: .openTelemetry,
                detail: "GenAI token usage attributes"),
            costProvenance: costUSD == nil ? nil : MetricProvenance(
                confidence: .providerReported,
                source: .openTelemetry,
                detail: "GenAI cost attribute"))
    }

    private static func operationKind(from attributes: [String: Any]) -> UsageLedgerOperationKind {
        let signals = [
            self.stringValue(
                for: [
                    "gen_ai.query.source",
                    "gen_ai.request.query_source",
                    "claude_code.query_source",
                    "claude.code.query_source",
                    "query_source",
                    "query.source",
                ],
                in: attributes),
            self.stringValue(
                for: [
                    "gen_ai.operation.name",
                    "operation.name",
                    "span.name",
                    "name",
                ],
                in: attributes),
        ]
        .compactMap { $0?.lowercased() }

        if signals.contains(where: { $0.contains("compact") || $0.contains("compaction") }) {
            return .compaction
        }
        if signals.contains(where: { $0.contains("tool") || $0.contains("function") }) {
            return .tool
        }
        return .inference
    }

    private static func parseAttributesPayload(_ payload: Any?) -> [String: Any] {
        guard let payload else { return [:] }
        if let keyed = payload as? [String: Any] {
            if keyed.keys.contains("attributes"), let nested = keyed["attributes"] {
                return self.parseAttributesPayload(nested)
            }
            if keyed.keys.contains("key"), keyed.keys.contains("value") {
                return self.parseAttributesPayload([keyed])
            }
            return keyed
        }
        guard let list = payload as? [Any] else { return [:] }

        var attributes: [String: Any] = [:]
        for itemAny in list {
            guard let item = itemAny as? [String: Any] else { continue }
            guard let key = item["key"] as? String, !key.isEmpty else { continue }
            guard let decoded = self.decodeAttributeValue(item["value"]) else { continue }
            attributes[key] = decoded
        }
        return attributes
    }

    private static func decodeAttributeValue(_ raw: Any?) -> Any? {
        guard let raw else { return nil }
        guard let dictionary = raw as? [String: Any] else { return raw }

        if let stringValue = dictionary["stringValue"] as? String {
            return stringValue
        }
        if let intValue = dictionary["intValue"] {
            return self.coerceInt(intValue) ?? intValue
        }
        if let doubleValue = dictionary["doubleValue"] {
            return self.coerceDouble(doubleValue) ?? doubleValue
        }
        if let boolValue = dictionary["boolValue"] as? Bool {
            return boolValue
        }
        if let arrayValue = dictionary["arrayValue"] as? [String: Any],
           let values = arrayValue["values"] as? [Any]
        {
            return values.compactMap { self.decodeAttributeValue($0) }
        }
        if let kvListValue = dictionary["kvlistValue"] as? [String: Any],
           let values = kvListValue["values"] as? [Any]
        {
            return self.parseAttributesPayload(values)
        }
        return nil
    }

    private static func mapProvider(_ rawValue: String) -> UsageProvider? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }
        let compact = normalized
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")

        switch compact {
        case "openai", "codex":
            return .codex
        case "anthropic", "claude":
            return .claude
        case "google", "googlegemini", "gemini":
            return .gemini
        case "vertexai", "googlevertexai", "vertex":
            return .vertexai
        case "zai", "zaiapi", "zhipu", "zhipuai":
            return .zai
        case "github", "githubcopilot", "copilot":
            return .copilot
        case "cursor":
            return .cursor
        case "factory", "factoryai":
            return .factory
        case "antigravity":
            return .antigravity
        case "minimax":
            return .minimax
        case "openrouter":
            return .openrouter
        case "vercel", "vercelai", "vercelaigateway", "aigateway":
            return .vercelai
        case "groq":
            return .groq
        case "deepseek":
            return .deepseek
        case "fireworks", "fireworksai":
            return .fireworks
        case "bedrock", "awsbedrock", "amazonbedrock":
            return .bedrock
        case "azure", "azureopenai":
            return .azure
        case "mistral":
            return .mistral
        case "perplexity":
            return .perplexity
        case "kimi", "moonshot", "moonshotai":
            return .kimi
        case "auggie":
            return .auggie
        case "cohere":
            return .cohere
        case "xai":
            return .xai
        case "together":
            return .together
        case "cerebras":
            return .cerebras
        case "sambanova":
            return .sambanova
        case "qwen", "dashscope", "alibabacloud":
            return .qwen
        case "local", "localllm", "locallanguage", "locallanguagemodel", "ollama", "lmstudio", "llamacpp", "vllm", "openwebui":
            return .localLLM
        default:
            return UsageProvider(rawValue: normalized)
        }
    }

    private static func inferProvider(fromModel model: String) -> UsageProvider? {
        let lower = model.lowercased()
        if lower.contains("claude") { return .claude }
        if lower.contains("gemini") { return .gemini }
        if lower.contains("deepseek") { return .deepseek }
        if lower.contains("qwen") { return .qwen }
        if lower.contains("kimi") { return .kimi }
        if lower.contains("moonshot") { return .kimi }
        if lower.contains("mistral") { return .mistral }
        if lower.contains("mixtral") { return .mistral }
        if lower.contains("groq") { return .groq }
        if lower.contains("minimax") { return .minimax }
        if lower.contains("command") { return .cohere }
        if lower.contains("gpt") || lower.contains("o1") || lower.contains("o3") || lower.contains("o4") {
            return .codex
        }
        if lower.contains("copilot") { return .copilot }
        return nil
    }

    private static func stringValue(for keys: [String], in dictionary: [String: Any]) -> String? {
        for key in keys {
            guard let raw = self.lookupValue(forKey: key, in: dictionary) else { continue }
            if let string = raw as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
                continue
            }
            if let number = raw as? NSNumber {
                return number.stringValue
            }
        }
        return nil
    }

    private static func intValue(for keys: [String], in dictionary: [String: Any]) -> Int? {
        for key in keys {
            guard let raw = self.lookupValue(forKey: key, in: dictionary) else { continue }
            if let coerced = self.coerceInt(raw) {
                return coerced
            }
        }
        return nil
    }

    private static func doubleValue(for keys: [String], in dictionary: [String: Any]) -> Double? {
        for key in keys {
            guard let raw = self.lookupValue(forKey: key, in: dictionary) else { continue }
            if let coerced = self.coerceDouble(raw) {
                return coerced
            }
        }
        return nil
    }

    private static func dateValue(for keys: [String], in dictionary: [String: Any]) -> Date? {
        for key in keys {
            guard let raw = self.lookupValue(forKey: key, in: dictionary) else { continue }
            if let nanos = self.coerceDouble(raw), nanos > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: nanos / 1_000_000_000)
            }
            if let seconds = self.coerceDouble(raw), seconds > 0, seconds < 4_102_444_800 {
                return Date(timeIntervalSince1970: seconds)
            }
            if let text = raw as? String, let parsed = self.parseISODate(text) {
                return parsed
            }
        }
        return nil
    }

    private static func parseISODate(_ text: String) -> Date? {
        if let parsed = try? Date(text, strategy: .iso8601) {
            return parsed
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    private static func lookupValue(forKey key: String, in dictionary: [String: Any]) -> Any? {
        if let direct = dictionary[key] {
            return direct
        }
        let parts = key.split(separator: ".").map(String.init)
        guard parts.count > 1 else { return nil }

        var cursor: Any = dictionary
        for part in parts {
            guard let object = cursor as? [String: Any], let next = object[part] else { return nil }
            cursor = next
        }
        return cursor
    }

    private static func coerceInt(_ value: Any) -> Int? {
        if let int = value as? Int { return int }
        if let uint = value as? UInt { return Int(uint) }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let int = Int(trimmed) { return int }
            if let double = Double(trimmed) { return Int(double) }
        }
        return nil
    }

    private static func coerceDouble(_ value: Any) -> Double? {
        if let double = value as? Double { return double }
        if let float = value as? Float { return Double(float) }
        if let int = value as? Int { return Double(int) }
        if let uint = value as? UInt { return Double(uint) }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(trimmed)
        }
        return nil
    }

    private static func isScalar(_ value: Any) -> Bool {
        value is String || value is NSNumber || value is Bool
    }
}

public struct OTelGenAIFileLedgerSource: UsageLedgerSource {
    public let files: [URL]
    public let options: OTelGenAIIngestionOptions
    public let minTimestamp: Date?

    public init(
        files: [URL],
        options: OTelGenAIIngestionOptions = .disabled,
        minTimestamp: Date? = nil)
    {
        self.files = files
        self.options = options
        self.minTimestamp = minTimestamp
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        guard self.options.enabled else { return [] }

        var entries: [UsageLedgerEntry] = []
        for file in self.files {
            try Task.checkCancellation()
            guard Self.shouldRead(file: file, minTimestamp: self.minTimestamp) else { continue }
            let parsed = try Self.parseFile(file, options: self.options, minTimestamp: self.minTimestamp)
            entries.append(contentsOf: parsed)
        }
        return entries.sorted { $0.timestamp < $1.timestamp }
    }

    private static func shouldRead(file: URL, minTimestamp: Date?) -> Bool {
        guard let minTimestamp else { return true }
        guard let modifiedAt = try? file.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        else { return true }
        return modifiedAt >= minTimestamp
    }

    private static func parseFile(
        _ file: URL,
        options: OTelGenAIIngestionOptions,
        minTimestamp: Date?) throws -> [UsageLedgerEntry]
    {
        if file.pathExtension.lowercased() == "json" {
            return try OTelGenAILedgerAdapter.parseData(Data(contentsOf: file), options: options)
                .filter { entry in minTimestamp.map { entry.timestamp >= $0 } ?? true }
        }

        var entries: [UsageLedgerEntry] = []

        func parseLine(_ line: Data, index: Int) throws {
            guard !line.isEmpty else { return }
            guard let text = String(data: line, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty
            else { return }
            guard let data = text.data(using: .utf8) else {
                throw OTelGenAILedgerAdapterError.invalidUTF8
            }
            do {
                let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                let parsed = OTelGenAILedgerAdapter.parseJSONObject(object, options: options)
                entries.append(contentsOf: parsed.filter { entry in
                    minTimestamp.map { entry.timestamp >= $0 } ?? true
                })
            } catch {
                throw OTelGenAILedgerAdapterError.invalidJSON("line \(index): \(error.localizedDescription)")
            }
        }

        var lineIndex = 1
        var parseError: Error?
        try CostUsageJsonl.scan(
            fileURL: file,
            maxLineBytes: 512 * 1024,
            prefixBytes: 512 * 1024)
        { line in
            guard parseError == nil else { return }
            guard !line.wasTruncated else {
                lineIndex += 1
                return
            }
            do {
                try parseLine(line.bytes, index: lineIndex)
            } catch {
                parseError = error
            }
            lineIndex += 1
        }
        if let parseError { throw parseError }
        return entries
    }
}
