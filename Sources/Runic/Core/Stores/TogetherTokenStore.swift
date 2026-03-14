import RunicCore
import Foundation
import Security

protocol TogetherTokenStoring: Sendable {
    func loadToken() throws -> String?
    func storeToken(_ token: String?) throws
}

enum TogetherTokenStoreError: LocalizedError {
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

struct KeychainTogetherTokenStore: TogetherTokenStoring {
    private static let log = RunicLog.logger("together-token-store")

    private let service = "com.sriinnu.athena.Runic"
    private let account = "together-api-token"

    func loadToken() throws -> String? {
        // Try standard keychain first.
        if let token = try self.readToken(dataProtection: false) {
            return token
        }
        // Migrate from the old Data Protection keychain if present.
        if let token = try self.readToken(dataProtection: true) {
            Self.log.info("Migrating Together token from Data Protection keychain")
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
        let query = self.baseQuery(dataProtection: false)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        // Try update first.
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        if updateStatus != errSecItemNotFound {
            // Item exists but update failed — delete and re-add to reset ACL.
            try? self.deleteToken(dataProtection: false)
        }

        var addQuery = query
        for (key, value) in attributes { addQuery[key] = value }

        // Grant the calling app permanent access so macOS never shows a
        // Keychain password dialog for this item.
        if let access = Self.createSelfAccess() {
            addQuery[kSecAttrAccess as String] = access
        }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.log.error("Keychain add failed: \(addStatus)")
            throw TogetherTokenStoreError.keychainStatus(addStatus)
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
            throw TogetherTokenStoreError.keychainStatus(status)
        }
        guard let data = result as? Data else {
            throw TogetherTokenStoreError.invalidData
        }
        let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (token?.isEmpty ?? true) ? nil : token
    }

    private func deleteToken(dataProtection: Bool) throws {
        let query = self.baseQuery(dataProtection: dataProtection)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return }
        Self.log.error("Keychain delete failed: \(status)")
        throw TogetherTokenStoreError.keychainStatus(status)
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
