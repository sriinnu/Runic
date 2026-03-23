import RunicCore
import Foundation
import Security

protocol CerebrasTokenStoring: Sendable {
    func loadToken() throws -> String?
    func storeToken(_ token: String?) throws
}

enum CerebrasTokenStoreError: LocalizedError {
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

struct KeychainCerebrasTokenStore: CerebrasTokenStoring {
    private static let log = RunicLog.logger("cerebras-token-store")

    private let service = "com.sriinnu.athena.Runic"
    private let account = "cerebras-api-token"

    func loadToken() throws -> String? {
        // Try standard keychain first.
        if let token = try self.readToken(dataProtection: false) {
            return token
        }
        // Migrate from the old Data Protection keychain if present.
        if let token = try self.readToken(dataProtection: true) {
            Self.log.info("Migrating Cerebras token from Data Protection keychain")
            // Store first, delete old only on success — prevents data loss.
            if (try? self.storeToken(token)) != nil {
                try? self.deleteToken(dataProtection: true)
            }
            return token
        }
        return nil
    }

    func storeToken(_ token: String?) throws {
        let cleaned = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == nil || cleaned?.isEmpty == true {
            try? self.deleteToken(dataProtection: false)
            try? self.deleteToken(dataProtection: true)
            return
        }

        let data = cleaned!.data(using: .utf8)!

        // Always delete-then-add to ensure SecAccess ACL is set.
        // SecItemUpdate does NOT update the ACL, so existing items with
        // missing or stale ACLs would continue to prompt for passwords.
        try? self.deleteToken(dataProtection: false)
        try? self.deleteToken(dataProtection: true)

        var addQuery = self.baseQuery(dataProtection: false)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        // Grant the calling app permanent access so macOS never shows a
        // Keychain password dialog for this item.
        if let access = Self.createSelfAccess() {
            addQuery[kSecAttrAccess as String] = access
        }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.log.error("Keychain add failed: \(addStatus)")
            throw CerebrasTokenStoreError.keychainStatus(addStatus)
        }
    }

    // MARK: - Private

    private func readToken(dataProtection: Bool) throws -> String? {
        var result: CFTypeRef?
        var query = self.baseQuery(dataProtection: dataProtection)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound || status == errSecInteractionNotAllowed {
            return nil
        }
        guard status == errSecSuccess else {
            Self.log.error("Keychain read failed: \(status)")
            throw CerebrasTokenStoreError.keychainStatus(status)
        }
        guard let data = result as? Data else {
            throw CerebrasTokenStoreError.invalidData
        }
        let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (token?.isEmpty ?? true) ? nil : token
    }

    private func deleteToken(dataProtection: Bool) throws {
        let query = self.baseQuery(dataProtection: dataProtection)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return }
        Self.log.error("Keychain delete failed: \(status)")
        throw CerebrasTokenStoreError.keychainStatus(status)
    }

    private func baseQuery(dataProtection: Bool) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
        ]
        if dataProtection {
            q[kSecUseDataProtectionKeychain as String] = true
        }
        return q
    }

    /// Creates a SecAccess that grants the calling application permanent
    /// read/write access without triggering the macOS Keychain password dialog.
    private static func createSelfAccess() -> SecAccess? {
        var trustedSelf: SecTrustedApplication?
        guard SecTrustedApplicationCreateFromPath(nil, &trustedSelf) == errSecSuccess,
              let trustedSelf else { return nil }
        var access: SecAccess?
        guard SecAccessCreate(
            "Runic API Token" as CFString,
            [trustedSelf] as CFArray,
            &access) == errSecSuccess else { return nil }
        return access
    }
}
