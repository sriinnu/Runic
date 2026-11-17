import Foundation

enum CostUsagePricing {
    struct CodexPricing {
        let inputCostPerToken: Double
        let outputCostPerToken: Double
        let cacheReadInputCostPerToken: Double
    }

    struct ClaudePricing {
        let inputCostPerToken: Double
        let outputCostPerToken: Double
        let cacheCreationInputCostPerToken: Double
        let cacheReadInputCostPerToken: Double

        let thresholdTokens: Int?
        let inputCostPerTokenAboveThreshold: Double?
        let outputCostPerTokenAboveThreshold: Double?
        let cacheCreationInputCostPerTokenAboveThreshold: Double?
        let cacheReadInputCostPerTokenAboveThreshold: Double?
    }

    private static let codex: [String: CodexPricing] = [
        "gpt-5": CodexPricing(
            inputCostPerToken: 1.25e-6,
            outputCostPerToken: 1e-5,
            cacheReadInputCostPerToken: 1.25e-7),
        "gpt-5-codex": CodexPricing(
            inputCostPerToken: 1.25e-6,
            outputCostPerToken: 1e-5,
            cacheReadInputCostPerToken: 1.25e-7),
        "gpt-5.1": CodexPricing(
            inputCostPerToken: 1.25e-6,
            outputCostPerToken: 1e-5,
            cacheReadInputCostPerToken: 1.25e-7),
        "gpt-5.2": CodexPricing(
            inputCostPerToken: 1.75e-6,
            outputCostPerToken: 1.4e-5,
            cacheReadInputCostPerToken: 1.75e-7),
        "gpt-5.2-codex": CodexPricing(
            inputCostPerToken: 1.75e-6,
            outputCostPerToken: 1.4e-5,
            cacheReadInputCostPerToken: 1.75e-7),
        // gpt-5.3 / 5.4 / 5.5 + the 5.4 mini tier. Rates from the local kosha
        // registry (per-million ÷ 1e6). gpt-5.3-codex and gpt-5.3-codex-spark both
        // normalize to "gpt-5.3" via the -codex strip and share its 5.2-level rate.
        "gpt-5.3": CodexPricing(
            inputCostPerToken: 1.75e-6,
            outputCostPerToken: 1.4e-5,
            cacheReadInputCostPerToken: 1.75e-7),
        "gpt-5.4": CodexPricing(
            inputCostPerToken: 2.5e-6,
            outputCostPerToken: 1.5e-5,
            cacheReadInputCostPerToken: 2.5e-7),
        "gpt-5.4-mini": CodexPricing(
            inputCostPerToken: 7.5e-7,
            outputCostPerToken: 4.5e-6,
            cacheReadInputCostPerToken: 7.5e-8),
        // gpt-5.6 and later price from the models.dev catalog (with its
        // long-context tiers): the hand-kept 5.6/6.x rates here were wrong.
        "gpt-5.5": CodexPricing(
            inputCostPerToken: 5e-6,
            outputCostPerToken: 3e-5,
            cacheReadInputCostPerToken: 5e-7),
    ]

