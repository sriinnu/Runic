import AppKit
import RunicCore
import Testing
@testable import Runic

@MainActor
struct StatusMenuTests {
    @Test(arguments: [false, true])
    func `OpenAI web errors do not replace the credits balance`(enabled: Bool) throws {
        let settings = SettingsStore(
            userDefaults: Self.isolatedDefaults(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.openAIWebAccessEnabled = enabled
        settings.showOptionalCreditsAndExtraUsage = true
        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        store.lastOpenAIDashboardError = "Web sign-in needed"
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())
        let model = try #require(controller.menuCardModel(for: .codex))
        #expect(model.creditsText == "0 left")
        #expect(model.creditsHintText == "Balance unavailable; showing 0 until the next refresh.")
        #expect(model.creditsHintText?.contains("Web sign-in needed") == false)
    }

    /// Each test gets a fresh defaults suite so it neither reads the developer's
    /// real Runic preferences (a menu selection made in the running app) nor
    /// writes provider toggles back into them.
    static func isolatedDefaults() -> UserDefaults {
        let suite = "StatusMenuTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        TestDefaults.track(suite)
        defaults.set(true, forKey: "providerDetectionCompleted")
        return defaults
    }

    @Test(arguments: [MenuMode.glance, .analyst, .operator])
    func `standard menu reserves credit purchase action for operator`(mode: MenuMode) throws {
        let settings = SettingsStore(
            userDefaults: Self.isolatedDefaults(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = false
        settings.menuMode = mode
        settings.showOptionalCreditsAndExtraUsage = true
        let metadata = try #require(ProviderRegistry.shared.metadata[.codex])
        settings.setProviderEnabled(provider: .codex, metadata: metadata, enabled: true)
        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        store.credits = CreditsSnapshot(remaining: 42, events: [], updatedAt: Date())
        store._setSnapshotForTesting(UsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: Date()), provider: .codex)
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())
        let menu = controller.makeMenu(for: .codex)
        controller.menuWillOpen(menu)
        #expect(menu.items.contains { $0.title == "Buy Credits..." } == (mode == .operator))
    }

    @Test
    func `remembers provider when menu opens`() {
        let settings = SettingsStore(
            userDefaults: Self.isolatedDefaults(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.menuMode = .operator

        let registry = ProviderRegistry.shared
        if let codexMeta = registry.metadata[.codex] {
            settings.setProviderEnabled(provider: .codex, metadata: codexMeta, enabled: false)
        }
        if let claudeMeta = registry.metadata[.claude] {
            settings.setProviderEnabled(provider: .claude, metadata: claudeMeta, enabled: true)
        }
        if let geminiMeta = registry.metadata[.gemini] {
            settings.setProviderEnabled(provider: .gemini, metadata: geminiMeta, enabled: false)
        }

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())

        let claudeMenu = controller.makeMenu()
        controller.menuWillOpen(claudeMenu)
        #expect(controller.lastMenuProvider == .claude)

        // No providers enabled: fall back to Codex.
        if let claudeMeta = registry.metadata[.claude] {
            settings.setProviderEnabled(provider: .claude, metadata: claudeMeta, enabled: false)
        }
        let unmappedMenu = controller.makeMenu()
        controller.menuWillOpen(unmappedMenu)
        #expect(controller.lastMenuProvider == .codex)
    }

    @Test
    func `hides open AI web submenus when no history`() {
        let settings = SettingsStore(
            userDefaults: Self.isolatedDefaults(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.menuMode = .operator
        settings.selectedMenuProvider = .codex

        let registry = ProviderRegistry.shared
        if let codexMeta = registry.metadata[.codex] {
            settings.setProviderEnabled(provider: .codex, metadata: codexMeta, enabled: true)
        }
        if let claudeMeta = registry.metadata[.claude] {
            settings.setProviderEnabled(provider: .claude, metadata: claudeMeta, enabled: false)
        }
        if let geminiMeta = registry.metadata[.gemini] {
            settings.setProviderEnabled(provider: .gemini, metadata: geminiMeta, enabled: false)
        }

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        store.openAIDashboard = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            codeReviewRemainingPercent: 100,
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            updatedAt: Date())

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)
        let titles = Set(menu.items.map(\.title))
        #expect(!titles.contains("Credits history"))
        #expect(!titles.contains("Usage breakdown"))
    }

    @Test
    func `shows open AI web submenus when history exists`() throws {
        let settings = SettingsStore(
            userDefaults: Self.isolatedDefaults(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.menuMode = .operator
        settings.selectedMenuProvider = .codex

        let registry = ProviderRegistry.shared
        if let codexMeta = registry.metadata[.codex] {
            settings.setProviderEnabled(provider: .codex, metadata: codexMeta, enabled: true)
        }
        if let claudeMeta = registry.metadata[.claude] {
            settings.setProviderEnabled(provider: .claude, metadata: claudeMeta, enabled: false)
        }
        if let geminiMeta = registry.metadata[.gemini] {
            settings.setProviderEnabled(provider: .gemini, metadata: geminiMeta, enabled: false)
        }

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)

        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2025
        components.month = 12
        components.day = 18
        let date = try #require(components.date)

        let events = [CreditEvent(date: date, service: "CLI", creditsUsed: 1)]
        let breakdown = OpenAIDashboardSnapshot.makeDailyBreakdown(from: events, maxDays: 30)
        store.openAIDashboard = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            codeReviewRemainingPercent: 100,
            creditEvents: events,
            dailyBreakdown: breakdown,
            usageBreakdown: breakdown,
            creditsPurchaseURL: nil,
            updatedAt: Date())

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)
        let usageItem = menu.items.first { ($0.representedObject as? String) == "menuCardUsage" }
        let creditsItem = menu.items.first { ($0.representedObject as? String) == "menuCardCredits" }
        // Chart submenu content is deferred: the id appears once the submenu
        // opens (before that the placeholder carries the deferred content box).
        let usageSubmenu = try #require(usageItem?.submenu)
        let creditsSubmenu = try #require(creditsItem?.submenu)
        controller.menuWillOpen(usageSubmenu)
        controller.menuWillOpen(creditsSubmenu)
        #expect(usageSubmenu.items
            .contains { ($0.representedObject as? String) == "usageBreakdownChart" } == true)
        #expect(creditsSubmenu.items
            .contains { ($0.representedObject as? String) == "creditsHistoryChart" } == true)
    }

    @Test
    func `shows credits before cost in codex menu card sections`() throws {
        let settings = SettingsStore(
            userDefaults: Self.isolatedDefaults(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.menuMode = .operator
        settings.selectedMenuProvider = .codex
        settings.costUsageEnabled = true

        let registry = ProviderRegistry.shared
        if let codexMeta = registry.metadata[.codex] {
            settings.setProviderEnabled(provider: .codex, metadata: codexMeta, enabled: true)
        }
        if let claudeMeta = registry.metadata[.claude] {
            settings.setProviderEnabled(provider: .claude, metadata: claudeMeta, enabled: false)
        }
        if let geminiMeta = registry.metadata[.gemini] {
            settings.setProviderEnabled(provider: .gemini, metadata: geminiMeta, enabled: false)
        }

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        store.credits = CreditsSnapshot(remaining: 100, events: [], updatedAt: Date())
        store.openAIDashboard = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            codeReviewRemainingPercent: 100,
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            updatedAt: Date())
        store._setTokenSnapshotForTesting(CostUsageTokenSnapshot(
            sessionTokens: 123,
            sessionCostUSD: 0.12,
            last30DaysTokens: 123,
            last30DaysCostUSD: 1.23,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2025-12-23",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: 123,
                    costUSD: 1.23,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
            ],
            updatedAt: Date()), provider: .codex)

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)
        let ids = menu.items.compactMap { $0.representedObject as? String }
        let creditsIndex = ids.firstIndex(of: "menuCardCredits")
        let costIndex = ids.firstIndex(of: "menuCardCost")
        #expect(creditsIndex != nil)
        #expect(costIndex != nil)
        #expect(try #require(creditsIndex) < costIndex!)
    }

    @Test
    func `shows extra usage for claude when using menu card sections`() {
        let settings = SettingsStore(
            userDefaults: Self.isolatedDefaults(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.menuMode = .operator
        settings.selectedMenuProvider = .claude
        settings.costUsageEnabled = true
        settings.claudeWebExtrasEnabled = true

        let registry = ProviderRegistry.shared
        if let codexMeta = registry.metadata[.codex] {
            settings.setProviderEnabled(provider: .codex, metadata: codexMeta, enabled: false)
        }
        if let claudeMeta = registry.metadata[.claude] {
            settings.setProviderEnabled(provider: .claude, metadata: claudeMeta, enabled: true)
        }
        if let geminiMeta = registry.metadata[.gemini] {
            settings.setProviderEnabled(provider: .gemini, metadata: geminiMeta, enabled: false)
        }

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        let identity = ProviderIdentitySnapshot(
            providerID: .claude,
            accountEmail: "user@example.com",
            accountOrganization: nil,
            loginMethod: "web")
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: nil, resetsAt: nil, resetDescription: "Resets soon"),
            secondary: nil,
            tertiary: nil,
            providerCost: ProviderCostSnapshot(
                used: 0,
                limit: 2000,
                currencyCode: "EUR",
                period: "Monthly",
                resetsAt: nil,
                updatedAt: Date()),
            updatedAt: Date(),
            identity: identity)
        store._setSnapshotForTesting(snapshot, provider: .claude)
        store._setTokenSnapshotForTesting(CostUsageTokenSnapshot(
            sessionTokens: 123,
            sessionCostUSD: 0.12,
            last30DaysTokens: 123,
            last30DaysCostUSD: 1.23,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2025-12-23",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: 123,
                    costUSD: 1.23,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
            ],
            updatedAt: Date()), provider: .claude)

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)
        let ids = menu.items.compactMap { $0.representedObject as? String }
        #expect(ids.contains("menuCardExtraUsage"))
    }

    @Test(arguments: [false, true], [UsageProvider.codex, .claude, .cursor, .ollamacloud, .xai])
    func `glance mode respects optional credits setting`(showCredits: Bool, provider: UsageProvider) throws {
        let settings = SettingsStore(
            userDefaults: Self.isolatedDefaults(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = false
        settings.selectedMenuProvider = provider
        settings.costUsageEnabled = true
        settings.menuMode = .glance
        settings.showOptionalCreditsAndExtraUsage = showCredits

        let registry = ProviderRegistry.shared
        if let codexMeta = registry.metadata[.codex] {
            settings.setProviderEnabled(provider: .codex, metadata: codexMeta, enabled: true)
        }
        if let claudeMeta = registry.metadata[.claude] {
            settings.setProviderEnabled(provider: .claude, metadata: claudeMeta, enabled: false)
        }
        if let geminiMeta = registry.metadata[.gemini] {
            settings.setProviderEnabled(provider: .gemini, metadata: geminiMeta, enabled: false)
        }

        if let metadata = registry.metadata[provider] {
            settings.setProviderEnabled(provider: provider, metadata: metadata, enabled: true)
        }

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        store.credits = CreditsSnapshot(remaining: 100, events: [], updatedAt: Date())
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                secondary: nil,
                tertiary: nil,
                providerCost: provider == .codex ? nil :
                    ProviderCostSnapshot(used: 5, limit: 20, currencyCode: "USD", updatedAt: Date()),
                updatedAt: Date()),
            provider: provider)
        store._setTokenSnapshotForTesting(CostUsageTokenSnapshot(
            sessionTokens: 123,
            sessionCostUSD: 0.12,
            last30DaysTokens: 123,
            last30DaysCostUSD: 1.23,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2025-12-23",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: 123,
                    costUSD: 1.23,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
            ],
            updatedAt: Date()), provider: .codex)

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())

        let menu = controller.makeMenu(for: provider)
        let model = try #require(controller.menuCardModel(for: provider))
        controller.addMenuCardSections(
            to: menu,
            request: .init(
                model: model,
                provider: provider,
                width: 320,
                sidebar: nil,
                webItems: .init(hasUsageBreakdown: false, hasCreditsHistory: false, hasCostHistory: false),
                animateEntrance: false))
        let ids = menu.items.compactMap { $0.representedObject as? String }
        let usageItem = menu.items.first { ($0.representedObject as? String) == "menuCardUsage" }

        #expect(ids.contains("menuCardUsage"))
        #expect(ids
            .contains("menuCardCredits") ==
            (showCredits && registry.metadata[provider]?.supportsCredits == true && provider != .cursor))
        #expect(ids.contains("menuCardExtraUsage") == (showCredits && provider != .codex))
        #expect(!ids.contains("menuCardCost"))
        #expect(!ids.contains("menuCardInsights"))
        #expect(usageItem?.submenu == nil)
        #expect(!menu.items.contains { $0.title == "Buy Credits..." })
    }

    @Test
    func `analyst mode shows summary without actions`() {
        let settings = SettingsStore(
            userDefaults: Self.isolatedDefaults(),
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.selectedMenuProvider = .codex
        settings.costUsageEnabled = true
        settings.menuMode = .analyst

        let registry = ProviderRegistry.shared
        if let codexMeta = registry.metadata[.codex] {
            settings.setProviderEnabled(provider: .codex, metadata: codexMeta, enabled: true)
        }
        if let claudeMeta = registry.metadata[.claude] {
            settings.setProviderEnabled(provider: .claude, metadata: claudeMeta, enabled: false)
        }
        if let geminiMeta = registry.metadata[.gemini] {
            settings.setProviderEnabled(provider: .gemini, metadata: geminiMeta, enabled: false)
        }

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        store.credits = CreditsSnapshot(remaining: 100, events: [], updatedAt: Date())
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date()),
            provider: .codex)
        store._setTokenSnapshotForTesting(CostUsageTokenSnapshot(
            sessionTokens: 123,
            sessionCostUSD: 0.12,
            last30DaysTokens: 123,
            last30DaysCostUSD: 1.23,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2025-12-23",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: 123,
                    costUSD: 1.23,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
            ],
            updatedAt: Date()), provider: .codex)

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)
        let ids = menu.items.compactMap { $0.representedObject as? String }
        let usageItem = menu.items.first { ($0.representedObject as? String) == "menuCardUsage" }
        let creditsItem = menu.items.first { ($0.representedObject as? String) == "menuCardCredits" }
        let costItem = menu.items.first { ($0.representedObject as? String) == "menuCardCost" }

        #expect(ids.contains("menuCardUsage"))
        #expect(ids.contains("menuCardCredits"))
        #expect(ids.contains("menuCardCost"))
        #expect(!ids.contains("menuCardInsights"))
        #expect(usageItem?.submenu == nil)
        #expect(creditsItem?.submenu == nil)
        #expect(costItem?.submenu == nil)
        #expect(!menu.items.contains { $0.title == "Buy Credits..." })
    }
}
