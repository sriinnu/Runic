import RunicCore
import Foundation
import SwiftUI
import Testing
@testable import Runic

private extension UsageMenuCardView.Model.Input {
    init(
        provider: UsageProvider,
        metadata: ProviderMetadata,
        snapshot: UsageSnapshot?,
        credits: CreditsSnapshot?,
        creditsError: String?,
        dashboard: OpenAIDashboardSnapshot?,
        dashboardError: String?,
        tokenSnapshot: CostUsageTokenSnapshot?,
        tokenError: String?,
        ledgerDaily: UsageLedgerDailySummary? = nil,
        ledgerActiveBlock: UsageLedgerBlockSummary? = nil,
        ledgerTopModel: UsageLedgerModelSummary? = nil,
        ledgerTopProject: UsageLedgerProjectSummary? = nil,
        ledgerSpendForecast: UsageLedgerSpendForecast? = nil,
        ledgerTopProjectSpendForecast: UsageLedgerSpendForecast? = nil,
        ledgerAnomaly: UsageLedgerAnomalySummary? = nil,
        ledgerReliability: UsageLedgerReliabilityScore? = nil,
        ledgerRouting: UsageLedgerRoutingRecommendation? = nil,
        ledgerError: String? = nil,
        ledgerUpdatedAt: Date? = nil,
        account: AccountInfo,
        isRefreshing: Bool,
        lastError: String?,
        usageBarsShowUsed: Bool,
        menuMode: MenuMode = .`operator`,
        tokenCostUsageEnabled: Bool,
        showOptionalCreditsAndExtraUsage: Bool,
        now: Date)
    {
        self.init(
            provider: provider,
            metadata: metadata,
            snapshot: snapshot,
            credits: credits,
            creditsError: creditsError,
            dashboard: dashboard,
            dashboardError: dashboardError,
            tokenSnapshot: tokenSnapshot,
            tokenError: tokenError,
            ledgerDaily: ledgerDaily,
            ledgerActiveBlock: ledgerActiveBlock,
            ledgerTopModel: ledgerTopModel,
            ledgerTopProject: ledgerTopProject,
            ledgerSpendForecast: ledgerSpendForecast,
            ledgerTopProjectSpendForecast: ledgerTopProjectSpendForecast,
            ledgerAnomaly: ledgerAnomaly,
            ledgerReliability: ledgerReliability,
            ledgerRouting: ledgerRouting,
            ledgerError: ledgerError,
            ledgerUpdatedAt: ledgerUpdatedAt,
            account: account,
            isRefreshing: isRefreshing,
            lastError: lastError,
            usageBarsShowUsed: usageBarsShowUsed,
            usageMetricDisplayMode: .barsAndPercent,
            menuMode: menuMode,
            tokenCostUsageEnabled: tokenCostUsageEnabled,
            showOptionalCreditsAndExtraUsage: showOptionalCreditsAndExtraUsage,
            now: now)
    }
}