    private static let claude: [String: ClaudePricing] = [
        "claude-haiku-4-5-20251001": ClaudePricing(
            inputCostPerToken: 1e-6,
            outputCostPerToken: 5e-6,
            cacheCreationInputCostPerToken: 1.25e-6,
            cacheReadInputCostPerToken: 1e-7,
            thresholdTokens: nil,
            inputCostPerTokenAboveThreshold: nil,
            outputCostPerTokenAboveThreshold: nil,
            cacheCreationInputCostPerTokenAboveThreshold: nil,
            cacheReadInputCostPerTokenAboveThreshold: nil),
        "claude-opus-4-5-20251101": ClaudePricing(
            inputCostPerToken: 5e-6,
            outputCostPerToken: 2.5e-5,
            cacheCreationInputCostPerToken: 6.25e-6,
            cacheReadInputCostPerToken: 5e-7,
            thresholdTokens: nil,
            inputCostPerTokenAboveThreshold: nil,
            outputCostPerTokenAboveThreshold: nil,
            cacheCreationInputCostPerTokenAboveThreshold: nil,
            cacheReadInputCostPerTokenAboveThreshold: nil),
        "claude-sonnet-4-5": ClaudePricing(
            inputCostPerToken: 3e-6,
            outputCostPerToken: 1.5e-5,
            cacheCreationInputCostPerToken: 3.75e-6,
            cacheReadInputCostPerToken: 3e-7,
            thresholdTokens: 200_000,
            inputCostPerTokenAboveThreshold: 6e-6,
            outputCostPerTokenAboveThreshold: 2.25e-5,
            cacheCreationInputCostPerTokenAboveThreshold: 7.5e-6,
            cacheReadInputCostPerTokenAboveThreshold: 6e-7),
        "claude-sonnet-4-5-20250929": ClaudePricing(
            inputCostPerToken: 3e-6,
            outputCostPerToken: 1.5e-5,
            cacheCreationInputCostPerToken: 3.75e-6,
            cacheReadInputCostPerToken: 3e-7,
            thresholdTokens: 200_000,
            inputCostPerTokenAboveThreshold: 6e-6,
            outputCostPerTokenAboveThreshold: 2.25e-5,
            cacheCreationInputCostPerTokenAboveThreshold: 7.5e-6,
            cacheReadInputCostPerTokenAboveThreshold: 6e-7),
        "claude-opus-4-20250514": ClaudePricing(
            inputCostPerToken: 1.5e-5,
            outputCostPerToken: 7.5e-5,
            cacheCreationInputCostPerToken: 1.875e-5,
            cacheReadInputCostPerToken: 1.5e-6,
            thresholdTokens: nil,
            inputCostPerTokenAboveThreshold: nil,
            outputCostPerTokenAboveThreshold: nil,
            cacheCreationInputCostPerTokenAboveThreshold: nil,
            cacheReadInputCostPerTokenAboveThreshold: nil),
        "claude-opus-4-1": ClaudePricing(
            inputCostPerToken: 1.5e-5,
            outputCostPerToken: 7.5e-5,
            cacheCreationInputCostPerToken: 1.875e-5,
            cacheReadInputCostPerToken: 1.5e-6,
            thresholdTokens: nil,
            inputCostPerTokenAboveThreshold: nil,
            outputCostPerTokenAboveThreshold: nil,
            cacheCreationInputCostPerTokenAboveThreshold: nil,
            cacheReadInputCostPerTokenAboveThreshold: nil),
        "claude-sonnet-4-20250514": ClaudePricing(
            inputCostPerToken: 3e-6,
            outputCostPerToken: 1.5e-5,
            cacheCreationInputCostPerToken: 3.75e-6,
            cacheReadInputCostPerToken: 3e-7,
            thresholdTokens: 200_000,
            inputCostPerTokenAboveThreshold: 6e-6,
            outputCostPerTokenAboveThreshold: 2.25e-5,
            cacheCreationInputCostPerTokenAboveThreshold: 7.5e-6,
            cacheReadInputCostPerTokenAboveThreshold: 6e-7),
    ]

    static func normalizeCodexModel(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("openai/") {
            trimmed = String(trimmed.dropFirst("openai/".count))
        }
        if let codexRange = trimmed.range(of: "-codex") {
            let base = String(trimmed[..<codexRange.lowerBound])
            if self.codex[base] != nil { return base }
        }
        return trimmed
    }

    /// Catalog list per log family. Only the vendor's own list, never a reseller's.
    static let openAIVendor = "openai"
    static let anthropicVendor = "anthropic"

    static func catalogPrice(vendor: String, model: String, catalog: ModelPriceCatalog) -> ModelPrice? {
        if let price = catalog.vendorPrice(vendor, model: model) { return price }
        if vendor == self.openAIVendor, let codexRange = model.range(of: "-codex") {
            return catalog.vendorPrice(vendor, model: String(model[..<codexRange.lowerBound]))
        }
        return nil
    }

