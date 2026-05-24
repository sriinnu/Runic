import Foundation
#if canImport(Security)
import Security
#endif

public struct ProviderCredentialMigrationSummary: Sendable, Equatable {
    public let migratedAccounts: [String]
    public let blockedAccounts: [String]
    public let failedAccounts: [String]

    public var needsUserRepair: Bool {
        !self.blockedAccounts.isEmpty || !self.failedAccounts.isEmpty
    }
}

public enum ProviderCredentialKeychainMigration {
    public static let knownAccounts: [String] = [
        "zai-api-token",
        "minimax-api-token",
        "minimax-cookie-header",
        "minimax-group-id",
        "copilot-api-token",
        "openrouter-api-token",
        "vercelai-api-token",
        "groq-api-token",
        "deepseek-api-token",
        "fireworks-api-token",
        "mistral-api-token",
        "perplexity-api-token",
        "kimi-api-token",
        "auggie-api-token",
        "together-api-token",
        "cohere-api-token",
        "xai-api-token",
        "cerebras-api-token",
        "sambanova-api-token",
        "azure-openai-api-token",
        "qwen-api-token",
    ]

    public static func migrateKnownLegacyItems() -> ProviderCredentialMigrationSummary {
        #if canImport(Security)
        var migrated: [String] = []
        var blocked: [String] = []
        var failed: [String] = []

        for account in self.knownAccounts {
            if self.read(service: RunicKeychainService.providerCredentials, account: account).token != nil {
                continue
            }
            switch self.readLegacy(account: account) {
            case let .found(token):
                if self.write(token: token, account: account) {
                    migrated.append(account)
                    self.deleteLegacy(account: account)
                } else {
                    failed.append(account)
                }
            case .blocked:
                blocked.append(account)
            case .missing:
                continue
            }
        }
        return ProviderCredentialMigrationSummary(
            migratedAccounts: migrated,
            blockedAccounts: blocked,
            failedAccounts: failed)
        #else
        return ProviderCredentialMigrationSummary(migratedAccounts: [], blockedAccounts: [], failedAccounts: [])
        #endif
    }

    public static func token(account: String) -> String? {
        #if canImport(Security)
        if let token = self.read(service: RunicKeychainService.providerCredentials, account: account).token {
            return token
        }
        if case let .found(token) = self.readLegacy(account: account), self.write(token: token, account: account) {
            self.deleteLegacy(account: account)
            return token
        }
        return nil
        #else
        _ = account
        return nil
        #endif
    }

    #if canImport(Security)
    private enum ReadResult {
        case found(String)
        case missing
        case blocked

        var token: String? {
            if case let .found(token) = self { return token }
            return nil
        }
    }

    private static func readLegacy(account: String) -> ReadResult {
        let standard = self.read(service: RunicKeychainService.legacyProviderCredentials, account: account)
        if standard.token != nil { return standard }
        if case .blocked = standard { return standard }
        return self.read(
            service: RunicKeychainService.legacyProviderCredentials,
            account: account,
            dataProtection: true)
    }

    private static func read(
        service: String,
        account: String,
        dataProtection: Bool = false) -> ReadResult
    {
        var result: CFTypeRef?
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecInteractionNotAllowed { return .blocked }
        if status == errSecItemNotFound { return .missing }
        guard status == errSecSuccess,
              let data = result as? Data,
              let raw = String(data: data, encoding: .utf8)
        else {
            return .missing
        }
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? .missing : .found(token)
    }

    private static func write(token: String, account: String) -> Bool {
        self.delete(service: RunicKeychainService.providerCredentials, account: account, dataProtection: false)
        self.delete(service: RunicKeychainService.providerCredentials, account: account, dataProtection: true)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: RunicKeychainService.providerCredentials,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private static func deleteLegacy(account: String) {
        self.delete(service: RunicKeychainService.legacyProviderCredentials, account: account, dataProtection: false)
        self.delete(service: RunicKeychainService.legacyProviderCredentials, account: account, dataProtection: true)
    }

    private static func delete(service: String, account: String, dataProtection: Bool) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
        _ = SecItemDelete(query as CFDictionary)
    }
    #endif
}
