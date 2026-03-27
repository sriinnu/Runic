import Foundation
import RunicCore
import Testing
@testable import Runic

@MainActor
struct SettingsStoreTests {
    @Test
    func `default refresh frequency is manual`() throws {
        let suite = "SettingsStoreTests-default"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(
            userDefaults: defaults,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(store.refreshFrequency == .manual)
        #expect(store.refreshFrequency.seconds == nil)
        #expect(store.autoDisableRefreshOnSleepEnabled == true)
    }

    @Test
    func `persists refresh frequency across instances`() throws {
        let suite = "SettingsStoreTests-persist"
        let defaultsA = try #require(UserDefaults(suiteName: suite))
        defaultsA.removePersistentDomain(forName: suite)
        let storeA = SettingsStore(
            userDefaults: defaultsA,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        storeA.refreshFrequency = .fifteenMinutes

        let defaultsB = try #require(UserDefaults(suiteName: suite))
        let storeB = SettingsStore(
            userDefaults: defaultsB,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(storeB.refreshFrequency == .fifteenMinutes)
        #expect(storeB.refreshFrequency.seconds == 900)
    }

    @Test
    func `default menu mode is operator`() throws {
        let suite = "SettingsStoreTests-menuMode-default"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(
            userDefaults: defaults,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(store.menuMode == .operator)
    }

    @Test
    func `persists menu mode across instances`() throws {
        let suite = "SettingsStoreTests-menuMode-persist"
        let defaultsA = try #require(UserDefaults(suiteName: suite))
        defaultsA.removePersistentDomain(forName: suite)
        let storeA = SettingsStore(
            userDefaults: defaultsA,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        storeA.menuMode = .analyst

        let defaultsB = try #require(UserDefaults(suiteName: suite))
        let storeB = SettingsStore(
            userDefaults: defaultsB,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(storeB.menuMode == .analyst)
    }

    @Test
    func `persists selected menu provider across instances`() throws {
        let suite = "SettingsStoreTests-selectedMenuProvider"
        let defaultsA = try #require(UserDefaults(suiteName: suite))
        defaultsA.removePersistentDomain(forName: suite)
        let storeA = SettingsStore(
            userDefaults: defaultsA,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        storeA.selectedMenuProvider = .claude

        let defaultsB = try #require(UserDefaults(suiteName: suite))
        let storeB = SettingsStore(
            userDefaults: defaultsB,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(storeB.selectedMenuProvider == .claude)
    }

    @Test
    func `defaults session quota notifications to enabled`() throws {
        let key = "sessionQuotaNotificationsEnabled"
        let suite = "SettingsStoreTests-sessionQuotaNotifications"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(
            userDefaults: defaults,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        #expect(store.sessionQuotaNotificationsEnabled == true)
        #expect(defaults.bool(forKey: key) == true)
    }

    @Test
    func `defaults claude usage source to O auth`() throws {
        let suite = "SettingsStoreTests-claude-source"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(
            userDefaults: defaults,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(store.claudeUsageDataSource == .oauth)
    }

    @Test
    func `defaults codex usage source to O auth`() throws {
        let suite = "SettingsStoreTests-codex-source"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(
            userDefaults: defaults,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(store.codexUsageDataSource == .oauth)
    }

    @Test
    func `defaults open AI web access to enabled`() throws {
        let suite = "SettingsStoreTests-openai-web"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(
            userDefaults: defaults,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(store.openAIWebAccessEnabled == true)
        #expect(defaults.bool(forKey: "openAIWebAccessEnabled") == true)
    }

    @Test
    func `provider order defaults to all cases`() throws {
        let suite = "SettingsStoreTests-providerOrder-default"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: "providerDetectionCompleted")

        let store = SettingsStore(
            userDefaults: defaults,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(store.orderedProviders() == UsageProvider.allCases)
    }

    @Test
    func `provider order persists and appends new providers`() throws {
        let suite = "SettingsStoreTests-providerOrder-persist"
        let defaultsA = try #require(UserDefaults(suiteName: suite))
        defaultsA.removePersistentDomain(forName: suite)
        defaultsA.set(true, forKey: "providerDetectionCompleted")

        // Partial list to mimic "older version" missing providers.
        defaultsA.set([UsageProvider.gemini.rawValue, UsageProvider.codex.rawValue], forKey: "providerOrder")

        let storeA = SettingsStore(
            userDefaults: defaultsA,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        let expectedAppended = UsageProvider.allCases.filter { ![.gemini, .codex].contains($0) }
        #expect(storeA.orderedProviders() == [.gemini, .codex] + expectedAppended)

        // Move one provider; ensure it's persisted across instances.
        let antigravityIndex = try #require(storeA.orderedProviders().firstIndex(of: .antigravity))
        storeA.moveProvider(fromOffsets: IndexSet(integer: antigravityIndex), toOffset: 0)

        let defaultsB = try #require(UserDefaults(suiteName: suite))
        defaultsB.set(true, forKey: "providerDetectionCompleted")
        let storeB = SettingsStore(
            userDefaults: defaultsB,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())

        #expect(storeB.orderedProviders().first == .antigravity)
    }
}
