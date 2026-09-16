import Foundation
import RunicCore
import Testing
@testable import Runic

/// The menu's brand tab selects the international root (`.kimi`) while stacking
/// a card per region, so "Refresh" on that tab must fan out to every enabled
/// slot. It used to refresh only the root — a China-only Kimi never re-fetched.
@MainActor
struct UsageStoreBrandRefreshTests {
    @Test
    func `china-only brand refreshes its china slot from the root tab`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-cn-only")
        for (root, china) in UsageProvider.chinaSiblingByParent {
            self.setEnabled(store, root, false)
            self.setEnabled(store, china, true)
            #expect(store.refreshSlots(for: root) == [china])
            #expect(store.refreshSlots(for: china) == [china])
        }
    }

    @Test
    func `two-region brand refreshes both slots, international first`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-both")
        self.setEnabled(store, .kimi, true)
        self.setEnabled(store, .kimiCN, true)
        #expect(store.refreshSlots(for: .kimi) == [.kimi, .kimiCN])
        #expect(store.refreshSlots(for: .kimiCN) == [.kimi, .kimiCN])
    }

    @Test
    func `single-region provider refreshes only itself`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-single")
        self.setEnabled(store, .codex, true)
        #expect(store.refreshSlots(for: .codex) == [.codex])
    }

    private func setEnabled(_ store: UsageStore, _ provider: UsageProvider, _ enabled: Bool) {
        store.settings.setProviderEnabled(
            provider: provider, metadata: store.metadata(for: provider), enabled: enabled)
    }

    private func makeStore(suiteName: String) -> UsageStore {
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
        return UsageStore(fetcher: UsageFetcher(environment: [:]), settings: settings)
    }
}
