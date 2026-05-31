import Foundation

public enum OTelGenAILedgerAdapter {
    struct EntryMetadata {
        let timestamp: Date
        let projectID: String?
        let projectName: String?
        let sessionID: String?
        let requestID: String?
        let messageID: String?
        let version: String?
    }

    struct TokenCounts {
        let input: Int
        let output: Int
        let cacheCreation: Int
        let cacheRead: Int
    }

    static let providerAliases: [String: UsageProvider] = [
        "openai": .codex,
        "codex": .codex,
        "anthropic": .claude,
        "claude": .claude,
        "google": .gemini,
        "googlegemini": .gemini,
        "gemini": .gemini,
        "vertexai": .vertexai,
        "googlevertexai": .vertexai,
        "vertex": .vertexai,
        "zai": .zai,
        "zaiapi": .zai,
        "zhipu": .zai,
        "zhipuai": .zai,
        "github": .copilot,
        "githubcopilot": .copilot,
        "copilot": .copilot,
        "cursor": .cursor,
        "factory": .factory,
        "factoryai": .factory,
        "antigravity": .antigravity,
        "minimax": .minimax,
        "openrouter": .openrouter,
        "vercel": .vercelai,
        "vercelai": .vercelai,
        "vercelaigateway": .vercelai,
        "aigateway": .vercelai,
        "groq": .groq,
        "deepseek": .deepseek,
        "fireworks": .fireworks,
        "fireworksai": .fireworks,
        "bedrock": .bedrock,
        "awsbedrock": .bedrock,
        "amazonbedrock": .bedrock,
        "azure": .azure,
        "azureopenai": .azure,
        "mistral": .mistral,
        "perplexity": .perplexity,
        "kimi": .kimi,
        "moonshot": .kimi,
        "moonshotai": .kimi,
        "auggie": .auggie,
        "cohere": .cohere,
        "xai": .xai,
        "together": .together,
        "cerebras": .cerebras,
        "sambanova": .sambanova,
        "qwen": .qwen,
        "dashscope": .qwen,
        "alibabacloud": .qwen,
        "local": .localLLM,
        "localllm": .localLLM,
        "locallanguage": .localLLM,
        "locallanguagemodel": .localLLM,
        "ollama": .localLLM,
        "lmstudio": .localLLM,
        "llamacpp": .localLLM,
        "vllm": .localLLM,
        "openwebui": .localLLM,
    ]

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
}
