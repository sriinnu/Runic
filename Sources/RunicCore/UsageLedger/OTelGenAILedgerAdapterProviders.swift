import Foundation

extension OTelGenAILedgerAdapter {
    static func resolvedProvider(
        model: String?,
        attributes: [String: Any],
        options: OTelGenAIIngestionOptions) -> UsageProvider?
    {
        if let rawSystem = self.stringValue(for: ["gen_ai.system", "llm.provider", "provider"], in: attributes),
           let mapped = self.mapProvider(rawSystem)
        {
            return mapped
        }
        if let model, let inferred = self.inferProvider(fromModel: model) {
            return inferred
        }
        return options.defaultProvider
    }

    static func mapProvider(_ rawValue: String) -> UsageProvider? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }
        let compact = normalized
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")

        return self.providerAliases[compact] ?? UsageProvider(rawValue: normalized)
    }

    static func inferProvider(fromModel model: String) -> UsageProvider? {
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
}
