import Foundation
import RunicCore
import Testing
@testable import Runic
@testable import RunicCLI

@MainActor
struct UIAndCLIAuditRegressionTests {
    @Test
    func `windowTitle and formattedWindowDescription preserve explicit labels and status phrases`() {
        let labeled = RateWindow(
            usedPercent: 12,
            windowMinutes: 300,
            resetsAt: nil,
            resetDescription: nil,
            label: "  Gemini 5h ")
        #expect(UsageFormatter.windowTitle(for: labeled, fallback: "Session") == "Gemini 5h")

        let unlabeled = RateWindow(usedPercent: 12, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        #expect(UsageFormatter.windowTitle(for: unlabeled, fallback: "Session") == "Session")

        #expect(UsageFormatter.formattedWindowDescription("Balance: $12.00") == "Balance: $12.00")
        #expect(UsageFormatter.formattedWindowDescription("Quota available") == "Quota available")
        #expect(UsageFormatter.formattedWindowDescription("17 requests") == "17 requests")
        #expect(UsageFormatter.formattedWindowDescription("in 2h 30m") == "Resets in 2h 30m")
    }

    @Test
    func `menuBarWavePercents follow preferred quota window and hide limitless balances`() {
        let now = Date(timeIntervalSince1970: 1_795_590_000)
        let antigravity = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 10,
                windowMinutes: 300,
                resetsAt: now,
                resetDescription: nil,
                label: "Gemini 5h"),
            secondary: RateWindow(
                usedPercent: 20,
                windowMinutes: 10080,
                resetsAt: now,
                resetDescription: nil,
                label: "Gemini Weekly"),
            tertiary: RateWindow(
                usedPercent: 80,
                windowMinutes: 10080,
                resetsAt: now,
                resetDescription: nil,
                label: "Claude & GPT Weekly"),
            updatedAt: now)
        let waves = StatusItemController.menuBarWavePercents(for: .antigravity, snapshot: antigravity, showUsed: false)
        #expect(waves.0 == 90)
        #expect(waves.1 == 80)

