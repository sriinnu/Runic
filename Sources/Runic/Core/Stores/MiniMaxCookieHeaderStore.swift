import RunicCore
import Foundation
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
        var result: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
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
        if let header, !header.isEmpty {
            return header
        }
        return nil
    }

    func storeHeader(_ header: String?) throws {
        let cleaned = header?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == nil || cleaned?.isEmpty == true {
            try self.deleteHeaderIfPresent()
            return
        }

        let data = cleaned!.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
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
            throw MiniMaxCookieHeaderStoreError.keychainStatus(updateStatus)
        }

        var addQuery = query
        for (key, value) in attributes {
            addQuery[key] = value
        }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.log.error("Keychain add failed: \(addStatus)")
            throw MiniMaxCookieHeaderStoreError.keychainStatus(addStatus)
        }
    }

    private func deleteHeaderIfPresent() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        Self.log.error("Keychain delete failed: \(status)")
        throw MiniMaxCookieHeaderStoreError.keychainStatus(status)
    }
}
