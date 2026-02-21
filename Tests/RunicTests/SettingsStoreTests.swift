import RunicCore
import Foundation
import Testing
@testable import Runic

@MainActor
@Suite
struct SettingsStoreTests {
    @Test
    func defaultRefreshFrequencyIsManual() {
        let suite = "SettingsStoreTests-default"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(userDefaults: defaults, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        #expect(store.refreshFrequency == .manual)
        #expect(store.refreshFrequency.seconds == nil)
        #expect(store.autoDisableRefreshOnSleepEnabled == true)
    }

    @Test
    func persistsRefreshFrequencyAcrossInstances() {
        let suite = "SettingsStoreTests-persist"
        let defaultsA = UserDefaults(suiteName: suite)!
        defaultsA.removePersistentDomain(forName: suite)
        let storeA = SettingsStore(userDefaults: defaultsA, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        storeA.refreshFrequency = .fifteenMinutes

        let defaultsB = UserDefaults(suiteName: suite)!
        let storeB = SettingsStore(userDefaults: defaultsB, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        #expect(storeB.refreshFrequency == .fifteenMinutes)
        #expect(storeB.refreshFrequency.seconds == 900)
    }

    @Test
    func persistsSelectedMenuProviderAcrossInstances() {
        let suite = "SettingsStoreTests-selectedMenuProvider"
        let defaultsA = UserDefaults(suiteName: suite)!
        defaultsA.removePersistentDomain(forName: suite)
        let storeA = SettingsStore(userDefaults: defaultsA, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        storeA.selectedMenuProvider = .claude

        let defaultsB = UserDefaults(suiteName: suite)!
        let storeB = SettingsStore(userDefaults: defaultsB, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        #expect(storeB.selectedMenuProvider == .claude)
    }

    @Test
    func defaultsSessionQuotaNotificationsToEnabled() {
        let key = "sessionQuotaNotificationsEnabled"
        let suite = "SettingsStoreTests-sessionQuotaNotifications"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(userDefaults: defaults, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())
        #expect(store.sessionQuotaNotificationsEnabled == true)
        #expect(defaults.bool(forKey: key) == true)
    }

    @Test
    func defaultsClaudeUsageSourceToOAuth() {
        let suite = "SettingsStoreTests-claude-source"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(userDefaults: defaults, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        #expect(store.claudeUsageDataSource == .oauth)
    }

    @Test
    func defaultsCodexUsageSourceToOAuth() {
        let suite = "SettingsStoreTests-codex-source"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(userDefaults: defaults, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        #expect(store.codexUsageDataSource == .oauth)
    }

    @Test
    func defaultsOpenAIWebAccessToEnabled() {
        let suite = "SettingsStoreTests-openai-web"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(userDefaults: defaults, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        #expect(store.openAIWebAccessEnabled == true)
        #expect(defaults.bool(forKey: "openAIWebAccessEnabled") == true)
    }

    @Test
    func providerOrder_defaultsToAllCases() {
        let suite = "SettingsStoreTests-providerOrder-default"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: "providerDetectionCompleted")

        let store = SettingsStore(userDefaults: defaults, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        #expect(store.orderedProviders() == UsageProvider.allCases)
    }

    @Test
    func providerOrder_persistsAndAppendsNewProviders() {
        let suite = "SettingsStoreTests-providerOrder-persist"
        let defaultsA = UserDefaults(suiteName: suite)!
        defaultsA.removePersistentDomain(forName: suite)
        defaultsA.set(true, forKey: "providerDetectionCompleted")

        // Partial list to mimic "older version" missing providers.
        defaultsA.set([UsageProvider.gemini.rawValue, UsageProvider.codex.rawValue], forKey: "providerOrder")

        let storeA = SettingsStore(userDefaults: defaultsA, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        let expectedAppended = UsageProvider.allCases.filter { ![.gemini, .codex].contains($0) }
        #expect(storeA.orderedProviders() == [.gemini, .codex] + expectedAppended)

        // Move one provider; ensure it's persisted across instances.
        let antigravityIndex = storeA.orderedProviders().firstIndex(of: .antigravity)!
        storeA.moveProvider(fromOffsets: IndexSet(integer: antigravityIndex), toOffset: 0)

        let defaultsB = UserDefaults(suiteName: suite)!
        defaultsB.set(true, forKey: "providerDetectionCompleted")
        let storeB = SettingsStore(userDefaults: defaultsB, zaiTokenStore: NoopZaiTokenStore(), minimaxTokenStore: NoopMiniMaxTokenStore(), minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(), minimaxGroupIDStore: NoopMiniMaxGroupIDStore(), openRouterTokenStore: NoopOpenRouterTokenStore(), groqTokenStore: NoopGroqTokenStore())

        #expect(storeB.orderedProviders().first == .antigravity)
    }
}
