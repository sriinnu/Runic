import Foundation
import RunicCore
import Security

protocol CustomProviderTokenStoring: Sendable {
    func storeToken(_ token: String?, account: String) throws
    func deleteToken(account: String) throws
}

struct KeychainCustomProviderTokenStore: CustomProviderTokenStoring {
    private static let log = RunicLog.logger("custom-provider-token-store")
    private let service = RunicKeychainService.providerCredentials

    func storeToken(_ token: String?, account: String) throws {
        let cleaned = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == nil || cleaned?.isEmpty == true { return }

        let data = cleaned!.data(using: .utf8)!
        try? self.deleteToken(account: account)

        var addQuery = self.baseQuery(account: account, dataProtection: false)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            Self.log.error("Keychain add failed for custom provider token \(account): \(status)")
            throw CustomProviderTokenStoreError.keychainStatus(status)
        }
    }

    func deleteToken(account: String) throws {
        var firstError: Error?
        do {
            try self.deleteToken(account: account, dataProtection: false)
        } catch {
            firstError = error
        }
        do {
            try self.deleteToken(account: account, dataProtection: true)
        } catch {
            if firstError == nil { firstError = error }
        }
        if let firstError { throw firstError }
    }

    private func deleteToken(account: String, dataProtection: Bool) throws {
        var query = self.baseQuery(account: account, dataProtection: dataProtection)
        RunicKeychainQuery.disallowAuthenticationUI(in: &query)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return }
        Self.log.error("Keychain delete failed for custom provider token \(account): \(status)")
        throw CustomProviderTokenStoreError.keychainStatus(status)
    }

    private func baseQuery(account: String, dataProtection: Bool) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account,
        ]
        if dataProtection {
            q[kSecUseDataProtectionKeychain as String] = true
        }
        return q
    }
}

enum CustomProviderTokenStoreError: LocalizedError {
    case keychainStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .keychainStatus(status):
            "Keychain error: \(status)"
        }
    }
}
