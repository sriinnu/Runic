import Foundation
import RunicCore
import Testing
@testable import Runic

extension MenuCardModelTests {
    @Test
    func `insights show forecast and budget ETA for top project`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.codex])
        let topProject = UsageLedgerProjectSummary(
            provider: .codex,
            projectKey: "id:proj-runic",
            projectID: "proj-runic",
            projectName: "Runic",
            entryCount: 5,
            totals: UsageLedgerTotals(
                inputTokens: 2000,
                outputTokens: 1000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: 12.5),
            modelsUsed: ["gpt-5"])
        let providerForecast = UsageLedgerSpendForecast(
            provider: .codex,
            observedDays: 3,
            observedCostUSD: 36,
            averageDailyCostUSD: 12,
            projected30DayCostUSD: 360,
            projectedCostP50USD: 330,
            projectedCostP80USD: 420,
            projectedCostP95USD: 510)
        let projectForecast = UsageLedgerSpendForecast(
            provider: .codex,
            projectKey: "id:proj-runic",
            projectID: "proj-runic",
            projectName: "Runic",
            observedDays: 3,
            observedCostUSD: 36,
            averageDailyCostUSD: 12,
            projected30DayCostUSD: 360)
            .applyingBudget(monthlyLimitUSD: 60)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            ledgerTopProject: topProject,
            ledgerSpendForecast: providerForecast,
            ledgerTopProjectSpendForecast: projectForecast,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        #expect(model.insights?.forecastLine?.contains("Month-end forecast") == true)
        #expect(model.insights?.forecastLine?.contains("p80") == true)
        #expect(model.insights?.forecastLine?.contains("p95") == true)
        #expect(model.insights?.projectDetail?.contains("Budget") == true)
        #expect(model.insights?.projectDetail?.contains("Breach") == true)
    }

    @Test
    func `insights surface anomaly severity line`() throws {
        let metadata = try #require(ProviderDefaults.metadata[.codex])
        let anomaly = UsageLedgerAnomalySummary(
            provider: .codex,
            baselineDays: 7,
            tokenAnomaly: UsageLedgerAnomalySummary.MetricAnomaly(
                metric: .tokens,
                severity: .high,
                todayValue: 4200,
                baselineAverage: 1500,
                percentIncrease: 1.8),
            spendAnomaly: UsageLedgerAnomalySummary.MetricAnomaly(
                metric: .spend,
                severity: .elevated,
                todayValue: 17.5,
                baselineAverage: 9.0,
                percentIncrease: 0.94))
        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            ledgerAnomaly: anomaly,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: Date()))

        #expect(model.insights?.anomalyLine == "Anomaly: High tokens spike")
        #expect(model.insights?.anomalyDetail?.contains("+180%") == true)
    }
}
