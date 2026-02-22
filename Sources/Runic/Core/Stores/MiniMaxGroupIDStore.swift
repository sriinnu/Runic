import RunicCore
import Foundation
import LocalAuthentication
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
            throw MiniMaxGroupIDStoreError.keychainStatus(status)
        }

        guard let data = result as? Data else {
            throw MiniMaxGroupIDStoreError.invalidData
        }
        let groupID = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let groupID, !groupID.isEmpty {
            return groupID
        }
        return nil
    }

    func storeGroupID(_ groupID: String?) throws {
        let cleaned = groupID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == nil || cleaned?.isEmpty == true {
            try self.deleteGroupIDIfPresent()
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
            throw MiniMaxGroupIDStoreError.keychainStatus(updateStatus)
        }

        var addQuery = query
        for (key, value) in attributes {
            addQuery[key] = value
        }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.log.error("Keychain add failed: \(addStatus)")
            throw MiniMaxGroupIDStoreError.keychainStatus(addStatus)
        }
    }

    private func deleteGroupIDIfPresent() throws {
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
        throw MiniMaxGroupIDStoreError.keychainStatus(status)
    }
}
