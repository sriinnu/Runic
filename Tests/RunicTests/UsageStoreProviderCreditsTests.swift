import Foundation
import RunicCore
import Testing
@testable import Runic

/// Per-provider credits: fetch results that attach a `CreditsSnapshot`
/// (DeepSeek, OpenRouter, Vercel AI, ...) must land in the store instead of
/// being discarded, while Codex keeps its dedicated slot.
@MainActor
struct UsageStoreProviderCreditsTests {
    @Test
    func `refresh stores per provider credits from fetch results`() async {
        let store = self.makeStore(suiteName: "UsageStoreProviderCreditsTests-store")
        let now = Date()
        let usage = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: 42.00 USD",
                hasKnownLimit: false),
            secondary: nil,
            updatedAt: now)
        let credits = CreditsSnapshot(remaining: 42, events: [], updatedAt: now)
        store.providerSpecs[.deepseek] = ProviderSpec(
            style: .codex,
            isEnabled: { true },
            fetch: {
                ProviderFetchOutcome(
                    result: .success(ProviderFetchResult(
                        usage: usage,
                        credits: credits,
                        dashboard: nil,
                        sourceLabel: "test",
                        strategyID: "test.api",
                        strategyKind: .apiToken)),
                    attempts: [])
            })

        await store.refreshProvider(.deepseek, trigger: .manual)

        #expect(store.credits(for: .deepseek)?.remaining == 42)
        #expect(store.providerCredits[.deepseek]?.remaining == 42)
        // The Codex slot is untouched by other providers' credits.
        #expect(store.credits == nil)
        #expect(store.credits(for: .codex) == nil)
    }

    @Test
    func `codex fetch credits never land in the per-provider map`() async {
        // `credits(for: .codex)` reads the dedicated `credits` slot, so a
        // `providerCredits[.codex]` entry would be a dead write that anything
        // iterating the map would see as a stale duplicate.
        let store = self.makeStore(suiteName: "UsageStoreProviderCreditsTests-codex-map")
        let now = Date()
        let usage = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: nil,
                hasKnownLimit: false),
            secondary: nil,
            updatedAt: now)
        store.providerSpecs[.codex] = ProviderSpec(
            style: .codex,
            isEnabled: { true },
            fetch: {
                ProviderFetchOutcome(
                    result: .success(ProviderFetchResult(
                        usage: usage,
                        credits: CreditsSnapshot(remaining: 7, events: [], updatedAt: now),
                        dashboard: nil,
                        sourceLabel: "test",
                        strategyID: "test.api",
                        strategyKind: .apiToken)),
                    attempts: [])
            })

        await store.refreshProvider(.codex, trigger: .manual)

        #expect(store.providerCredits[.codex] == nil)
        // The dedicated slot stays owned by the OpenAI web flow.
        #expect(store.credits == nil)
    }

    @Test
    func `codex accessor reads the dedicated slot`() {
        let store = self.makeStore(suiteName: "UsageStoreProviderCreditsTests-codex")
        let snapshot = CreditsSnapshot(remaining: 12, events: [], updatedAt: Date())
        store.credits = snapshot

        #expect(store.credits(for: .codex)?.remaining == 12)
        #expect(store.credits(for: .deepseek) == nil)
    }

    @Test
    func `disabling a provider clears its credits`() async {
        let store = self.makeStore(suiteName: "UsageStoreProviderCreditsTests-disable")
        store.providerCredits[.deepseek] = CreditsSnapshot(remaining: 42, events: [], updatedAt: Date())
        store.providerSpecs[.deepseek] = ProviderSpec(
            style: .codex,
            isEnabled: { false },
            fetch: {
                ProviderFetchOutcome(
                    result: .failure(ProviderFetchError.missingCredentials),
                    attempts: [])
            })

        await store.refreshProvider(.deepseek, trigger: .manual)

        #expect(store.credits(for: .deepseek) == nil)
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
