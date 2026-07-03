import AppKit
import RunicCore
import SwiftUI
import Testing
@testable import Runic

/// Behavior coverage for the menu-open performance fixes: lazy chart
/// submenus, entrance-animation suppression on repopulate, and lazy
/// per-provider status items.
@MainActor
struct MenuPerfBehaviorTests {
    private func makeSettings() -> SettingsStore {
        let settings = SettingsStore(
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.menuMode = .operator
        return settings
    }

    private func makeController(settings: SettingsStore) -> StatusItemController {
        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        return StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection())
    }

    @Test
    func `deferred chart submenu builds its hosted view only when it opens`() {
        let settings = self.makeSettings()
        let controller = self.makeController(settings: settings)

        var buildCount = 0
        let submenu = controller.makeDeferredHostedSubmenu(id: "testChart") {
            buildCount += 1
            return controller.makeSizedHostedView(Text("chart").frame(width: 340), width: 340)
        }

        let placeholder = try? #require(submenu.items.first)
        #expect(buildCount == 0)
        #expect(placeholder?.view == nil)
        #expect(placeholder?.representedObject is StatusItemController.DeferredHostedSubmenuContent)

        controller.menuWillOpen(submenu)
        #expect(buildCount == 1)
        #expect(placeholder?.view != nil)
        #expect(placeholder?.representedObject as? String == "testChart")
        #expect(placeholder?.view?.frame.width == 340)
        #expect((placeholder?.view?.frame.height ?? 0) > 0)

        // Re-opening must not rebuild the hierarchy.
        controller.menuWillOpen(submenu)
        #expect(buildCount == 1)
    }

    @Test
    func `entrance animations play on first open and are suppressed while the menu is open`() {
        let settings = self.makeSettings()
        settings.mergeIcons = true
        let registry = ProviderRegistry.shared
        if let codexMeta = registry.metadata[.codex] {
            settings.setProviderEnabled(provider: .codex, metadata: codexMeta, enabled: true)
        }
        let controller = self.makeController(settings: settings)

        let menu = controller.makeMenu()
        let beforeOpen = controller.makeMenuPopulationContext(provider: .codex, menu: menu)
        #expect(beforeOpen.animateEntrance)

        controller.menuWillOpen(menu)
        let whileOpen = controller.makeMenuPopulationContext(provider: .codex, menu: menu)
        #expect(!whileOpen.animateEntrance)

        controller.menuDidClose(menu)
        let afterClose = controller.makeMenuPopulationContext(provider: .codex, menu: menu)
        #expect(afterClose.animateEntrance)
    }

    @Test
    func `status items are created only for providers that need a menubar presence`() {
        let settings = self.makeSettings()
        settings.mergeIcons = false
        let registry = ProviderRegistry.shared
        if let claudeMeta = registry.metadata[.claude] {
            settings.setProviderEnabled(provider: .claude, metadata: claudeMeta, enabled: true)
        }
        if let codexMeta = registry.metadata[.codex] {
            settings.setProviderEnabled(provider: .codex, metadata: codexMeta, enabled: false)
        }
        let controller = self.makeController(settings: settings)

        #expect(controller.statusItems[.claude] != nil)
        // Disabled, non-fallback providers get no menubar slot at all.
        let created = Set(controller.statusItems.keys)
        #expect(!created.contains(.gemini))
        #expect(created.count < UsageProvider.allCases.count)
    }

    @Test
    func `performance retention prune gate honors the daily interval`() {
        let now = Date(timeIntervalSince1970: 1_767_225_600)
        #expect(PerformanceRetentionPruner.isPruneDue(lastPrune: nil, now: now))
        #expect(PerformanceRetentionPruner.isPruneDue(
            lastPrune: now.addingTimeInterval(-25 * 3600),
            now: now))
        #expect(!PerformanceRetentionPruner.isPruneDue(
            lastPrune: now.addingTimeInterval(-2 * 3600),
            now: now))
    }
}
