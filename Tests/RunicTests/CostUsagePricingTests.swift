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
    func `claude long context request prices every class at premium`() {
        // Anthropic bills the WHOLE request — including all output — at the
        // long-context rate once the input context exceeds 200K, not just the
        // tokens above the boundary.
        let cost = CostUsagePricing.claudeCostUSD(
            model: "claude-sonnet-4-5",
            inputTokens: 250_000,
            cacheReadInputTokens: 0,
            cacheCreationInputTokens: 0,
            outputTokens: 1000)
        let expected = 250_000.0 * 6e-6 + 1000.0 * 2.25e-5
        #expect(abs((cost ?? -1) - expected) < 1e-9)
    }

    @Test
    func `claude cache tokens count toward the long context threshold`() {
        // 150K fresh + 60K cache-read input = 210K context → premium everywhere.
        let cost = CostUsagePricing.claudeCostUSD(
            model: "claude-sonnet-4-5",
            inputTokens: 150_000,
            cacheReadInputTokens: 60000,
            cacheCreationInputTokens: 0,
            outputTokens: 1000)
        let expected = 150_000.0 * 6e-6 + 60000.0 * 6e-7 + 1000.0 * 2.25e-5
        #expect(abs((cost ?? -1) - expected) < 1e-9)
    }

    @Test
    func `claude exactly at threshold context bills base rates`() {
        // Anthropic's long-context rule is "exceeds 200K", not "reaches": a
        // request whose context is exactly 200K bills every class at base.
        let cost = CostUsagePricing.claudeCostUSD(
            model: "claude-sonnet-4-5",
            inputTokens: 200_000,
            cacheReadInputTokens: 0,
            cacheCreationInputTokens: 0,
            outputTokens: 1000)
        let expected = 200_000.0 * 3e-6 + 1000.0 * 1.5e-5
        #expect(abs((cost ?? -1) - expected) < 1e-9)

        // One token past the boundary flips the whole request to premium.
        let premium = CostUsagePricing.claudeCostUSD(
            model: "claude-sonnet-4-5",
            inputTokens: 200_001,
            cacheReadInputTokens: 0,
            cacheCreationInputTokens: 0,
            outputTokens: 1000)
        let expectedPremium = 200_001.0 * 6e-6 + 1000.0 * 2.25e-5
        #expect(abs((premium ?? -1) - expectedPremium) < 1e-9)
    }

    @Test
    func `claude below threshold request prices every class at base`() {
        // 190K context stays below 200K → base rates for every class.
        let cost = CostUsagePricing.claudeCostUSD(
            model: "claude-sonnet-4-5",
            inputTokens: 150_000,
            cacheReadInputTokens: 40000,
            cacheCreationInputTokens: 0,
            outputTokens: 1000)
        let expected = 150_000.0 * 3e-6 + 40000.0 * 3e-7 + 1000.0 * 1.5e-5
        #expect(abs((cost ?? -1) - expected) < 1e-9)
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
