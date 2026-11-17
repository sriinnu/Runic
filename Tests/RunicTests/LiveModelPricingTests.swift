import Foundation
import Testing
@testable import RunicCore

/// Claude 4.6+ / 5.x and Codex gpt-5.6+ / 6.x were missing from the hand-kept
/// table, so every day on them saved at $0. They price from the catalog now.
struct LiveModelPricingTests {
    private static let haikuTier = ModelPriceTier(
        contextAbove: 100_000,
        input: 0.5,
        output: 2.5,
        cacheRead: 0.05,
        cacheWrite: 0.625)
    private static let solTier = ModelPriceTier(
        contextAbove: 272_000,
        input: 4,
        output: 15,
        cacheRead: 0.2,
        cacheWrite: 5)

    private let catalog = ModelPriceCatalog(
        prices: [
            "anthropic": [
                "claude-opus-5-5": ModelPrice(input: 4, output: 20, cacheRead: 0.2, cacheWrite: 5),
                "claude-haiku-5-5": ModelPrice(
                    input: 0.1,
                    output: 0.5,
                    cacheRead: 0.01,
                    cacheWrite: 0.125,
                    tiers: [LiveModelPricingTests.haikuTier]),
            ],
            "openai": [
                "gpt-6.2-sol": ModelPrice(
                    input: 2,
                    output: 10,
                    cacheRead: 0.1,
                    cacheWrite: 2.5,
                    tiers: [LiveModelPricingTests.solTier]),
            ],
            "openrouter": ["gpt-6.9-fake": ModelPrice(input: 99, output: 99)],
        ],
        snapshot: "test")

    private func claude(_ model: String, input: Int, read: Int = 0, write: Int = 0, output: Int = 0) -> Double? {
        CostUsagePricing.claudeCostUSD(
            model: model,
            inputTokens: input,
            cacheReadInputTokens: read,
            cacheCreationInputTokens: write,
            outputTokens: output,
            catalog: self.catalog)
    }

    private func codex(_ model: String, input: Int, cached: Int, output: Int) -> Double? {
        CostUsagePricing.codexCostUSD(
            model: model,
            inputTokens: input,
            cachedInputTokens: cached,
            outputTokens: output,
            catalog: self.catalog)
    }

    @Test
    func `claude 5 models price from the catalog`() {
        let cost = self.claude("claude-opus-5-5", input: 1000, read: 1_000_000, write: 10000, output: 2000)
        let micros = 1000.0 * 4 + 1_000_000.0 * 0.2 + 10000.0 * 5 + 2000.0 * 20
        #expect(abs((cost ?? -1) - micros / 1_000_000) < 1e-12)
    }

    @Test
    func `claude dated and bedrock ids reach the catalog`() {
        for model in ["claude-opus-5-5-20260922", "anthropic.claude-opus-5-5"] {
            #expect(self.claude(model, input: 1_000_000) == 4, "\(model)")
        }
    }

    @Test
    func `long context tier bills the whole request`() {
        // 90K fresh + 20K cache read = 110K context, past haiku 5.5's 100K tier.
        let cost = self.claude("claude-haiku-5-5", input: 90000, read: 20000, output: 1000)
        let micros = 90000.0 * 0.5 + 20000.0 * 0.05 + 1000.0 * 2.5
        #expect(abs((cost ?? -1) - micros / 1_000_000) < 1e-12)

        // Exactly at the size stays on base rates.
        let atBoundary = self.claude("claude-haiku-5-5", input: 100_000)
        #expect(abs((atBoundary ?? -1) - 0.01) < 1e-12)
    }

    @Test
    func `codex 6 models price from the catalog with tiers`() {
        let base = self.codex("gpt-6.2-sol", input: 200_000, cached: 150_000, output: 1000)
        let baseMicros = 50000.0 * 2 + 150_000.0 * 0.1 + 1000.0 * 10
        #expect(abs((base ?? -1) - baseMicros / 1_000_000) < 1e-12)

        let long = self.codex("openai/gpt-6.2-sol-codex", input: 300_000, cached: 200_000, output: 1000)
        let longMicros = 100_000.0 * 4 + 200_000.0 * 0.2 + 1000.0 * 15
        #expect(abs((long ?? -1) - longMicros / 1_000_000) < 1e-12)
    }

    @Test
    func `never prices from a reseller list`() {
        #expect(self.codex("gpt-6.9-fake", input: 1000, cached: 0, output: 10) == nil)
    }

    @Test
    func `bundled snapshot prices the models in use`() {
        let bundled = ModelPriceCatalog.bundled
        let claudeModels = ["claude-opus-5-5", "claude-fable-5-2", "claude-haiku-5-5", "claude-sonnet-5-5"]
        for model in claudeModels + ["claude-opus-4-6"] {
            #expect(bundled.vendorPrice("anthropic", model: model) != nil, "\(model)")
        }
        for model in ["gpt-6-sol", "gpt-6.1-sol", "gpt-6.2-sol", "gpt-6.2-astra", "gpt-6-luna", "gpt-5.6-sol"] {
            #expect(bundled.vendorPrice("openai", model: model)?.tiers?.isEmpty == false, "\(model)")
        }
    }

    @Test
    func `models dev tiers parse and round trip`() throws {
        let json = """
        {"openai":{"models":{"gpt-6.2-astra":{"cost":{"input":8,"output":40,"cache_read":0.4,
        "tiers":[{"input":16,"output":60,"cache_read":0.8,"tier":{"type":"context","size":272000}},
        {"input":1,"output":1,"tier":{"type":"batch"}}]}}}}}
        """
        let catalog = try ModelPriceCatalog.fromModelsDev(Data(json.utf8), snapshot: "t")
        let price = try #require(catalog.vendorPrice("openai", model: "gpt-6.2-astra"))
        #expect(price.tiers == [ModelPriceTier(contextAbove: 272_000, input: 16, output: 60, cacheRead: 0.8)])
        let decoded = try ModelPriceCatalog.decodeSnapshot(catalog.encodedSnapshot())
        #expect(decoded == catalog)
    }

    @Test
    func `context windows cover current models`() {
        #expect(UsageFormatter.modelContextWindow(for: "claude-opus-5-5") == 1_000_000)
        #expect(UsageFormatter.modelContextWindow(for: "claude-fable-5-2") == 1_000_000)
        #expect(UsageFormatter.modelContextWindow(for: "gpt-6.1-sol") == 500_000)
        #expect(UsageFormatter.modelContextWindow(for: "gpt-6-sol") == 272_000)
    }
}
