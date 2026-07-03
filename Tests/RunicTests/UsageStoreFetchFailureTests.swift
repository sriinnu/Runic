import Foundation
import RunicCore
import Testing
@testable import Runic

/// Regression tests for surfaced fetch failures: the last-known-good snapshot
/// must survive so the menu card keeps rendering usage bars (dated by the
/// snapshot's `updatedAt`) with the error shown alongside, instead of flipping
/// to error-text-only.
@MainActor
struct UsageStoreFetchFailureTests {
    @Test
    func `surfaced failure keeps last known snapshot`() {
        let store = self.makeStore(suiteName: "UsageStoreFetchFailureTests-keeps")
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 40, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: Date(timeIntervalSince1970: 1_767_122_400))
        store.snapshots[.codex] = snapshot

        // First failure with prior data is a suppressed flake.
        store.recordProviderFetchFailure(.codex, message: "boom")
        #expect(store.errors[.codex] == nil)
        #expect(store.snapshots[.codex] != nil)

        // Second consecutive failure surfaces the error but keeps the stale
        // snapshot so the card still shows the last-known usage.
        store.recordProviderFetchFailure(.codex, message: "boom")
        #expect(store.errors[.codex] == "boom")
        #expect(store.snapshots[.codex] != nil)
        #expect(store.snapshots[.codex]?.updatedAt == snapshot.updatedAt)
        #expect(store.isStale(provider: .codex))
    }

    @Test
    func `failure without prior data surfaces immediately`() {
        let store = self.makeStore(suiteName: "UsageStoreFetchFailureTests-noprior")

        store.recordProviderFetchFailure(.claude, message: "no session")
        #expect(store.errors[.claude] == "no session")
        #expect(store.snapshots[.claude] == nil)
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
