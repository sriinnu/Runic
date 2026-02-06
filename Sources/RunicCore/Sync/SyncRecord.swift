import Foundation
import CloudKit
import CryptoKit

// MARK: - CloudKit Record Type Constants

/// CloudKit record type identifiers
public enum CloudKitRecordType {
    public static let usageSnapshot = "UsageSnapshot"
    public static let userPreferences = "UserPreferences"
    public static let alertConfiguration = "AlertConfiguration"
    public static let syncMetadata = "SyncMetadata"
}

// MARK: - Usage Snapshot Sync Record

/// Syncable usage snapshot record for cross-device synchronization
///
/// This record encapsulates usage data that can be synchronized across
/// devices using CloudKit, with support for encryption and versioning.
public struct UsageSnapshotSyncRecord: SyncableRecord {
    public let recordID: String
    public let recordType: String = CloudKitRecordType.usageSnapshot
    public let version: Int
    public let modifiedAt: Date
    public let lastModifiedDeviceID: String?

    // Usage data
    public let providerID: String
    public let primaryUsed: Int
    public let primaryLimit: Int?
    public let secondaryUsed: Int?
    public let secondaryLimit: Int?
    public let costUSD: Double?
    public let accountEmail: String?
    public let updatedAt: Date

    // Metadata
    public let deviceName: String
    public let platform: String

    public init(
        recordID: String = UUID().uuidString,
        version: Int = 1,
        modifiedAt: Date = Date(),
        lastModifiedDeviceID: String? = nil,
        providerID: String,
        primaryUsed: Int,
        primaryLimit: Int?,
        secondaryUsed: Int? = nil,
        secondaryLimit: Int? = nil,
        costUSD: Double? = nil,
        accountEmail: String? = nil,
        updatedAt: Date = Date(),
        deviceName: String,
        platform: String
    ) {
        self.recordID = recordID
        self.version = version
        self.modifiedAt = modifiedAt
        self.lastModifiedDeviceID = lastModifiedDeviceID
        self.providerID = providerID
        self.primaryUsed = primaryUsed
        self.primaryLimit = primaryLimit
        self.secondaryUsed = secondaryUsed
        self.secondaryLimit = secondaryLimit
        self.costUSD = costUSD
        self.accountEmail = accountEmail
        self.updatedAt = updatedAt
        self.deviceName = deviceName
        self.platform = platform
    }

    public func toCKRecord() throws -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: recordID))

        record["version"] = version as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = lastModifiedDeviceID as? CKRecordValue
        record["providerID"] = providerID as CKRecordValue
        record["primaryUsed"] = primaryUsed as CKRecordValue
        record["primaryLimit"] = primaryLimit as? CKRecordValue
        record["secondaryUsed"] = secondaryUsed as? CKRecordValue
        record["secondaryLimit"] = secondaryLimit as? CKRecordValue
        record["costUSD"] = costUSD as? CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        record["deviceName"] = deviceName as CKRecordValue
        record["platform"] = platform as CKRecordValue

        // Encrypt sensitive data
        if let email = accountEmail {
            let encrypted = try encryptString(email)
            record["accountEmail"] = encrypted as CKRecordValue
        }

        return record
    }

    public static func fromCKRecord(_ ckRecord: CKRecord) throws -> UsageSnapshotSyncRecord {
        guard let version = ckRecord["version"] as? Int,
              let modifiedAt = ckRecord["modifiedAt"] as? Date,
              let providerID = ckRecord["providerID"] as? String,
              let primaryUsed = ckRecord["primaryUsed"] as? Int,
              let updatedAt = ckRecord["updatedAt"] as? Date,
              let deviceName = ckRecord["deviceName"] as? String,
              let platform = ckRecord["platform"] as? String
        else {
            throw SyncError.invalidRecordFormat("Missing required fields in UsageSnapshot")
        }

        var accountEmail: String?
        if let encryptedEmail = ckRecord["accountEmail"] as? String {
            accountEmail = try? decryptString(encryptedEmail)
        }

        return UsageSnapshotSyncRecord(
            recordID: ckRecord.recordID.recordName,
            version: version,
            modifiedAt: modifiedAt,
            lastModifiedDeviceID: ckRecord["lastModifiedDeviceID"] as? String,
            providerID: providerID,
            primaryUsed: primaryUsed,
            primaryLimit: ckRecord["primaryLimit"] as? Int,
            secondaryUsed: ckRecord["secondaryUsed"] as? Int,
            secondaryLimit: ckRecord["secondaryLimit"] as? Int,
            costUSD: ckRecord["costUSD"] as? Double,
            accountEmail: accountEmail,
            updatedAt: updatedAt,
            deviceName: deviceName,
            platform: platform
        )
    }
}