        let walletOnly = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: $10.00",
                hasKnownLimit: false),
            secondary: nil,
            updatedAt: now)
        let walletWaves = StatusItemController.menuBarWavePercents(
            for: .vercelai,
            snapshot: walletOnly,
            showUsed: false)
        #expect(walletWaves.0 == nil && walletWaves.1 == nil)

        let factory = UsageSnapshot(
            primary: RateWindow(usedPercent: 15, windowMinutes: 43200, resetsAt: nil, resetDescription: nil),
            secondary: RateWindow(usedPercent: 45, windowMinutes: 43200, resetsAt: nil, resetDescription: nil),
            updatedAt: now)
        let factoryWaves = StatusItemController.menuBarWavePercents(for: .factory, snapshot: factory, showUsed: true)
        #expect(factoryWaves.0 == 45)
        #expect(factoryWaves.1 == 15)
    }

    @Test
    func `usageStore decouples single provider refresh, surfaces manual failures, and tracks balance blocks`() {
        let settings = SettingsStore(
            userDefaults: TestDefaults.isolated(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        let store = UsageStore(fetcher: UsageFetcher(environment: [:]), settings: settings)

        store.isGlobalRefreshing = true
        #expect(store.isRefreshing(provider: .antigravity) == false)
        #expect(store.isRefreshing(provider: nil) == true)
        store.activeSingleRefreshes.insert(.antigravity)
        #expect(store.isRefreshing(provider: .antigravity) == true)
        store.activeSingleRefreshes.removeAll()
        store.isGlobalRefreshing = false

        let prior = UsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: Date())
        store._setSnapshotForTesting(prior, provider: .antigravity)

        store.recordProviderFetchFailure(.antigravity, message: "transient", forceSurface: false)
        #expect(store.errors[.antigravity] == nil)
        store.recordProviderFetchFailure(.antigravity, message: "manual fail", forceSurface: true)
        #expect(store.errors[.antigravity] == "manual fail")

        let activeBalance = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: $5.00",
                hasKnownLimit: false),
            secondary: nil,
            balance: ProviderBalance(available: 5.0, currency: "USD", apiCallsAllowed: true),
            updatedAt: Date())
        store.handleSessionQuotaTransition(provider: .openrouter, snapshot: activeBalance)
        #expect(store.lastKnownSessionRemaining[.openrouter] == 100)

        let blockedBalance = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: $0.00",
                hasKnownLimit: false),
            secondary: nil,
            balance: ProviderBalance(available: 0.0, currency: "USD", apiCallsAllowed: false),
            updatedAt: Date())
        store.handleSessionQuotaTransition(provider: .openrouter, snapshot: blockedBalance)
        #expect(store.lastKnownSessionRemaining[.openrouter] == 0)
    }

    @Test
    func `menuCard, resetSchedule, and CLI renderers honor labels and additionalWindows`() {
        let now = Date(timeIntervalSince1970: 1_795_590_000)
        let metadata = ProviderDescriptorRegistry.descriptor(for: .antigravity).metadata
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 2.24,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(3600),
                resetDescription: "Resets in 1h",
                label: "Gemini 5h"),
            secondary: RateWindow(
                usedPercent: 3.78,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(7200),
                resetDescription: "Resets in 2h",
                label: "Gemini Weekly"),
            tertiary: RateWindow(
                usedPercent: 0,
                windowMinutes: 300,
                resetsAt: nil,
                resetDescription: "Quota available",
                label: "Claude & GPT 5h"),
            additionalWindows: [
                RateWindow(
                    usedPercent: 45.41,
                    windowMinutes: 10080,
                    resetsAt: now.addingTimeInterval(10800),
                    resetDescription: "Resets in 3h",
                    label: "Claude & GPT Weekly"),
            ],
            updatedAt: now)

        let cardInput = UsageMenuCardView.Model.Input(
            provider: .antigravity,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            ledgerDaily: nil,
            ledgerActiveBlock: nil,
            ledgerTopModel: nil,
            ledgerTopModelContextLabel: nil,
            ledgerTopProject: nil,
            ledgerSpendForecast: nil,
            ledgerTopProjectSpendForecast: nil,
            ledgerAnomaly: nil,
            ledgerCompaction: nil,
            ledgerReliability: nil,
            ledgerRouting: nil,
            ledgerError: nil,
            ledgerUpdatedAt: nil,
            providerContextStatus: nil,
            account: AccountInfo(email: nil, plan: "Google AI Ultra"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            usageMetricDisplayMode: .barsAndPercent,
            menuMode: .operator,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: false,
            now: now)
        let cardModel = UsageMenuCardView.Model.make(cardInput)
        #expect(cardModel.metrics.map(\.title) == [
            "Gemini 5h",
            "Gemini Weekly",
            "Claude & GPT 5h",
            "Claude & GPT Weekly",
        ])

        let scheduleEntries = ResetScheduleBuilder.entries(
            [ResetScheduleBuilder.ProviderInput(provider: .antigravity, metadata: metadata, snapshot: snapshot)],
            now: now)
        #expect(scheduleEntries.map(\.windowTitle) == [
            "Gemini 5h",
            "Gemini Weekly",
            "Claude & GPT Weekly",
        ])

        let cliRendered = CLIRenderer.renderText(
            provider: .antigravity,
            snapshot: snapshot,
            credits: nil,
            context: RenderContext(header: metadata.displayName, useColor: false))
        #expect(cliRendered.contains("Antigravity"))
        #expect(cliRendered.contains("Gemini 5h:"))
        #expect(cliRendered.contains("Claude & GPT Weekly:"))
        #expect(!cliRendered.contains("Resets Quota available"))

        let usageText = RunicCLI.renderUsageText(
            provider: .antigravity,
            snapshot: snapshot,
            credits: nil,
            header: metadata.displayName,
            useColor: false)
        #expect(usageText.contains("Claude & GPT Weekly:"))

        let resetInfo = ResetCommand.buildResetInfo(provider: .antigravity, snapshot: snapshot, metadata: metadata)
        #expect(resetInfo.windows.map(\.windowName) == [
            "Gemini 5h",
            "Gemini Weekly",
            "Claude & GPT 5h",
            "Claude & GPT Weekly",
        ])
    }
}