    static func normalizeClaudeModel(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("anthropic.") {
            trimmed = String(trimmed.dropFirst("anthropic.".count))
        }

        if let lastDot = trimmed.lastIndex(of: "."),
           trimmed.contains("claude-")
        {
            let tail = String(trimmed[trimmed.index(after: lastDot)...])
            if tail.hasPrefix("claude-") {
                trimmed = tail
            }
        }

        if let vRange = trimmed.range(of: #"-v\d+:\d+$"#, options: .regularExpression) {
            trimmed.removeSubrange(vRange)
        }

        if let baseRange = trimmed.range(of: #"-\d{8}$"#, options: .regularExpression) {
            let base = String(trimmed[..<baseRange.lowerBound])
            if self.claude[base] != nil {
                return base
            }
        }

        return trimmed
    }

    static func codexCostUSD(
        model: String,
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        catalog: ModelPriceCatalog? = nil) -> Double?
    {
        let key = self.normalizeCodexModel(model)
        let cached = min(max(0, cachedInputTokens), max(0, inputTokens))
        let nonCached = max(0, inputTokens - cached)
        guard let pricing = self.codex[key] else {
            let catalog = catalog ?? ModelPriceCatalogStore.shared.pricingCatalog()
            guard let price = self.catalogPrice(vendor: self.openAIVendor, model: key, catalog: catalog)
            else { return nil }
            // Codex input already includes the cached tokens: context = input.
            return price.rates(forContextTokens: max(0, inputTokens))
                .cost(input: nonCached, output: max(0, outputTokens), cacheWrite: 0, cacheRead: cached)
        }
        return Double(nonCached) * pricing.inputCostPerToken
            + Double(cached) * pricing.cacheReadInputCostPerToken
            + Double(max(0, outputTokens)) * pricing.outputCostPerToken
    }

    static func claudeCostUSD(
        model: String,
        inputTokens: Int,
        cacheReadInputTokens: Int,
        cacheCreationInputTokens: Int,
        outputTokens: Int,
        catalog: ModelPriceCatalog? = nil) -> Double?
    {
        let key = self.normalizeClaudeModel(model)
        let input = max(0, inputTokens)
        let cacheRead = max(0, cacheReadInputTokens)
        let cacheCreation = max(0, cacheCreationInputTokens)
        let output = max(0, outputTokens)

        guard let pricing = self.claude[key] else {
            let catalog = catalog ?? ModelPriceCatalogStore.shared.pricingCatalog()
            guard let price = self.catalogPrice(vendor: self.anthropicVendor, model: key, catalog: catalog)
            else { return nil }
            return price.rates(forContextTokens: input + cacheRead + cacheCreation)
                .cost(input: input, output: output, cacheWrite: cacheCreation, cacheRead: cacheRead)
        }

        // Anthropic long-context billing is whole-request: once the input context
        // (input + cache reads + cache writes) EXCEEDS the threshold, EVERY token
        // of EVERY class — including all output — bills at the premium rate. The
        // premium is never applied per class above the boundary. Exactly-at-
        // threshold requests (e.g. 200K on the nose) bill at base rates:
        // Anthropic's rule is "exceeds", not "reaches".
        let contextTokens = input + cacheRead + cacheCreation
        let isLongContext = pricing.thresholdTokens.map { contextTokens > $0 } ?? false

        func rate(_ base: Double, _ above: Double?) -> Double {
            isLongContext ? (above ?? base) : base
        }

        return Double(input) * rate(pricing.inputCostPerToken, pricing.inputCostPerTokenAboveThreshold)
            + Double(cacheRead) * rate(
                pricing.cacheReadInputCostPerToken,
                pricing.cacheReadInputCostPerTokenAboveThreshold)
            + Double(cacheCreation) * rate(
                pricing.cacheCreationInputCostPerToken,
                pricing.cacheCreationInputCostPerTokenAboveThreshold)
            + Double(output) * rate(pricing.outputCostPerToken, pricing.outputCostPerTokenAboveThreshold)
    }
}
