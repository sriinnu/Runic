#if os(macOS)
import Foundation
import LocalAuthentication
import Security
import Testing
@testable import Runic
@testable import RunicCore

struct KeychainQueryPolicyTests {
    @Test
    func `Runic token store queries fail instead of prompting`() throws {
        var query: [String: Any] = [:]

        RunicKeychainQuery.disallowAuthenticationUI(in: &query)

        #expect(query[kSecUseAuthenticationUI as String] as? String == "u_AuthUIF")
        let context = try #require(query[kSecUseAuthenticationContext as String] as? LAContext)
        #expect(context.interactionNotAllowed)
    }

    @Test
    func `RunicCore background keychain queries fail instead of prompting`() throws {
        var query: [String: Any] = [:]

        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)

        #expect(query[kSecUseAuthenticationUI as String] as? String == "u_AuthUIF")
        let context = try #require(query[kSecUseAuthenticationContext as String] as? LAContext)
        #expect(context.interactionNotAllowed)
    }

    @Test
    func `RunicCore explicit imports are the only interactive keychain path`() throws {
        var query: [String: Any] = [:]

        RunicCoreKeychainQueryPolicy.setAuthenticationUI(true, in: &query)

        #expect(query[kSecUseAuthenticationUI as String] as? String == "u_AuthUIA")
        let context = try #require(query[kSecUseAuthenticationContext as String] as? LAContext)
        #expect(!context.interactionNotAllowed)
    }

    @Test
    func `RunicCore noninteractive safe storage reads hard fail UI`() throws {
        var query: [String: Any] = [:]

        RunicCoreKeychainQueryPolicy.setAuthenticationUI(false, in: &query)

        #expect(query[kSecUseAuthenticationUI as String] as? String == "u_AuthUIF")
        let context = try #require(query[kSecUseAuthenticationContext as String] as? LAContext)
        #expect(context.interactionNotAllowed)
    }

    @Test
    func `legacy provider migration is opt in to avoid startup prompts`() {
        let summary = ProviderCredentialKeychainMigration.migrateKnownLegacyItems()
        let token = ProviderCredentialKeychainMigration.token(account: "runic-test-missing-\(UUID().uuidString)")

        #expect(summary.migratedAccounts.isEmpty)
        #expect(summary.blockedAccounts.isEmpty)
        #expect(summary.failedAccounts.isEmpty)
        #expect(token == nil)
    }

    @Test
    func `custom provider fetcher reads standard keychain token saved by UI`() async throws {
        let account = "runic-test-custom-provider-\(UUID().uuidString)"
        self.deleteProviderCredential(account: account, dataProtection: false)
        self.deleteProviderCredential(account: account, dataProtection: true)
        defer {
            self.deleteProviderCredential(account: account, dataProtection: false)
            self.deleteProviderCredential(account: account, dataProtection: true)
        }

        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: RunicKeychainService.providerCredentials,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data("secret-token".utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &addQuery)
        #expect(SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess)

        let config = CustomProviderConfig(
            name: "Test",
            icon: "server.rack",
            auth: AuthConfig(type: .bearer, headerName: "Authorization", tokenKeychain: account),
            endpoints: EndpointConfig())
        let fetcher = GenericProviderFetcher(config: config)

        let token = try await fetcher._loadTokenForTesting()
        #expect(token == "secret-token")
    }

    private func deleteProviderCredential(account: String, dataProtection: Bool) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: RunicKeychainService.providerCredentials,
            kSecAttrAccount as String: account,
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
        _ = SecItemDelete(query as CFDictionary)
    }
}
#endif
