import AppKit
import Foundation
import RunicCore
import Testing
@testable import Runic

/// Tests for the menu UI/UX defect fixes: supplemental text sections,
/// number/date format wiring, Ping-now targeting, keyboard activation,
/// error classification, and provider-name truncation.
@MainActor
struct MenuUXFixesTests {
    // MARK: - UsageFormatter style overloads

    @Test
    func `token count string full style renders grouped digits`() {
        let us = Locale(identifier: "en_US")
        #expect(UsageFormatter.tokenCountString(45234, style: .full, locale: us) == "45,234")
        #expect(UsageFormatter.tokenCountString(999, style: .full, locale: us) == "999")
        #expect(UsageFormatter.tokenCountString(1_250_000, style: .full, locale: us) == "1,250,000")
    }

    @Test
    func `token count string full style uses locale grouping`() {
        // .full follows the user's locale grouping instead of pinning
        // en_US_POSIX (the locale parameter defaults to Locale.current).
        let german = Locale(identifier: "de_DE")
        #expect(UsageFormatter.tokenCountString(45234, style: .full, locale: german) == "45.234")
        #expect(UsageFormatter.tokenCountString(1_250_000, style: .full, locale: german) == "1.250.000")
        let french = Locale(identifier: "fr_FR")
        let frenchResult = UsageFormatter.tokenCountString(45234, style: .full, locale: french)
        // French groups with (narrow) non-breaking spaces; exact codepoint
        // varies by OS version, so assert grouping happened without pinning it.
        #expect(frenchResult.count > "45234".count)
        #expect(!frenchResult.contains(","))
    }

    @Test
    func `token count string abbreviated style matches legacy behavior`() {
        #expect(UsageFormatter.tokenCountString(45234, style: .abbreviated) == UsageFormatter.tokenCountString(45234))
        #expect(UsageFormatter.tokenCountString(45234, style: .abbreviated) == "45K")
    }

