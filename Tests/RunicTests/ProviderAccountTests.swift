import Foundation
import RunicCore
import Testing

struct ProviderAccountTests {
    @Test
    func `the default account's id is the kind's raw value, added accounts are kind~slug`() throws {
        #expect(UsageProvider.kimi.defaultAccount.rawValue == "kimi")
        #expect(AccountID(kind: .kimi, slug: "work").rawValue == "kimi~work")
        #expect(AccountID(rawValue: "kimi") == .init(kind: .kimi))
        #expect(AccountID(rawValue: "kimi~work") == .init(kind: .kimi, slug: "work"))
        #expect(AccountID(rawValue: "nope~work") == nil)
        #expect(AccountID(rawValue: "kimi~") == nil)
        #expect(AccountID(kind: .claude, slug: "").isDefault)

        let encoded = try JSONEncoder().encode([AccountID(kind: .codex, slug: "org")])
        #expect(String(bytes: encoded, encoding: .utf8) == #"["codex~org"]"#)
        #expect(try JSONDecoder().decode([AccountID].self, from: encoded) == [AccountID(kind: .codex, slug: "org")])
    }

    @Test
    func `keychain item names keep the historical name for the default account`() {
        #expect(UsageProvider.kimi.defaultAccount.keychainAccount(base: "kimi-api-token") == "kimi-api-token")
        #expect(AccountID(kind: .kimi, slug: "work").keychainAccount(base: "kimi-api-token") == "kimi-api-token.work")
    }

    @Test
    func `an added account never inherits the default account's environment key`() {
        let env = ["KIMI_API_KEY": "shell-key"]
        #expect(ProviderTokenResolver.credentialResolution(
            for: UsageProvider.kimi.defaultAccount, environment: env, allowKeychain: false)?.token == "shell-key")
        #expect(ProviderTokenResolver.credentialResolution(
            for: AccountID(kind: .kimi, slug: "work"), environment: env, allowKeychain: false) == nil)
        // Kinds without an API-key resolver have no second-account keychain item either.
        #expect(ProviderTokenResolver.credentialResolution(
            for: AccountID(kind: .claude, slug: "work"), environment: env) == nil)
    }

    @Test
    func `a fetch context resolves the kind's default account unless told otherwise`() {
        let context = ProviderFetchContext(
            runtime: .cli,
            sourceMode: .auto,
            includeCredits: false,
            webTimeout: 1,
            webDebugDumpHTML: false,
            verbose: false,
            env: ["DEEPSEEK_API_KEY": "k"],
            settings: nil,
            fetcher: UsageFetcher(),
            claudeFetcher: ClaudeUsageFetcher())
        #expect(context.account == nil)
        #expect(context.credential(for: .deepseek)?.token == "k")
    }
}
