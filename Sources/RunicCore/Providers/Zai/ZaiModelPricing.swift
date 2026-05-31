import Foundation

/// Static pricing lookup for z.ai models (USD per 1M tokens).
public enum ZaiModelPricing {
    public struct Tier: Sendable {
        public let inputPerMillion: Double
        public let outputPerMillion: Double
        public let contextWindow: Int
    }

    private static let tiers: [String: Tier] = [
        "glm-4.7-flash": Tier(inputPerMillion: 0.06, outputPerMillion: 0.40, contextWindow: 203_000),
        "glm-4.7-flash-thinking": Tier(inputPerMillion: 0.06, outputPerMillion: 0.40, contextWindow: 203_000),
        "glm-4-32b": Tier(inputPerMillion: 0.10, outputPerMillion: 0.10, contextWindow: 128_000),
        "glm-4.5-air": Tier(inputPerMillion: 0.13, outputPerMillion: 0.85, contextWindow: 131_000),
        "glm-4.6v": Tier(inputPerMillion: 0.30, outputPerMillion: 0.90, contextWindow: 131_000),
        "glm-4.6v-thinking": Tier(inputPerMillion: 0.30, outputPerMillion: 0.90, contextWindow: 131_000),
        "glm-4.7": Tier(inputPerMillion: 0.38, outputPerMillion: 1.75, contextWindow: 203_000),
        "glm-4.7-thinking": Tier(inputPerMillion: 0.38, outputPerMillion: 1.75, contextWindow: 203_000),
        "glm-4.6": Tier(inputPerMillion: 0.39, outputPerMillion: 1.74, contextWindow: 205_000),
        "glm-4.6-thinking": Tier(inputPerMillion: 0.39, outputPerMillion: 1.74, contextWindow: 205_000),
        "glm-4.5v": Tier(inputPerMillion: 0.60, outputPerMillion: 1.80, contextWindow: 66_000),
        "glm-4.5v-thinking": Tier(inputPerMillion: 0.60, outputPerMillion: 1.80, contextWindow: 66_000),
        "glm-4.5": Tier(inputPerMillion: 0.60, outputPerMillion: 2.20, contextWindow: 131_000),
        "glm-4.5-thinking": Tier(inputPerMillion: 0.60, outputPerMillion: 2.20, contextWindow: 131_000),
        "glm-5": Tier(inputPerMillion: 0.72, outputPerMillion: 2.30, contextWindow: 203_000),
        "glm-5-thinking": Tier(inputPerMillion: 0.72, outputPerMillion: 2.30, contextWindow: 203_000),
    ]

    /// Returns pricing tier for a model code, case-insensitive with fuzzy matching.
    public static func tier(for modelCode: String) -> Tier? {
        let key = modelCode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = self.tiers[key] { return exact }
        return self.tiers.first { key.contains($0.key) || $0.key.contains(key) }?.value
    }

    /// Estimates cost assuming a 60/40 input/output token split (typical for coding).
    public static func estimateCost(tokens: Int, modelCode: String) -> Double? {
        guard let tier = self.tier(for: modelCode), tokens > 0 else { return nil }
        let inputTokens = Double(tokens) * 0.6
        let outputTokens = Double(tokens) * 0.4
        let inputCost = (inputTokens / 1_000_000) * tier.inputPerMillion
        let outputCost = (outputTokens / 1_000_000) * tier.outputPerMillion
        return inputCost + outputCost
    }
}
