import Foundation
import RunicCore
import SwiftUI
import Testing
@testable import Runic

extension UsageMenuCardView.Model.Input {
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
        ledgerTopModelContextLabel: String? = nil,
        ledgerTopProject: UsageLedgerProjectSummary? = nil,
        ledgerSpendForecast: UsageLedgerSpendForecast? = nil,
        ledgerTopProjectSpendForecast: UsageLedgerSpendForecast? = nil,
        ledgerAnomaly: UsageLedgerAnomalySummary? = nil,
        ledgerCompaction: UsageLedgerCompactionSummary? = nil,
        ledgerReliability: UsageLedgerReliabilityScore? = nil,
        ledgerRouting: UsageLedgerRoutingRecommendation? = nil,
        ledgerError: String? = nil,
        ledgerUpdatedAt: Date? = nil,
        providerContextStatus: ProviderContextWindowLabel? = nil,
        account: AccountInfo,
        isRefreshing: Bool,
        lastError: String?,
        usageBarsShowUsed: Bool,
        menuMode: MenuMode = .operator,
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
            ledgerTopModelContextLabel: ledgerTopModelContextLabel,
            ledgerTopProject: ledgerTopProject,
            ledgerSpendForecast: ledgerSpendForecast,
            ledgerTopProjectSpendForecast: ledgerTopProjectSpendForecast,
            ledgerAnomaly: ledgerAnomaly,
            ledgerCompaction: ledgerCompaction,
            ledgerReliability: ledgerReliability,
            ledgerRouting: ledgerRouting,
            ledgerError: ledgerError,
            ledgerUpdatedAt: ledgerUpdatedAt,
            providerContextStatus: providerContextStatus,
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

struct MenuCardModelTests {
    @Test
    func `builds metrics using remaining percent`() throws {
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
        let metadata = try #require(ProviderDefaults.metadata[.codex])
        let updatedSnap = try UsageSnapshot(
            primary: snapshot.primary,
            secondary: RateWindow(
                usedPercent: #require(snapshot.secondary?.usedPercent),
                windowMinutes: #require(snapshot.secondary?.windowMinutes),
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
    func `builds metrics using used percent when enabled`() throws {
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
        let metadata = try #require(ProviderDefaults.metadata[.codex])

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
        #expect(model.metrics.first?.percentLabel?.contains("used") == true)
        #expect(model.metrics.contains { $0.title == "Code review" && $0.percent == 27 })
    }

    @Test
    func `shows code review metric when dashboard present`() throws {
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
        let metadata = try #require(ProviderDefaults.metadata[.codex])

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
    func `claude model hides weekly when unavailable`() throws {
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
        let metadata = try #require(ProviderDefaults.metadata[.claude])
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
    func `shows error subtitle when present`() throws {
        let metadata = try #require(ProviderDefaults.metadata[.codex])
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
    func `cost section includes last30 days tokens`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.codex])
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
    func `claude model does not leak codex plan`() throws {
        let metadata = try #require(ProviderDefaults.metadata[.claude])
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
    func `non-codex credits render as text without a bar`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.deepseek])
        #expect(metadata.supportsCredits)
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: 49.58 CNY",
                hasKnownLimit: false),
            secondary: nil,
            tertiary: nil,
            updatedAt: now)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .deepseek,
            metadata: metadata,
            snapshot: snapshot,
            credits: CreditsSnapshot(remaining: 49.58, events: [], updatedAt: now),
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
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        // The balance renders as a text line; the "of 1K credits" gauge is
        // codex-only, so no bar denominator is invented for currency balances.
        #expect(model.creditsText == "49.58 left")
        #expect(model.creditsRemaining == nil)
    }

    @Test
    func `codex credits keep the thousand-credit bar`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.codex])
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            updatedAt: now)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: snapshot,
            credits: CreditsSnapshot(remaining: 250, events: [], updatedAt: now),
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
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        #expect(model.creditsText == "250 left")
        #expect(model.creditsRemaining == 250)
    }

    @Test
    func `hides codex credits when disabled`() throws {
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
        let metadata = try #require(ProviderDefaults.metadata[.codex])

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
    func `renders tertiary window for non-opus providers using its label`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.copilot])
        #expect(metadata.supportsOpus == false)
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 10,
                windowMinutes: nil,
                resetsAt: now.addingTimeInterval(600),
                resetDescription: nil,
                label: "Premium"),
            secondary: RateWindow(
                usedPercent: 20,
                windowMinutes: nil,
                resetsAt: now.addingTimeInterval(600),
                resetDescription: nil,
                label: "Completions"),
            tertiary: RateWindow(
                usedPercent: 30,
                windowMinutes: nil,
                resetsAt: now.addingTimeInterval(600),
                resetDescription: nil,
                label: "Chat"),
            updatedAt: now)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .copilot,
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
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        let tertiary = try #require(model.metrics.first { $0.id == "tertiary" })
        #expect(tertiary.title == "Chat")
        #expect(tertiary.percent == 70)
    }

    @Test
    func `keeps metadata opus label for claude tertiary`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.claude])
        #expect(metadata.supportsOpus)
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: RateWindow(
                usedPercent: 30,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: nil,
                label: "some-window-label"),
            updatedAt: now)

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
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        let tertiary = try #require(model.metrics.first { $0.id == "tertiary" })
        #expect(tertiary.title == metadata.opusLabel)
    }

    @Test
    func `hides percent gauge for windows without a known limit`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.kimi])
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: 12.34",
                hasKnownLimit: false),
            secondary: nil,
            tertiary: nil,
            updatedAt: now)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .kimi,
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
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        let primary = try #require(model.metrics.first)
        #expect(primary.percent == nil)
        #expect(primary.percentLabel == nil)
        #expect(primary.resetText == "Balance: 12.34")
    }

    @Test
    func `shows cursor on demand cost with limit`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.cursor])
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 40, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            providerCost: ProviderCostSnapshot(used: 12, limit: 50, currencyCode: "USD", updatedAt: now),
            updatedAt: now)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .cursor,
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
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        let cost = try #require(model.providerCost)
        #expect(cost.title == "On-demand usage")
        #expect(cost.percentUsed == 24)
        #expect(cost.spendLine.contains("/"))
    }

    @Test
    func `shows cursor unlimited on demand spend without a gauge`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.cursor])
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 40, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            providerCost: ProviderCostSnapshot(used: 12, limit: 0, currencyCode: "USD", updatedAt: now),
            updatedAt: now)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .cursor,
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
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        let cost = try #require(model.providerCost)
        #expect(cost.percentUsed == nil)
        #expect(!cost.spendLine.contains("/"))
    }

    @Test
    func `hides claude extra usage when disabled`() throws {
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
        let metadata = try #require(ProviderDefaults.metadata[.claude])

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
}
