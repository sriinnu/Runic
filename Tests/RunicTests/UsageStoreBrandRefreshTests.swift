import Foundation
import RunicCore
import Testing
@testable import Runic

/// The menu's brand tab selects the international root (`.kimi`) while stacking
/// a card per region, so "Refresh" on that tab must fan out to every enabled
/// slot (it used to refresh only the root — a China-only Kimi never re-fetched),
/// and dashboard/status/export plus the menu-open ping must act on the region(s)
/// actually shown.
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

    @Test
    func `no enabled slot falls back to the requested provider`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-none")
        self.setEnabled(store, .kimi, false)
        self.setEnabled(store, .kimiCN, false)
        #expect(store.refreshSlots(for: .kimi) == [.kimi])
    }

    @Test
    func `brand slots pair every region, international first`() {
        for (root, china) in UsageProvider.chinaSiblingByParent {
            #expect(root.brandSlots == [root, china])
            #expect(china.brandSlots == [root, china])
        }
        #expect(UsageProvider.codex.brandSlots == [.codex])
    }

    // MARK: - Menu slots (dashboard / status / export target, menu-open ping)

    // These seed snapshots and fetch attempts so menu presence resolves from
    // memory — no China-slot credential lookup, so no keychain access.

    @Test
    func `both configured regions are menu slots and intl leads`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-menu-both")
        self.setEnabled(store, .kimi, true)
        self.setEnabled(store, .kimiCN, true)
        store.snapshots[.kimi] = self.snapshot(updatedAt: Date())
        store.snapshots[.kimiCN] = self.snapshot(updatedAt: Date())

        #expect(store.menuSlots(for: .kimi) == [.kimi, .kimiCN])
        #expect(store.menuLeadSlot(for: .kimiCN) == .kimi)
    }

    @Test
    func `china-only brand tab targets the china console`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-menu-cn")
        self.chinaOnlyKimi(store, chinaUpdatedAt: Date())

        #expect(store.menuSlots(for: .kimi) == [.kimiCN])
        #expect(store.menuLeadSlot(for: .kimi) == .kimiCN)
        let dashboard = store.metadata(for: store.menuLeadSlot(for: .kimi)).dashboardURL ?? ""
        #expect(dashboard.contains("moonshot.cn"))
    }

    @Test
    func `single-region provider is its own menu slot`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-menu-single")
        #expect(store.menuSlots(for: .codex) == [.codex])
        #expect(store.menuLeadSlot(for: .codex) == .codex)
    }

    @Test
    func `hidden unconfigured intl slot does not bypass the ping budget`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-ping-hidden")
        let now = Date()
        self.chinaOnlyKimi(store, chinaUpdatedAt: now.addingTimeInterval(-60))
        store.errors[.kimi] = "missing token"
        store.menuOpenRefreshCount = PerformanceConstants.maxPingsPerSession

        #expect(store.shouldPingOnMenuOpen(provider: .kimi, now: now) == false)
    }

    @Test
    func `aged china slot pings from the brand root tab`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-ping-aged")
        let now = Date()
        let age = UsageStore.menuOpenSnapshotMaxAge + 1
        self.setEnabled(store, .kimi, true)
        self.setEnabled(store, .kimiCN, true)
        store.snapshots[.kimi] = self.snapshot(updatedAt: now)
        store.snapshots[.kimiCN] = self.snapshot(updatedAt: now.addingTimeInterval(-age))

        #expect(store.shouldPingOnMenuOpen(provider: .kimi, now: now) == true)
        store.menuOpenRefreshCount = PerformanceConstants.maxPingsPerSession
        #expect(store.shouldPingOnMenuOpen(provider: .kimi, now: now) == false)
    }

    @Test
    func `failing china slot pings from the brand root tab regardless of budget`() {
        let store = self.makeStore(suiteName: "UsageStoreBrandRefreshTests-ping-error")
        let now = Date()
        self.chinaOnlyKimi(store, chinaUpdatedAt: now)
        store.errors[.kimiCN] = "boom"
        store.menuOpenRefreshCount = PerformanceConstants.maxPingsPerSession

        #expect(store.shouldPingOnMenuOpen(provider: .kimi, now: now) == true)
    }

    /// Kimi intl enabled but keyless (its last fetch found no token, so it's
    /// hidden) with a configured China slot holding a snapshot.
    private func chinaOnlyKimi(_ store: UsageStore, chinaUpdatedAt: Date) {
        self.setEnabled(store, .kimi, true)
        self.setEnabled(store, .kimiCN, true)
        store.lastFetchAttempts[.kimi] = [
            ProviderFetchAttempt(
                strategyID: "kimi.api", kind: .apiToken, wasAvailable: false, errorDescription: nil),
        ]
        store.snapshots[.kimiCN] = self.snapshot(updatedAt: chinaUpdatedAt)
    }

    private func snapshot(updatedAt: Date) -> UsageSnapshot {
        UsageSnapshot(
            primary: RateWindow(
                usedPercent: 10,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: nil,
                hasKnownLimit: false),
            secondary: nil,
            updatedAt: updatedAt)
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