    @Test
    func `updated string relative style matches legacy behavior`() {
        let now = Date(timeIntervalSince1970: 1_767_122_400)
        let date = now.addingTimeInterval(-7200)
        #expect(
            UsageFormatter.updatedString(from: date, style: .relative, now: now) ==
                UsageFormatter.updatedString(from: date, now: now))
    }

    @Test
    func `updated string absolute style renders a timestamp`() {
        let now = Date(timeIntervalSince1970: 1_767_122_400)
        let date = now.addingTimeInterval(-7200)
        let result = UsageFormatter.updatedString(from: date, style: .absolute, now: now)
        #expect(result.hasPrefix("Updated "))
        #expect(!result.contains("ago"))
        #expect(!result.contains("just now"))
    }

    @Test
    func `absolute timestamp includes date when not same day`() {
        let now = Date(timeIntervalSince1970: 1_767_122_400)
        let older = now.addingTimeInterval(-5 * 86400)
        let sameDay = UsageFormatter.absoluteTimestampString(from: now, now: now)
        let differentDay = UsageFormatter.absoluteTimestampString(from: older, now: now)
        // Same-day timestamps omit the date part, so they're strictly shorter.
        #expect(differentDay.count > sameDay.count)
    }

    // MARK: - Error classification

    @Test
    func `auth-like errors are classified for recovery`() {
        #expect(MenuCardErrorClassifier.isAuthLike("401 Unauthorized"))
        #expect(MenuCardErrorClassifier.isAuthLike("Please log in to continue"))
        #expect(MenuCardErrorClassifier.isAuthLike("OAuth token expired, sign in again"))
        #expect(MenuCardErrorClassifier.isAuthLike("Missing API key"))
        #expect(MenuCardErrorClassifier.isAuthLike("HTTP 403 Forbidden"))
        #expect(MenuCardErrorClassifier.isAuthLike("Keychain item not found"))
        #expect(MenuCardErrorClassifier.isAuthLike("cookie import required"))
    }

    @Test
    func `non-auth errors are not classified as auth`() {
        #expect(!MenuCardErrorClassifier.isAuthLike("The network connection was lost."))
        #expect(!MenuCardErrorClassifier.isAuthLike("Request timed out"))
        #expect(!MenuCardErrorClassifier.isAuthLike("HTTP 500 internal server error"))
        #expect(!MenuCardErrorClassifier.isAuthLike("Rate limit exceeded, retry later"))
    }

    // MARK: - Provider name abbreviation

    @Test
    func `abbreviated provider name adds ellipsis when truncating`() {
        #expect(StatusItemController.abbreviatedProviderName("Codex") == "Codex")
        #expect(StatusItemController.abbreviatedProviderName("Antigravity") == "AntiG")
        // Unknown long names are prefix-truncated WITH a truncation marker.
        #expect(StatusItemController.abbreviatedProviderName("Continuation") == "Contin\u{2026}")
    }

    @Test
    func `popover provider abbreviation matches the menu switcher`() {
        // Both surfaces delegate the same behavior (shared helper carries the
        // ellipsis marker); they must never drift apart again.
        #expect(ProviderNameAbbreviator.abbreviate("Codex") == "Codex")
        #expect(ProviderNameAbbreviator.abbreviate("Antigravity") == "AntiG")
        #expect(ProviderNameAbbreviator.abbreviate("Continuation") == "Contin\u{2026}")
        for name in ["Codex", "Antigravity", "OpenRouter", "Perplexity", "Azure OpenAI", "Continuation"] {
            #expect(
                MenuPopoverView.abbreviatedProviderName(name) ==
                    StatusItemController.abbreviatedProviderName(name))
        }
    }

    // MARK: - Supplemental descriptor sections

    @Test
    func `cursor on-demand spend lands in a supplemental section when card section is hidden`() {
        let (store, settings) = Self.makeStores(suiteName: "MenuUXFixesTests-cursor")
        // With the optional credits/extra-usage card section hidden, the
        // descriptor's supplemental row is the only On-Demand rendering.
        settings.showOptionalCreditsAndExtraUsage = false
        store.snapshots[.cursor] = UsageSnapshot(
            primary: RateWindow(usedPercent: 40, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            providerCost: ProviderCostSnapshot(
                used: 4.2,
                limit: 20,
                currencyCode: "USD",
                updatedAt: Date()),
            updatedAt: Date())

        let descriptor = MenuDescriptor.build(
            provider: .cursor,
            store: store,
            settings: settings,
            account: AccountInfo(email: nil, plan: nil),
            updateReady: false)

        let supplemental = descriptor.sections.filter(\.isSupplementalInfo)
        #expect(supplemental.count == 1)
        let hasOnDemand = supplemental.first?.entries.contains { entry in
            if case let .text(text, _) = entry { return text.hasPrefix("On-Demand:") }
            return false
        } ?? false
        #expect(hasOnDemand)
        #expect(supplemental.allSatisfy { !$0.hasActions })
    }

    @Test
    func `cursor on-demand supplemental row is suppressed when card section is shown`() {
        let (store, settings) = Self.makeStores(suiteName: "MenuUXFixesTests-cursor-dedupe")
        // Default settings: showOptionalCreditsAndExtraUsage is on, so the
        // SwiftUI card renders the "On-demand usage" section — the descriptor
        // must not emit the same numbers a second time.
        #expect(settings.showOptionalCreditsAndExtraUsage)
        store.snapshots[.cursor] = UsageSnapshot(
            primary: RateWindow(usedPercent: 40, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            providerCost: ProviderCostSnapshot(
                used: 4.2,
                limit: 20,
                currencyCode: "USD",
                updatedAt: Date()),
            updatedAt: Date())

        let descriptor = MenuDescriptor.build(
            provider: .cursor,
            store: store,
            settings: settings,
            account: AccountInfo(email: nil, plan: nil),
            updateReady: false)

        let supplementalTexts: [String] = descriptor.sections
            .filter(\.isSupplementalInfo)
            .flatMap(\.entries)
            .compactMap { entry in
                if case let .text(text, _) = entry { return text }
                return nil
            }
        #expect(!supplementalTexts.contains { $0.hasPrefix("On-Demand:") })
    }

    @Test
    func `claude missing weekly window lands in a supplemental section`() {
        let (store, settings) = Self.makeStores(suiteName: "MenuUXFixesTests-claude")
        store.snapshots[.claude] = UsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: Date())

        let descriptor = MenuDescriptor.build(
            provider: .claude,
            store: store,
            settings: settings,
            account: AccountInfo(email: nil, plan: nil),
            updateReady: false)

        let supplementalTexts: [String] = descriptor.sections
            .filter(\.isSupplementalInfo)
            .flatMap(\.entries)
            .compactMap { entry in
                if case let .text(text, _) = entry { return text }
                return nil
            }
        #expect(supplementalTexts.contains("Weekly usage unavailable for this account."))
    }

    @Test
    func `supplemental section renders in the menu`() {
        let (store, settings) = Self.makeStores(suiteName: "MenuUXFixesTests-menu")
        settings.mergeIcons = true
        // Hide the card's On-demand section so the supplemental row is the
        // (single) rendering the NSMenu must surface.
        settings.showOptionalCreditsAndExtraUsage = false
        Self.enable(only: [.cursor], settings: settings)
        settings.selectedMenuProvider = .cursor
        store.snapshots[.cursor] = UsageSnapshot(
            primary: RateWindow(usedPercent: 40, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            providerCost: ProviderCostSnapshot(
                used: 4.2,
                limit: 0,
                currencyCode: "USD",
                updatedAt: Date()),
            updatedAt: Date())

        let controller = Self.makeController(store: store, settings: settings)
        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)
        #expect(menu.items.contains { $0.title.hasPrefix("On-Demand:") })
    }

    // MARK: - Ping now targeting

    @Test
    func `refresh target prefers last menu provider`() {
        let (store, settings) = Self.makeStores(suiteName: "MenuUXFixesTests-target")
        Self.enable(only: [.claude, .codex], settings: settings)
        let controller = Self.makeController(store: store, settings: settings)

        // Persisted selection must NOT win over the menu the user last opened.
        settings.selectedMenuProvider = .codex
        controller.lastMenuProvider = .claude
        #expect(controller.refreshTargetProvider() == .claude)

        // Same fallback chain as openDashboard when no menu was opened yet.
        controller.lastMenuProvider = nil
        #expect(controller.refreshTargetProvider() == .codex)
    }

    @Test
    func `refresh target is nil for merged menu on overview`() {
        let (store, settings) = Self.makeStores(suiteName: "MenuUXFixesTests-target-overview")
        settings.mergeIcons = true
        // codex intentionally disabled: the old codex fallback would have made
        // "Ping now" a silent no-op from the Overview tab.
        Self.enable(only: [.claude, .cursor], settings: settings)
        settings.selectedMenuProvider = nil
        let controller = Self.makeController(store: store, settings: settings)
        controller.lastMenuProvider = nil

        // Overview: no provider in focus → nil target → refreshNow performs a
        // full store.refresh() across every enabled provider.
        #expect(controller.refreshTargetProvider() == nil)

        // Picking a provider keeps the single-provider ping.
        controller.lastMenuProvider = .cursor
        #expect(controller.refreshTargetProvider() == .cursor)

        // Back on Overview (tab select clears both) → full refresh again.
        settings.selectedMenuProvider = nil
        controller.lastMenuProvider = nil
        #expect(controller.refreshTargetProvider() == nil)
    }

    // MARK: - Keyboard activation

    @Test
    func `refresh row and provider switcher are keyboard activatable`() {
        let (store, settings) = Self.makeStores(suiteName: "MenuUXFixesTests-keyboard")
        settings.mergeIcons = true
        settings.menuMode = .operator
        Self.enable(only: [.claude, .codex], settings: settings)
        let controller = Self.makeController(store: store, settings: settings)

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)

        let refreshItem = menu.items.first { $0.action == #selector(StatusItemController.refreshNow) }
        #expect(refreshItem != nil)
        #expect(refreshItem?.isEnabled == true)
        #expect(refreshItem?.target === controller)

        let tabBarItem = menu.items.first { ($0.representedObject as? String) == "providerTabBar" }
        #expect(tabBarItem != nil)
        #expect(tabBarItem?.isEnabled == true)
        #expect(tabBarItem?.action == #selector(StatusItemController.cycleMenuProvider(_:)))
    }

    @Test
    func `cycle menu provider advances through providers and overview`() {
        let (store, settings) = Self.makeStores(suiteName: "MenuUXFixesTests-cycle")
        settings.mergeIcons = true
        Self.enable(only: [.claude, .codex], settings: settings)
        let controller = Self.makeController(store: store, settings: settings)

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)
        guard let tabBarItem = menu.items.first(where: { ($0.representedObject as? String) == "providerTabBar" })
        else {
            Issue.record("missing provider tab bar item")
            return
        }

        let first = controller.selectedMenuProvider
        #expect(first != nil)

        controller.cycleMenuProvider(tabBarItem)
        let second = controller.selectedMenuProvider
        #expect(second != first)

        // Cycling through every option returns to the starting selection
        // (providers + the Overview entry).
        let enabledCount = store.enabledProviders().count
        for _ in 0..<enabledCount {
            guard let item = menu.items.first(where: { ($0.representedObject as? String) == "providerTabBar" })
            else {
                Issue.record("tab bar item missing after repopulation")
                return
            }
            controller.cycleMenuProvider(item)
        }
        #expect(controller.selectedMenuProvider == first)
    }

    // MARK: - Helpers

    private static func makeStores(suiteName: String) -> (UsageStore, SettingsStore) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = SettingsStore(
            userDefaults: defaults,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        let store = UsageStore(fetcher: UsageFetcher(environment: [:]), settings: settings)
        return (store, settings)
    }

    private static func makeController(store: UsageStore, settings: SettingsStore) -> StatusItemController {
        StatusItemController(
            store: store,
            settings: settings,
            account: AccountInfo(email: nil, plan: nil),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())
    }

    private static func enable(only enabled: [UsageProvider], settings: SettingsStore) {
        let registry = ProviderRegistry.shared
        for provider in UsageProvider.allCases {
            guard let metadata = registry.metadata[provider] else { continue }
            settings.setProviderEnabled(
                provider: provider,
                metadata: metadata,
                enabled: enabled.contains(provider))
        }
    }
}
