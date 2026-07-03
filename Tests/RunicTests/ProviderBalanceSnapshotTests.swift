import Foundation
import Testing
@testable import RunicCore

/// Providers that report balances/counters without a quota limit must not
/// pretend to have a 0%-used gauge: their primary windows carry the parsed
/// values as text and are flagged `hasKnownLimit == false` so UIs skip the
/// fake percent bar and cross-provider averages exclude them.
struct ProviderBalanceSnapshotTests {
    @Test
    func `kimi balance maps to limitless window with balance text`() {
        let response = KimiBalanceResponse(
            data: KimiBalanceResponse.Balance(
                availableBalance: 12.34,
                voucherBalance: 1.5,
                cashBalance: 2.25),
            status: true)

        let usage = response.toUsageSnapshot()

        #expect(usage.primary.hasKnownLimit == false)
        #expect(usage.primary.usedPercent == 0)
        #expect(usage.primary.windowMinutes == nil)
        #expect(usage.primary.resetsAt == nil)
        #expect(usage.primary.resetDescription?.contains("12.34") == true)
        #expect(usage.primary.resetDescription?.contains("Voucher") == true)
    }

    @Test
    func `deepseek balance maps to limitless window and credits snapshot`() {
        let response = DeepSeekBalanceResponse(
            is_available: true,
            balance_infos: [
                DeepSeekBalanceResponse.BalanceInfo(
                    currency: "USD",
                    total_balance: "5.00",
                    granted_balance: nil,
                    topped_up_balance: nil),
            ])

        let usage = response.toUsageSnapshot()
        let credits = response.toCreditsSnapshot()

        #expect(usage.primary.hasKnownLimit == false)
        #expect(usage.primary.usedPercent == 0)
        #expect(usage.primary.resetDescription?.contains("5.00") == true)
        #expect(usage.primary.resetDescription?.contains("USD") == true)
        #expect(credits.remaining == 5.0)
    }

    @Test
    func `auggie daily metrics map to limitless window with counters`() {
        let metrics = AuggieUsageMetrics(
            requestCount: 3,
            totalTokens: 1200,
            inputTokens: nil,
            outputTokens: nil)

        let usage = metrics.toUsageSnapshot()

        #expect(usage.primary.hasKnownLimit == false)
        #expect(usage.primary.usedPercent == 0)
        #expect(usage.primary.resetDescription == "Requests: 3 · Tokens: 1200")
    }

    @Test
    func `qwen totals surface as summary text on a limitless window`() {
        let snapshot = QwenUsageSnapshot(
            modelEntries: [],
            totalInputTokens: 600,
            totalOutputTokens: 400,
            totalTokens: 1000,
            totalRequests: 4,
            totalEstimatedCostUSD: 0.5,
            updatedAt: Date())

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.primary.hasKnownLimit == false)
        #expect(usage.primary.usedPercent == 0)
        #expect(usage.primary.resetDescription == snapshot.usageSummaryText)
        #expect(snapshot.usageSummaryText.contains("tokens"))
        #expect(snapshot.usageSummaryText.contains("4 req"))
        #expect(snapshot.usageSummaryText.contains("est."))
    }

    @Test
    func `qwen summary omits requests and cost when absent`() {
        let snapshot = QwenUsageSnapshot(
            modelEntries: [],
            totalInputTokens: 0,
            totalOutputTokens: 0,
            totalTokens: 0,
            totalRequests: 0,
            totalEstimatedCostUSD: 0,
            updatedAt: Date())

        #expect(snapshot.usageSummaryText.contains("tokens"))
        #expect(!snapshot.usageSummaryText.contains("req"))
        #expect(!snapshot.usageSummaryText.contains("est."))
    }
}
