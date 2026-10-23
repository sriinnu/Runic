import CryptoKit
import Foundation
import Security

/// Encrypts a string using AES-GCM encryption (team-specific wrapper)
func teamSyncEncryptString(_ plaintext: String) throws -> String {
    guard let data = plaintext.data(using: .utf8) else {
        throw SyncError.encryptionFailed("Failed to convert string to data")
    }

    let key = try getTeamSyncEncryptionKey(createIfMissing: true)
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

    let key = try getTeamSyncEncryptionKey(createIfMissing: false)
    let sealedBox = try AES.GCM.SealedBox(combined: combined)
    let decrypted = try AES.GCM.open(sealedBox, using: key)

    guard let plaintext = String(data: decrypted, encoding: .utf8) else {
        throw SyncError.encryptionFailed("Failed to convert decrypted data to string")
    }

    return plaintext
}

/// Retrieves or creates an encryption key for sensitive data
private func getTeamSyncEncryptionKey(createIfMissing: Bool) throws -> SymmetricKey {
    let keychainKey = "com.runic.sync.team.encryption.key"

    if let keyData = try loadTeamSyncKeyFromKeychain(key: keychainKey) {
        return SymmetricKey(data: keyData)
    }
    guard createIfMissing else {
        throw SyncError.encryptionFailed("Team sync encryption key is missing")
    }

    let key = SymmetricKey(size: .bits256)
    let keyData = key.withUnsafeBytes { Data($0) }
    let status = saveTeamSyncKeyToKeychain(key: keychainKey, data: keyData)
    if status == errSecSuccess { return key }
    if status == errSecDuplicateItem,
       let existing = try loadTeamSyncKeyFromKeychain(key: keychainKey)
    {
        return SymmetricKey(data: existing)
    }
    throw SyncError.encryptionFailed("Could not persist team sync encryption key (\(status))")
}

private func saveTeamSyncKeyToKeychain(key: String, data: Data) -> OSStatus {
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.sriinnu.athena.Runic",
        kSecAttrAccount as String: key,
        kSecUseDataProtectionKeychain as String: true,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]
    RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
    return RunicKeychainGate.add(query as CFDictionary)
}

private func loadTeamSyncKeyFromKeychain(key: String) throws -> Data? {
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.sriinnu.athena.Runic",
        kSecAttrAccount as String: key,
        kSecUseDataProtectionKeychain as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecReturnData as String: true,
    ]
    RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
    var result: CFTypeRef?
    let status = RunicKeychainGate.copyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else {
        throw SyncError.encryptionFailed("Could not read team sync encryption key (\(status))")
    }
    guard let data = result as? Data, data.count == 32 else {
        throw SyncError.encryptionFailed("Team sync encryption key has an invalid length")
    }
    return data
}
