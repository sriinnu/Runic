import RunicCore
import Foundation
import LocalAuthentication
import Security

protocol OpenRouterTokenStoring: Sendable {
    func loadToken() throws -> String?
    func storeToken(_ token: String?) throws
}

enum OpenRouterTokenStoreError: LocalizedError {
    case keychainStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case let .keychainStatus(status):
            "Keychain error: \(status)"
        case .invalidData:
            "Keychain returned invalid data."
        }
    }
}

struct KeychainOpenRouterTokenStore: OpenRouterTokenStoring {
    private static let log = RunicLog.logger("openrouter-token-store")

    private let service = "com.sriinnu.athena.Runic"
    private let account = "openrouter-api-token"

    func loadToken() throws -> String? {
        var result: CFTypeRef?
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecUseDataProtectionKeychain as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        let authContext = LAContext()
        authContext.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = authContext

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        if status == errSecInteractionNotAllowed {
            return nil
        }
        guard status == errSecSuccess else {
            Self.log.error("Keychain read failed: \(status)")
            throw OpenRouterTokenStoreError.keychainStatus(status)
        }

        guard let data = result as? Data else {
            throw OpenRouterTokenStoreError.invalidData
        }
        let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let token, !token.isEmpty {
            return token
        }
        return nil
    }

    func storeToken(_ token: String?) throws {
        let cleaned = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == nil || cleaned?.isEmpty == true {
            try self.deleteTokenIfPresent()
            return
        }

        let data = cleaned!.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            Self.log.error("Keychain update failed: \(updateStatus)")
            throw OpenRouterTokenStoreError.keychainStatus(updateStatus)
        }

        var addQuery = query
        for (key, value) in attributes {
            addQuery[key] = value
        }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.log.error("Keychain add failed: \(addStatus)")
            throw OpenRouterTokenStoreError.keychainStatus(addStatus)
        }
    }

    private func deleteTokenIfPresent() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        Self.log.error("Keychain delete failed: \(status)")
        throw OpenRouterTokenStoreError.keychainStatus(status)
    }
}
