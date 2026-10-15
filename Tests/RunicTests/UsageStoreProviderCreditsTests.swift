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
            fetch: { _, _ in
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
    func `a kind with an added account fetches once per account into its own slot`() async {
        let store = self.makeStore(suiteName: "UsageStoreProviderCreditsTests-accounts")
        let work = ProviderAccount(
            id: AccountID(kind: .deepseek, slug: "work"),
            displayName: "work",
            credential: .keychainItem("deepseek-api-token.work"))
        let off = ProviderAccount(id: AccountID(kind: .deepseek, slug: "off"), displayName: "off", isEnabled: false)
        store.addedAccounts = [work, off]

        let fetched = FetchLog()
        store.providerSpecs[.deepseek] = ProviderSpec(
            style: .codex,
            isEnabled: { true },
            fetch: { account, credential in
                await fetched.record(account, credential)
                let usage = UsageSnapshot(
                    primary: RateWindow(
                        usedPercent: account.isDefault ? 10 : 20,
                        windowMinutes: 300,
                        resetsAt: nil,
                        resetDescription: nil),
                    secondary: nil,
                    updatedAt: Date())
                return ProviderFetchOutcome(
                    result: .success(ProviderFetchResult(
                        usage: usage,
                        credits: nil,
                        dashboard: nil,
                        sourceLabel: "test",
                        strategyID: "test.api",
                        strategyKind: .apiToken)),
                    attempts: [])
            })

        await store.refreshProvider(.deepseek, trigger: .manual)

        let calls = await fetched.calls
        #expect(calls.map(\.0.rawValue) == ["deepseek", "deepseek~work"])
        #expect(calls.map(\.1) == [nil, .keychainItem("deepseek-api-token.work")])
        #expect(store.snapshots[.deepseek]?.primary.usedPercent == 10)
        #expect(store.snapshots[work.id]?.primary.usedPercent == 20)
        #expect(store.snapshots[off.id] == nil)
        #expect(store.errors[work.id] == nil)
        #expect(store.lastSourceLabels[work.id] == "test")
    }

    private actor FetchLog {
        var calls: [(AccountID, CredentialRef?)] = []
        func record(_ account: AccountID, _ credential: CredentialRef?) {
            self.calls.append((account, credential))
        }
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
            fetch: { _, _ in
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
        // Codex usage results populate the dedicated slot directly.
        #expect(store.credits?.remaining == 7)
        #expect(store.lastCreditsSnapshot?.remaining == 7)
        #expect(store.lastCreditsError == nil)
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
            fetch: { _, _ in
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
