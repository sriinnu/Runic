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

        #expect(UsageFormatter.formattedWindowDescription("").isEmpty)
        #expect(UsageFormatter.formattedWindowDescription("   ").isEmpty)
        #expect(UsageFormatter.formattedWindowDescription("Balance: $12.00") == "Balance: $12.00")
        #expect(UsageFormatter.formattedWindowDescription("80 / 100 remaining") == "80 / 100 remaining")
        #expect(UsageFormatter.formattedWindowDescription("Ollama online · 3 models") == "Ollama online · 3 models")
        #expect(UsageFormatter.formattedWindowDescription("5 hours window") == "5 hours window")
        #expect(UsageFormatter.formattedWindowDescription(
            "50 of 100 prompts left this minute") == "50 of 100 prompts left this minute")
        #expect(UsageFormatter.formattedWindowDescription("Usage fetched at 12:00") == "Usage fetched at 12:00")
        #expect(UsageFormatter.formattedWindowDescription("Input: 100 · Output: 50") == "Input: 100 · Output: 50")
        #expect(UsageFormatter.formattedWindowDescription("Quota available") == "Quota available")
        #expect(UsageFormatter.formattedWindowDescription("17 requests") == "17 requests")
        #expect(UsageFormatter.formattedWindowDescription("in 2h 30m") == "Resets in 2h 30m")
        #expect(UsageFormatter.formattedWindowDescription("at 7:39 PM") == "Resets at 7:39 PM")
        #expect(UsageFormatter.formattedWindowDescription("Weekly") == "Resets Weekly")
        #expect(UsageFormatter.formattedWindowDescription("Oct 10 at 2:00 AM") == "Resets Oct 10 at 2:00 AM")
        #expect(UsageFormatter.formattedWindowDescription("Resets in 1h") == "Resets in 1h")
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

        let factoryPrimaryOnly = UsageSnapshot(
            primary: RateWindow(usedPercent: 25, windowMinutes: 43200, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: now)
        let factorySingleWave = StatusItemController.menuBarWavePercents(
            for: .factory,
            snapshot: factoryPrimaryOnly,
            showUsed: true)
        #expect(factorySingleWave.0 == 25)
        #expect(factorySingleWave.1 == nil)

        let factoryLimitlessSecondary = UsageSnapshot(
            primary: RateWindow(usedPercent: 30, windowMinutes: 43200, resetsAt: nil, resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Unlimited",
                hasKnownLimit: false),
            updatedAt: now)
        let factoryFilteredWave = StatusItemController.menuBarWavePercents(
            for: .factory,
            snapshot: factoryLimitlessSecondary,
            showUsed: true)
        #expect(factoryFilteredWave.0 == 30)
        #expect(factoryFilteredWave.1 == nil)
    }

    @Test
    func `usageStore decouples single provider refresh, coalesces fetches, and tracks balance blocks`() async {
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

        // Fresh provider with prior data (streak 0 -> 1) would suppress a non-manual failure;
        // `forceSurface: true` must bypass the consecutive-failure gate on the first attempt.
        store._setSnapshotForTesting(prior, provider: .gemini)
        store.recordProviderFetchFailure(.gemini, message: "manual fail", forceSurface: true)
        #expect(store.errors[.gemini] == "manual fail")

        // Prepaid balance notifications must fire even when `supportsCredits == false`.
        for provider in [UsageProvider.openrouter, .cline, .kimi, .stepfun] {
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
            store.handleSessionQuotaTransition(provider: provider, snapshot: activeBalance)
            #expect(store.lastKnownSessionRemaining[provider] == 100)

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
            store.handleSessionQuotaTransition(provider: provider, snapshot: blockedBalance)
            #expect(store.lastKnownSessionRemaining[provider] == 0)
        }

        // Overlapping per-account fetches coalesce onto a single execution.
        var fetchCalls = 0
        settings.setProviderEnabled(
            provider: .antigravity,
            metadata: store.metadata(for: .antigravity),
            enabled: true)
        store.providerSpecs[.antigravity] = ProviderSpec(
            style: .antigravity,
            isEnabled: { true },
            fetch: { _, _ in
                await MainActor.run { fetchCalls += 1 }
                try? await Task.sleep(for: .milliseconds(120))
                let snap = UsageSnapshot(
                    primary: RateWindow(usedPercent: 42, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                    secondary: nil,
                    updatedAt: Date())
                let result = ProviderFetchResult(
                    usage: snap,
                    credits: nil,
                    dashboard: nil,
                    sourceLabel: "mock",
                    strategyID: "mock.antigravity",
                    strategyKind: .cli)
                return ProviderFetchOutcome(
                    result: .success(result),
                    attempts: [ProviderFetchAttempt(
                        strategyID: "mock.antigravity",
                        kind: .cli,
                        wasAvailable: true,
                        errorDescription: nil)])
            })

        async let singleRun: Void = store.refreshSingleProvider(.antigravity)
        try? await Task.sleep(for: .milliseconds(20))
        #expect(store.isRefreshing(provider: .antigravity) == true)
        #expect(store.isRefreshing(provider: .gemini) == false)

        async let overlappingRun: Void = store.refreshProvider(.antigravity, trigger: .autoTimer)
        _ = await (singleRun, overlappingRun)

        #expect(fetchCalls == 1)
        #expect(store.isRefreshing(provider: .antigravity) == false)
        #expect(store.snapshots[.antigravity]?.primary.usedPercent == 42)
    }

    @Test
    func `menuCard and resetSchedule honor labels, additionalWindows, and opusLabel`() {
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

        // SupportsOpus == false must still honor metadata.opusLabel (Copilot "Chat", OpenRouter "Free requests").
        let copilotMeta = ProviderDescriptorRegistry.descriptor(for: .copilot).metadata
        let copilotSnap = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 10,
                windowMinutes: 43200,
                resetsAt: now.addingTimeInterval(600),
                resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 20,
                windowMinutes: 43200,
                resetsAt: now.addingTimeInterval(900),
                resetDescription: nil),
            tertiary: RateWindow(
                usedPercent: 30,
                windowMinutes: 43200,
                resetsAt: now.addingTimeInterval(1200),
                resetDescription: nil),
            updatedAt: now)
        let copilotEntries = ResetScheduleBuilder.entries(
            [ResetScheduleBuilder.ProviderInput(provider: .copilot, metadata: copilotMeta, snapshot: copilotSnap)],
            now: now)
        #expect(copilotEntries.last?.windowTitle == "Chat")
    }

    @Test
    func `CLI and NSMenu renderers omit fake percents for limitless windows and propagate exit codes`() async {
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

        let cliRendered = CLIRenderer.renderText(
            provider: .antigravity,
            snapshot: snapshot,
            credits: nil,
            context: RenderContext(header: metadata.displayName, useColor: false))
        #expect(cliRendered.contains("Antigravity"))
        #expect(cliRendered.contains("Gemini 5h:"))
        #expect(cliRendered.contains("Claude & GPT Weekly:"))
        #expect(!cliRendered.contains("Resets Quota available"))

        let walletSnapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: $8.00",
                hasKnownLimit: false),
            secondary: nil,
            updatedAt: now)
        let deepSeekMeta = ProviderDescriptorRegistry.descriptor(for: .deepseek).metadata
        let walletCLI = CLIRenderer.renderText(
            provider: .deepseek,
            snapshot: walletSnapshot,
            credits: nil,
            context: RenderContext(header: deepSeekMeta.displayName, useColor: false))
        #expect(walletCLI.contains("Balance: Balance: $8.00"))
        #expect(!walletCLI.contains("100% left"))

        let usageText = RunicCLI.renderUsageText(
            provider: .antigravity,
            snapshot: snapshot,
            credits: nil,
            header: metadata.displayName,
            useColor: false)
        #expect(usageText.contains("Claude & GPT Weekly:"))

        let resetInfo = ResetCommand.buildResetInfo(provider: .antigravity, snapshot: snapshot, metadata: metadata)
        #expect(resetInfo.providerName == "Antigravity")
        #expect(resetInfo.windows.map(\.windowName) == [
            "Gemini 5h",
            "Gemini Weekly",
            "Claude & GPT 5h",
            "Claude & GPT Weekly",
        ])

        let walletReset = ResetCommand.buildResetInfo(
            provider: .deepseek,
            snapshot: walletSnapshot,
            metadata: deepSeekMeta)
        #expect(walletReset.status == "No quota limit")
        #expect(walletReset.windows.first?.isNearLimit == false)

        // M4: EnhancedUsageCommand comparison ignores limitless windows.
        let deepSeekData = EnhancedUsageCommand.ProviderUsageData(
            provider: .deepseek,
            providerName: deepSeekMeta.displayName,
            snapshot: walletSnapshot,
            credits: nil,
            windows: [EnhancedUsageCommand.WindowData(
                name: "Balance",
                used: nil,
                limit: nil,
                usedPercent: 0,
                remainingPercent: 100,
                resetDescription: "Balance: $8.00",
                hasKnownLimit: false)],
            breakdown: nil,
            trending: nil,
            projected: nil)
        let limitedData = EnhancedUsageCommand.ProviderUsageData(
            provider: .antigravity,
            providerName: metadata.displayName,
            snapshot: snapshot,
            credits: nil,
            windows: [EnhancedUsageCommand.WindowData(
                name: "Gemini 5h",
                used: nil,
                limit: nil,
                usedPercent: 50,
                remainingPercent: 50,
                resetDescription: nil,
                hasKnownLimit: true)],
            breakdown: nil,
            trending: nil,
            projected: nil)
        let comparison = EnhancedUsageCommand.buildComparison(providerData: [deepSeekData, limitedData])
        #expect(comparison?.mostEfficient == "Antigravity")

        let explicitFail = await RunicCLI.executeUsageQuery(
            providers: [.zai],
            options: CLIUsageQueryOptions(explicitFilter: true, isJson: false, isPretty: false, useColor: false))
        { @Sendable _ in throw MockCLIFetchError() }
        #expect(explicitFail.exitCode == 1)
        #expect(explicitFail.stdout == nil)
        #expect(explicitFail.stderrErrors.count == 1)

        let allPartial = await RunicCLI.executeUsageQuery(
            providers: [.antigravity, .zai],
            options: CLIUsageQueryOptions(explicitFilter: false, isJson: true, isPretty: false, useColor: false))
        { @Sendable provider in
            if provider == .zai { throw MockCLIFetchError() }
            return (sourceLabel: "mock", usage: snapshot, credits: nil)
        }
        #expect(allPartial.exitCode == 0)
        #expect(allPartial.stdout?.contains("\"error\":\"missing credentials\"") == true)

        let allFailed = await RunicCLI.executeUsageQuery(
            providers: [.antigravity, .zai],
            options: CLIUsageQueryOptions(explicitFilter: false, isJson: true, isPretty: false, useColor: false))
        { @Sendable _ in throw MockCLIFetchError() }
        #expect(allFailed.exitCode == 1)
    }

    @Test
    func `exporters, overview target, store deltas, and menu descriptor cover additionalWindows and wallets`() {
        let now = Date(timeIntervalSince1970: 1_795_590_000)
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
        let walletSnapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: $8.00",
                hasKnownLimit: false),
            secondary: nil,
            updatedAt: now)

        // H3: Overview target resolves to nil in multi-provider popover / merged overview.
        #expect(StatusItemController.resolveRefreshTarget(
            selectedMenuProvider: nil,
            lastMenuProvider: nil,
            isMultiProviderOverviewCapable: true,
            enabledProviders: [.claude, .antigravity]) == nil)
        #expect(StatusItemController.resolveRefreshTarget(
            selectedMenuProvider: nil,
            lastMenuProvider: .antigravity,
            isMultiProviderOverviewCapable: true,
            enabledProviders: [.claude, .antigravity]) == .antigravity)

        // M3 + M4: Exporters, store activity delta, insights helper, and MenuDescriptor.
        let settings = SettingsStore(
            userDefaults: TestDefaults.isolated(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        let store = UsageStore(fetcher: UsageFetcher(environment: [:]), settings: settings)
        store._setSnapshotForTesting(snapshot, provider: .antigravity)

        let csvWindows = UsageExporter.exportCSV(store: store, provider: .antigravity, scope: .windows)
        #expect(csvWindows.contains("Claude & GPT Weekly"))
        let jsonWindows = UsageExporter.exportJSON(store: store, provider: .antigravity, scope: .windows)
        #expect(jsonWindows.contains("Claude & GPT Weekly"))
        #expect(ProviderInsightsComposer.windowModelsValue(snapshot)?.contains("+1 more") == true)

        let updatedFourthOnly = UsageSnapshot(
            primary: snapshot.primary,
            secondary: snapshot.secondary,
            tertiary: snapshot.tertiary,
            additionalWindows: [
                RateWindow(
                    usedPercent: 60.0,
                    windowMinutes: 10080,
                    resetsAt: now.addingTimeInterval(10800),
                    resetDescription: "Resets in 3h",
                    label: "Claude & GPT Weekly"),
            ],
            updatedAt: now.addingTimeInterval(120))
        store.recordUsageActivity(provider: .antigravity, previous: snapshot, current: updatedFourthOnly)
        #expect(store.lastUsageDeltaAt[.antigravity] == now.addingTimeInterval(120))

        store._setSnapshotForTesting(walletSnapshot, provider: .deepseek)
        let walletDescriptor = MenuDescriptor.build(
            provider: .deepseek,
            store: store,
            settings: settings,
            account: AccountInfo(email: nil, plan: nil),
            updateReady: false)
        let walletTexts = walletDescriptor.sections.flatMap(\.entries).compactMap { entry -> String? in
            if case let .text(text, _) = entry { return text }
            return nil
        }
        #expect(!walletTexts.contains { $0.contains("100% left") })
        #expect(walletTexts.contains { $0.contains("Balance: $8.00") })
    }
}

private struct MockCLIFetchError: LocalizedError {
    var errorDescription: String? {
        "missing credentials"
    }
}