// MARK: - User Preferences Sync Record

/// Syncable user preferences record
///
/// Stores user preferences and settings that should be synchronized
/// across all devices where the user is signed in.
public struct UserPreferencesSyncRecord: SyncableRecord {
    public let recordID: String
    public let recordType: String = CloudKitRecordType.userPreferences
    public let version: Int
    public let modifiedAt: Date
    public let lastModifiedDeviceID: String?

    // Preferences
    public let refreshInterval: TimeInterval
    public let enabledProviders: [String]
    public let notificationsEnabled: Bool
    public let autoRefreshEnabled: Bool
    public let theme: String
    public let displayFormat: String

    public init(
        recordID: String = "user-preferences",
        version: Int = 1,
        modifiedAt: Date = Date(),
        lastModifiedDeviceID: String? = nil,
        refreshInterval: TimeInterval = 300,
        enabledProviders: [String] = [],
        notificationsEnabled: Bool = true,
        autoRefreshEnabled: Bool = true,
        theme: String = "system",
        displayFormat: String = "compact"
    ) {
        self.recordID = recordID
        self.version = version
        self.modifiedAt = modifiedAt
        self.lastModifiedDeviceID = lastModifiedDeviceID
        self.refreshInterval = refreshInterval
        self.enabledProviders = enabledProviders
        self.notificationsEnabled = notificationsEnabled
        self.autoRefreshEnabled = autoRefreshEnabled
        self.theme = theme
        self.displayFormat = displayFormat
    }

    public func toCKRecord() throws -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: recordID))

        record["version"] = version as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = lastModifiedDeviceID as? CKRecordValue
        record["refreshInterval"] = refreshInterval as CKRecordValue
        record["enabledProviders"] = enabledProviders as CKRecordValue
        record["notificationsEnabled"] = (notificationsEnabled ? 1 : 0) as CKRecordValue
        record["autoRefreshEnabled"] = (autoRefreshEnabled ? 1 : 0) as CKRecordValue
        record["theme"] = theme as CKRecordValue
        record["displayFormat"] = displayFormat as CKRecordValue

        return record
    }

    public static func fromCKRecord(_ ckRecord: CKRecord) throws -> UserPreferencesSyncRecord {
        guard let version = ckRecord["version"] as? Int,
              let modifiedAt = ckRecord["modifiedAt"] as? Date,
              let refreshInterval = ckRecord["refreshInterval"] as? Double,
              let enabledProviders = ckRecord["enabledProviders"] as? [String],
              let notificationsEnabled = ckRecord["notificationsEnabled"] as? Int,
              let autoRefreshEnabled = ckRecord["autoRefreshEnabled"] as? Int,
              let theme = ckRecord["theme"] as? String,
              let displayFormat = ckRecord["displayFormat"] as? String
        else {
            throw SyncError.invalidRecordFormat("Missing required fields in UserPreferences")
        }

        return UserPreferencesSyncRecord(
            recordID: ckRecord.recordID.recordName,
            version: version,
            modifiedAt: modifiedAt,
            lastModifiedDeviceID: ckRecord["lastModifiedDeviceID"] as? String,
            refreshInterval: refreshInterval,
            enabledProviders: enabledProviders,
            notificationsEnabled: notificationsEnabled == 1,
            autoRefreshEnabled: autoRefreshEnabled == 1,
            theme: theme,
            displayFormat: displayFormat
        )
    }
}

// MARK: - Alert Configuration Sync Record

/// Syncable alert configuration record
///
/// Stores alert thresholds and notification settings that should be
/// consistent across all user devices.
public struct AlertConfigurationSyncRecord: SyncableRecord {
    public let recordID: String
    public let recordType: String = CloudKitRecordType.alertConfiguration
    public let version: Int
    public let modifiedAt: Date
    public let lastModifiedDeviceID: String?

    // Alert settings
    public let providerID: String
    public let warningThreshold: Double
    public let criticalThreshold: Double
    public let notificationChannels: [String]
    public let enabled: Bool

    public init(
        recordID: String = UUID().uuidString,
        version: Int = 1,
        modifiedAt: Date = Date(),
        lastModifiedDeviceID: String? = nil,
        providerID: String,
        warningThreshold: Double = 0.75,
        criticalThreshold: Double = 0.90,
        notificationChannels: [String] = ["system"],
        enabled: Bool = true
    ) {
        self.recordID = recordID
        self.version = version
        self.modifiedAt = modifiedAt
        self.lastModifiedDeviceID = lastModifiedDeviceID
        self.providerID = providerID
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
        self.notificationChannels = notificationChannels
        self.enabled = enabled
    }

