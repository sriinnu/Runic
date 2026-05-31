import CryptoKit
import Foundation
import Security

/// Encrypts a string using AES-GCM encryption (team-specific wrapper)
func teamSyncEncryptString(_ plaintext: String) throws -> String {
    guard let data = plaintext.data(using: .utf8) else {
        throw SyncError.encryptionFailed("Failed to convert string to data")
    }

    let key = getOrCreateTeamSyncEncryptionKey()
    let sealed = try AES.GCM.seal(data, using: key)

    guard let combined = sealed.combined else {
        throw SyncError.encryptionFailed("Failed to create sealed box")
    }

    return combined.base64EncodedString()
}

/// Decrypts a string that was encrypted with teamSyncEncryptString
func teamSyncDecryptString(_ encrypted: String) throws -> String {
    guard let combined = Data(base64Encoded: encrypted) else {
        throw SyncError.encryptionFailed("Failed to decode base64")
    }

    let key = getOrCreateTeamSyncEncryptionKey()
    let sealedBox = try AES.GCM.SealedBox(combined: combined)
    let decrypted = try AES.GCM.open(sealedBox, using: key)

    guard let plaintext = String(data: decrypted, encoding: .utf8) else {
        throw SyncError.encryptionFailed("Failed to convert decrypted data to string")
    }

    return plaintext
}

/// Retrieves or creates an encryption key for sensitive data
private func getOrCreateTeamSyncEncryptionKey() -> SymmetricKey {
    let keychainKey = "com.runic.sync.team.encryption.key"

    // Try to load existing key from Keychain
    if let keyData = loadTeamSyncKeyFromKeychain(key: keychainKey) {
        return SymmetricKey(data: keyData)
    }

    // Generate new key
    let key = SymmetricKey(size: .bits256)
    let keyData = key.withUnsafeBytes { Data($0) }

    // Store in Keychain
    saveTeamSyncKeyToKeychain(key: keychainKey, data: keyData)

    return key
}

private func saveTeamSyncKeyToKeychain(key: String, data: Data) {
    let baseQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.sriinnu.athena.Runic",
        kSecAttrAccount as String: key,
        kSecUseDataProtectionKeychain as String: true,
    ]
    var deleteQuery = baseQuery
    RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &deleteQuery)
    SecItemDelete(deleteQuery as CFDictionary)

    var addQuery = baseQuery
    addQuery[kSecValueData as String] = data
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(addQuery as CFDictionary, nil)
}

private func loadTeamSyncKeyFromKeychain(key: String) -> Data? {
    let returnDataAttribute = "r_Data"
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.sriinnu.athena.Runic",
        kSecAttrAccount as String: key,
        kSecUseDataProtectionKeychain as String: true,
        returnDataAttribute: true,
    ]
    RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecInteractionNotAllowed {
        return nil
    }
    return status == errSecSuccess ? result as? Data : nil
}