@Suite
struct MenuCardModelTests {
    @Test
    func buildsMetricsUsingRemainingPercent() {
        let now = Date()
        let identity = ProviderIdentitySnapshot(
            providerID: .codex,
            accountEmail: "codex@example.com",
            accountOrganization: nil,
            loginMethod: "Plus Plan")
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 22,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(3000),
                resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 40,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(6000),
                resetDescription: nil),
            updatedAt: now,
            identity: identity)
        let metadata = ProviderDefaults.metadata[.codex]!
        let updatedSnap = UsageSnapshot(
            primary: snapshot.primary,
            secondary: RateWindow(
                usedPercent: snapshot.secondary!.usedPercent,
                windowMinutes: snapshot.secondary!.windowMinutes,
                resetsAt: now.addingTimeInterval(3600),
                resetDescription: nil),
            tertiary: snapshot.tertiary,
            updatedAt: now,
            identity: identity)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: updatedSnap,
            credits: CreditsSnapshot(remaining: 12, events: [], updatedAt: now),
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "codex@example.com", plan: "Plus Plan"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        #expect(model.providerName == "Codex")
        #expect(model.metrics.count == 2)
        #expect(model.metrics.first?.percent == 78)
        #expect(model.planText == "Plus")
        #expect(model.subtitleText.hasPrefix("Updated"))
        #expect(model.progressColor != Color.clear)
        #expect(model.metrics[1].resetText?.isEmpty == false)
    }

    @Test
    func buildsMetricsUsingUsedPercentWhenEnabled() {
        let now = Date()
        let identity = ProviderIdentitySnapshot(
            providerID: .codex,
            accountEmail: "codex@example.com",
            accountOrganization: nil,
            loginMethod: "Plus Plan")
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 22,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(3000),
                resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 40,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(6000),
                resetDescription: nil),
            updatedAt: now,
            identity: identity)
        let metadata = ProviderDefaults.metadata[.codex]!

        let dashboard = OpenAIDashboardSnapshot(
            signedInEmail: "codex@example.com",
            codeReviewRemainingPercent: 73,
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            updatedAt: now)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: dashboard,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "codex@example.com", plan: "Plus Plan"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: true,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        #expect(model.metrics.first?.title == "Session")
        #expect(model.metrics.first?.percent == 22)
        #expect(model.metrics.first?.percentLabel.contains("used") == true)
        #expect(model.metrics.contains { $0.title == "Code review" && $0.percent == 27 })
    }

    @Test
    func showsCodeReviewMetricWhenDashboardPresent() {
        let now = Date()
        let identity = ProviderIdentitySnapshot(
            providerID: .codex,
            accountEmail: "codex@example.com",
            accountOrganization: nil,
            loginMethod: nil)
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 0, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            updatedAt: now,
            identity: identity)
        let metadata = ProviderDefaults.metadata[.codex]!

        let dashboard = OpenAIDashboardSnapshot(
            signedInEmail: "codex@example.com",
            codeReviewRemainingPercent: 73,
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            updatedAt: now)
        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: dashboard,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "codex@example.com", plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        #expect(model.metrics.contains { $0.title == "Code review" && $0.percent == 73 })
    }

    @Test
    func claudeModelHidesWeeklyWhenUnavailable() {
        let now = Date()
        let identity = ProviderIdentitySnapshot(
            providerID: .claude,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "Max")
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 2,
                windowMinutes: nil,
                resetsAt: now.addingTimeInterval(3600),
                resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            updatedAt: now,
            identity: identity)
        let metadata = ProviderDefaults.metadata[.claude]!
        let model = UsageMenuCardView.Model.make(.init(
            provider: .claude,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "codex@example.com", plan: "plus"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        #expect(model.metrics.count == 1)
        #expect(model.metrics.first?.title == "Session")
        #expect(model.planText == "Max")
    }

    @Test
    func showsErrorSubtitleWhenPresent() {
        let metadata = ProviderDefaults.metadata[.codex]!
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
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: "Probe failed for Codex",
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: Date()))

        #expect(model.subtitleStyle == .error)
        #expect(model.subtitleText.contains("Probe failed"))
        #expect(model.placeholder == nil)
    }

    @Test
    func costSectionIncludesLast30DaysTokens() {
        let now = Date()
        let metadata = ProviderDefaults.metadata[.codex]!
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 0, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            updatedAt: now)
        let tokenSnapshot = CostUsageTokenSnapshot(
            sessionTokens: 123,
            sessionCostUSD: 1.23,
            last30DaysTokens: 456,
            last30DaysCostUSD: 78.9,
            daily: [],
            updatedAt: now)
        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: tokenSnapshot,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: true,
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        #expect(model.tokenUsage?.monthLine.contains("456") == true)
        #expect(model.tokenUsage?.monthLine.contains("tokens") == true)
    }

    @Test
    func claudeModelDoesNotLeakCodexPlan() {
        let metadata = ProviderDefaults.metadata[.claude]!
        let model = UsageMenuCardView.Model.make(.init(
            provider: .claude,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "codex@example.com", plan: "plus"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: Date()))

        #expect(model.planText == nil)
        #expect(model.email.isEmpty)
    }

    @Test
    func hidesCodexCreditsWhenDisabled() {
        let now = Date()
        let identity = ProviderIdentitySnapshot(
            providerID: .codex,
            accountEmail: "codex@example.com",
            accountOrganization: nil,
            loginMethod: nil)
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 0, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            updatedAt: now,
            identity: identity)
        let metadata = ProviderDefaults.metadata[.codex]!

        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: snapshot,
            credits: CreditsSnapshot(remaining: 12, events: [], updatedAt: now),
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "codex@example.com", plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: false,
            now: now))

        #expect(model.creditsText == nil)
    }

    @Test
    func hidesClaudeExtraUsageWhenDisabled() {
        let now = Date()
        let identity = ProviderIdentitySnapshot(
            providerID: .claude,
            accountEmail: "claude@example.com",
            accountOrganization: nil,
            loginMethod: nil)
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 0, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            providerCost: ProviderCostSnapshot(used: 12, limit: 200, currencyCode: "USD", updatedAt: now),
            updatedAt: now,
            identity: identity)
        let metadata = ProviderDefaults.metadata[.claude]!

        let model = UsageMenuCardView.Model.make(.init(
            provider: .claude,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: false,
            now: now))

        #expect(model.providerCost == nil)
    }

    @Test
    func insightsShowForecastAndBudgetETAForTopProject() {
        let now = Date()
        let metadata = ProviderDefaults.metadata[.codex]!
        let topProject = UsageLedgerProjectSummary(
            provider: .codex,
            projectKey: "id:proj-runic",
            projectID: "proj-runic",
            projectName: "Runic",
            entryCount: 5,
            totals: UsageLedgerTotals(
                inputTokens: 2_000,
                outputTokens: 1_000,
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
    func insightsSurfaceAnomalySeverityLine() {
        let metadata = ProviderDefaults.metadata[.codex]!
        let anomaly = UsageLedgerAnomalySummary(
            provider: .codex,
            baselineDays: 7,
            tokenAnomaly: UsageLedgerAnomalySummary.MetricAnomaly(
                metric: .tokens,
                severity: .high,
                todayValue: 4_200,
                baselineAverage: 1_500,
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
