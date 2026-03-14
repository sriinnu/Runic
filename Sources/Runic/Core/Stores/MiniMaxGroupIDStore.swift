import RunicCore
import Foundation
import Security

protocol MiniMaxGroupIDStoring: Sendable {
    func loadGroupID() throws -> String?
    func storeGroupID(_ groupID: String?) throws
}

enum MiniMaxGroupIDStoreError: LocalizedError {
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

struct KeychainMiniMaxGroupIDStore: MiniMaxGroupIDStoring {
    private static let log = RunicLog.logger("minimax-groupid-store")

    private let service = "com.sriinnu.athena.Runic"
    private let account = "minimax-group-id"

    func loadGroupID() throws -> String? {
        // Try standard keychain first.
        if let groupID = try self.readGroupID(dataProtection: false) {
            return groupID
        }
        // Migrate from the old Data Protection keychain if present.
        if let groupID = try self.readGroupID(dataProtection: true) {
            Self.log.info("Migrating MiniMax group ID from Data Protection keychain")
            // Store first, delete old only on success — prevents data loss.
            if (try? self.storeGroupID(groupID)) != nil {
                try? self.deleteGroupID(dataProtection: true)
            }
            return groupID
        }
        return nil
    }

    func storeGroupID(_ groupID: String?) throws {
        let cleaned = groupID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == nil || cleaned?.isEmpty == true {
            try? self.deleteGroupID(dataProtection: false)
            try? self.deleteGroupID(dataProtection: true)
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
            try? self.deleteGroupID(dataProtection: false)
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
            throw MiniMaxGroupIDStoreError.keychainStatus(addStatus)
        }
    }

    // MARK: - Private

    private func readGroupID(dataProtection: Bool) throws -> String? {
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
            throw MiniMaxGroupIDStoreError.keychainStatus(status)
        }
        guard let data = result as? Data else {
            throw MiniMaxGroupIDStoreError.invalidData
        }
        let groupID = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (groupID?.isEmpty ?? true) ? nil : groupID
    }

    private func deleteGroupID(dataProtection: Bool) throws {
        let query = self.baseQuery(dataProtection: dataProtection)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return }
        Self.log.error("Keychain delete failed: \(status)")
        throw MiniMaxGroupIDStoreError.keychainStatus(status)
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