    public func toCKRecord() throws -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: recordID))

        record["version"] = version as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = lastModifiedDeviceID as? CKRecordValue
        record["providerID"] = providerID as CKRecordValue
        record["warningThreshold"] = warningThreshold as CKRecordValue
        record["criticalThreshold"] = criticalThreshold as CKRecordValue
        record["notificationChannels"] = notificationChannels as CKRecordValue
        record["enabled"] = (enabled ? 1 : 0) as CKRecordValue

        return record
    }

    public static func fromCKRecord(_ ckRecord: CKRecord) throws -> AlertConfigurationSyncRecord {
        guard let version = ckRecord["version"] as? Int,
              let modifiedAt = ckRecord["modifiedAt"] as? Date,
              let providerID = ckRecord["providerID"] as? String,
              let warningThreshold = ckRecord["warningThreshold"] as? Double,
              let criticalThreshold = ckRecord["criticalThreshold"] as? Double,
              let notificationChannels = ckRecord["notificationChannels"] as? [String],
              let enabled = ckRecord["enabled"] as? Int
        else {
            throw SyncError.invalidRecordFormat("Missing required fields in AlertConfiguration")
        }

        return AlertConfigurationSyncRecord(
            recordID: ckRecord.recordID.recordName,
            version: version,
            modifiedAt: modifiedAt,
            lastModifiedDeviceID: ckRecord["lastModifiedDeviceID"] as? String,
            providerID: providerID,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold,
            notificationChannels: notificationChannels,
            enabled: enabled == 1
        )
    }
}

// MARK: - Encryption Helpers

/// Encrypts a string using AES-GCM encryption
///
/// - Parameter plaintext: The string to encrypt
/// - Returns: Base64-encoded encrypted string with nonce prepended
/// - Throws: SyncError.encryptionFailed if encryption fails
private func encryptString(_ plaintext: String) throws -> String {
    guard let data = plaintext.data(using: .utf8) else {
        throw SyncError.encryptionFailed("Failed to convert string to data")
    }

    let key = getOrCreateEncryptionKey()
    let sealed = try AES.GCM.seal(data, using: key)

    guard let combined = sealed.combined else {
        throw SyncError.encryptionFailed("Failed to create sealed box")
    }

    return combined.base64EncodedString()
}

/// Decrypts a string that was encrypted with encryptString
///
/// - Parameter encrypted: Base64-encoded encrypted string
/// - Returns: Decrypted plaintext string
/// - Throws: SyncError.encryptionFailed if decryption fails
private func decryptString(_ encrypted: String) throws -> String {
    guard let combined = Data(base64Encoded: encrypted) else {
        throw SyncError.encryptionFailed("Failed to decode base64")
    }

    let key = getOrCreateEncryptionKey()
    let sealedBox = try AES.GCM.SealedBox(combined: combined)
    let decrypted = try AES.GCM.open(sealedBox, using: key)

    guard let plaintext = String(data: decrypted, encoding: .utf8) else {
        throw SyncError.encryptionFailed("Failed to convert decrypted data to string")
    }

    return plaintext
}

/// Retrieves or creates an encryption key for sensitive data
///
/// The key is stored securely in the Keychain and persists across app launches.
///
/// - Returns: SymmetricKey for AES-GCM encryption
private func getOrCreateEncryptionKey() -> SymmetricKey {
    let keychainKey = "com.runic.sync.encryption.key"

    // Try to load existing key from Keychain
    if let keyData = loadFromKeychain(key: keychainKey) {
        return SymmetricKey(data: keyData)
    }

    // Generate new key
    let key = SymmetricKey(size: .bits256)
    let keyData = key.withUnsafeBytes { Data($0) }

    // Store in Keychain
    saveToKeychain(key: keychainKey, data: keyData)

    return key
}

private func saveToKeychain(key: String, data: Data) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.sriinnu.athena.Runic",
        kSecAttrAccount as String: key,
        kSecUseDataProtectionKeychain as String: true,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]
    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
}

private func loadFromKeychain(key: String) -> Data? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.sriinnu.athena.Runic",
        kSecAttrAccount as String: key,
        kSecUseDataProtectionKeychain as String: true,
        kSecReturnData as String: true
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    return status == errSecSuccess ? result as? Data : nil
}
