import Foundation
import RunicCore
import Security

protocol MiniMaxCookieHeaderStoring: Sendable {
    func loadHeader() throws -> String?
    func storeHeader(_ header: String?) throws
}

enum MiniMaxCookieHeaderStoreError: LocalizedError {
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

struct KeychainMiniMaxCookieHeaderStore: MiniMaxCookieHeaderStoring {
    private static let log = RunicLog.logger("minimax-cookie-store")

    private let service = "com.sriinnu.athena.Runic"
    private let account = "minimax-cookie-header"

    func loadHeader() throws -> String? {
        // Try standard keychain first.
        if let header = try self.readHeader(dataProtection: false) {
            return header
        }
        // Migrate from the old Data Protection keychain if present.
        if let header = try self.readHeader(dataProtection: true) {
            Self.log.info("Migrating MiniMax cookie header from Data Protection keychain")
            // Store first, delete old only on success — prevents data loss.
            if (try? self.storeHeader(header)) != nil {
                try? self.deleteHeader(dataProtection: true)
            }
            return header
        }
        return nil
    }

    func storeHeader(_ header: String?) throws {
        let cleaned = header?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == nil || cleaned?.isEmpty == true {
            try? self.deleteHeader(dataProtection: false)
            try? self.deleteHeader(dataProtection: true)
            return
        }

        let data = cleaned!.data(using: .utf8)!

        // Always delete-then-add to ensure SecAccess ACL is set.
        // SecItemUpdate does NOT update the ACL, so existing items with
        // missing or stale ACLs would continue to prompt for passwords.
        try? self.deleteHeader(dataProtection: false)
        try? self.deleteHeader(dataProtection: true)

        var addQuery = self.baseQuery(dataProtection: false)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.log.error("Keychain add failed: \(addStatus)")
            throw MiniMaxCookieHeaderStoreError.keychainStatus(addStatus)
        }
    }

    // MARK: - Private

    private func readHeader(dataProtection: Bool) throws -> String? {
        var result: CFTypeRef?
        var query = self.baseQuery(dataProtection: dataProtection)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound || status == errSecInteractionNotAllowed {
            return nil
        }
        guard status == errSecSuccess else {
            Self.log.error("Keychain read failed: \(status)")
            throw MiniMaxCookieHeaderStoreError.keychainStatus(status)
        }
        guard let data = result as? Data else {
            throw MiniMaxCookieHeaderStoreError.invalidData
        }
        let header = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (header?.isEmpty ?? true) ? nil : header
    }

    private func deleteHeader(dataProtection: Bool) throws {
        let query = self.baseQuery(dataProtection: dataProtection)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return }
        Self.log.error("Keychain delete failed: \(status)")
        throw MiniMaxCookieHeaderStoreError.keychainStatus(status)
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
}
