import Foundation
import RunicCore
import Testing
@testable import Runic

/// Menu-open ping policy: error-stale and missing snapshots always ping, and a
/// SUCCESSFUL snapshot older than `menuOpenSnapshotMaxAge` must ping too —
/// `isStale` is error-keyed only, so stale-but-successful data used to never
/// re-ping when the menu opened. (`.manual` refresh frequency never pings at
/// all; that guard lives in `scheduleOpenMenuPing` and is unchanged.)
@MainActor
struct UsageStoreMenuOpenPingTests {
    @Test
    func `fresh successful snapshot does not ping`() {
        let store = self.makeStore(suiteName: "UsageStoreMenuOpenPingTests-fresh")
        let now = Date()
        store.snapshots[.codex] = self.snapshot(updatedAt: now.addingTimeInterval(-60))

        #expect(store.shouldPingOnMenuOpen(provider: .codex, now: now) == false)
        #expect(store.shouldPingOnMenuOpen(provider: nil, now: now) == false)
    }

    @Test
    func `aged successful snapshot pings even without an error`() {
        let store = self.makeStore(suiteName: "UsageStoreMenuOpenPingTests-aged")
        let now = Date()
        let age = UsageStore.menuOpenSnapshotMaxAge + 1
        store.snapshots[.codex] = self.snapshot(updatedAt: now.addingTimeInterval(-age))

        #expect(store.isStale(provider: .codex) == false)
        #expect(store.shouldPingOnMenuOpen(provider: .codex, now: now) == true)
        // Merged/fallback menus (no specific provider) count any aged snapshot.
        #expect(store.shouldPingOnMenuOpen(provider: nil, now: now) == true)
    }

    @Test
    func `error-stale provider pings regardless of snapshot age`() {
        let store = self.makeStore(suiteName: "UsageStoreMenuOpenPingTests-error")
        let now = Date()
        store.snapshots[.codex] = self.snapshot(updatedAt: now)
        store.errors[.codex] = "boom"

        #expect(store.shouldPingOnMenuOpen(provider: .codex, now: now) == true)
    }

    @Test
    func `missing snapshot pings`() {
        let store = self.makeStore(suiteName: "UsageStoreMenuOpenPingTests-missing")

        #expect(store.shouldPingOnMenuOpen(provider: .codex, now: Date()) == true)
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
