import Testing
@testable import RunicCore

struct CostUsagePricingTests {
    @Test
    func `normalizes codex model variants`() {
        #expect(CostUsagePricing.normalizeCodexModel("openai/gpt-5-codex") == "gpt-5")
        #expect(CostUsagePricing.normalizeCodexModel("gpt-5.2-codex") == "gpt-5.2")
        #expect(CostUsagePricing.normalizeCodexModel("gpt-5.1-codex-max") == "gpt-5.1")
    }

    @Test
    func `codex cost supports gpt51 codex max`() {
        let cost = CostUsagePricing.codexCostUSD(
            model: "gpt-5.1-codex-max",
            inputTokens: 100,
            cachedInputTokens: 10,
            outputTokens: 5)
        #expect(cost != nil)
    }

    @Test
    func `codex cost supports gpt53 54 55 model families`() {
        // gpt-5.3-codex and -codex-spark both normalize to gpt-5.3.
        #expect(CostUsagePricing.normalizeCodexModel("gpt-5.3-codex") == "gpt-5.3")
        #expect(CostUsagePricing.normalizeCodexModel("gpt-5.3-codex-spark") == "gpt-5.3")
        for model in ["gpt-5.3-codex", "gpt-5.3-codex-spark", "gpt-5.4", "gpt-5.4-mini", "gpt-5.5"] {
            let cost = CostUsagePricing.codexCostUSD(
                model: model,
                inputTokens: 1000,
                cachedInputTokens: 100,
                outputTokens: 50)
            #expect(cost != nil && (cost ?? 0) > 0, "expected priced cost for \(model)")
        }
    }

    @Test
    func `codex cost returns nil for unknown models`() {
        // codex-auto-review is not a real model — no fabricated price.
        let cost = CostUsagePricing.codexCostUSD(
            model: "codex-auto-review",
            inputTokens: 1000,
            cachedInputTokens: 0,
            outputTokens: 50)
        #expect(cost == nil)
    }

    @Test
    func `normalizes claude opus41 dated variants`() {
        #expect(CostUsagePricing.normalizeClaudeModel("claude-opus-4-1-20250805") == "claude-opus-4-1")
    }

    @Test
    func `claude cost supports opus41 dated variant`() {
        let cost = CostUsagePricing.claudeCostUSD(
            model: "claude-opus-4-1-20250805",
            inputTokens: 10,
            cacheReadInputTokens: 0,
            cacheCreationInputTokens: 0,
            outputTokens: 5)
        #expect(cost != nil)
    }

    @Test
    func `claude cost returns nil for unknown models`() {
        let cost = CostUsagePricing.claudeCostUSD(
            model: "glm-4.6",
            inputTokens: 100,
            cacheReadInputTokens: 500,
            cacheCreationInputTokens: 0,
            outputTokens: 40)
        #expect(cost == nil)
    }
}
