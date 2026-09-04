import Foundation
import RunicCore
import Security

protocol MiniMaxCNTokenStoring: Sendable {
    func loadToken() throws -> String?
    func storeToken(_ token: String?) throws
}

struct KeychainMiniMaxCNTokenStore: MiniMaxCNTokenStoring {
    private static let log = RunicLog.logger("minimax-cn-token-store")

    private let service = RunicKeychainService.providerCredentials
    private let account = "minimax-cn-api-token"

    func loadToken() throws -> String? {
        try self.readToken()
    }

    func storeToken(_ token: String?) throws {
        let cleaned = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == nil || cleaned?.isEmpty == true {
            try? self.deleteToken()
            return
        }

        let normalized = cleaned!
        if let current = try self.readToken(), current == normalized {
            return
        }

        let data = normalized.data(using: .utf8)!
        try? self.deleteToken()

        var addQuery = self.baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.log.error("Keychain add failed: \(addStatus)")
            throw KimiTokenStoreError.keychainStatus(addStatus)
        }
    }

    private func readToken() throws -> String? {
        var result: CFTypeRef?
        var query = self.baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        RunicKeychainQuery.disallowAuthenticationUI(in: &query)

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound || status == errSecInteractionNotAllowed {
            return nil
        }
        guard status == errSecSuccess else {
            Self.log.error("Keychain read failed: \(status)")
            throw KimiTokenStoreError.keychainStatus(status)
        }
        guard let data = result as? Data else {
            throw KimiTokenStoreError.invalidData
        }
        let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (token?.isEmpty ?? true) ? nil : token
    }

    private func deleteToken() throws {
        var query = self.baseQuery()
        RunicKeychainQuery.disallowAuthenticationUI(in: &query)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return }
        Self.log.error("Keychain delete failed: \(status)")
        throw KimiTokenStoreError.keychainStatus(status)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
        ]
    }
}
