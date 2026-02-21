import Foundation
import Testing

@testable import RunicCore

@Suite
struct UsageLedgerInsightsAdvisorTests {
    @Test
    func reliabilityScoreDropsWhenErrorsExist() {
        let now = Date()
        let daily = UsageLedgerDailySummary(
            provider: .codex,
            projectID: nil,
            dayStart: now,
            dayKey: "2026-02-21",
            totals: UsageLedgerTotals(
                inputTokens: 1_000,
                outputTokens: 500,
                cacheCreationTokens: 100,
                cacheReadTokens: 200,
                costUSD: 2.5),
            modelsUsed: ["gpt-5"])

        let scoreWithoutErrors = UsageLedgerInsightsAdvisor.reliabilityScore(
            provider: .codex,
            daily: daily,
            activeBlock: nil,
            modelBreakdown: [],
            projectBreakdown: [],
            providerError: nil,
            ledgerError: nil)
        let scoreWithErrors = UsageLedgerInsightsAdvisor.reliabilityScore(
            provider: .codex,
            daily: daily,
            activeBlock: nil,
            modelBreakdown: [],
            projectBreakdown: [],
            providerError: "fetch failed",
            ledgerError: "parse failed")

        #expect(scoreWithoutErrors != nil)
        #expect(scoreWithErrors != nil)
        #expect((scoreWithErrors?.score ?? 0) < (scoreWithoutErrors?.score ?? 100))
    }

    @Test
    func routingRecommendationFindsSavingsBetweenModels() {
        let expensive = UsageLedgerModelSummary(
            provider: .codex,
            projectID: "proj-a",
            projectName: "Project A",
            model: "gpt-5",
            entryCount: 20,
            totals: UsageLedgerTotals(
                inputTokens: 30_000,
                outputTokens: 20_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: 12.0))

        let cheaper = UsageLedgerModelSummary(
            provider: .codex,
            projectID: "proj-a",
            projectName: "Project A",
            model: "gpt-5-mini",
            entryCount: 30,
            totals: UsageLedgerTotals(
                inputTokens: 40_000,
                outputTokens: 20_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: 3.0))

        let recommendation = UsageLedgerInsightsAdvisor.routingRecommendation(
            modelBreakdown: [expensive, cheaper],
            shiftPercent: 0.20)

        #expect(recommendation != nil)
        #expect((recommendation?.estimatedSavingsUSD ?? 0) > 0)
        #expect(recommendation?.fromModel == "gpt-5")
        #expect(recommendation?.toModel == "gpt-5-mini")
    }
}
