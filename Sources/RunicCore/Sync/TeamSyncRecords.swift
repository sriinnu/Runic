import Foundation
import CloudKit
import CryptoKit
import LocalAuthentication

// MARK: - CloudKit Record Type Constants

extension CloudKitRecordType {
    public static let team = "Team"
    public static let teamMembership = "TeamMembership"
    public static let projectOwnership = "ProjectOwnership"
    public static let teamUsageSnapshot = "TeamUsageSnapshot"
}

// MARK: - CloudKit Custom Zone Configuration

/// Custom zone for team collaboration data
///
/// Using a custom zone allows for atomic batch operations and better
/// change tracking for team-related records.
public struct TeamSyncZone {
    public static let zoneName = "TeamCollaborationZone"
    public static let ownerName = CKCurrentUserDefaultName

    public static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
    }

    public static func createZone() -> CKRecordZone {
        CKRecordZone(zoneID: zoneID)
    }
}

// MARK: - Team Record

/// Team record for CloudKit synchronization
///
/// Represents a collaborative team that can share usage quotas and projects.
/// - Record Type: "Team"
/// - Queryable by: ownerUserID
/// - Zone: TeamCollaborationZone (custom zone)
public struct TeamRecord: SyncableRecord {
    public let recordID: String
    public let recordType: String = CloudKitRecordType.team
    public let version: Int
    public let modifiedAt: Date
    public let lastModifiedDeviceID: String?

    // Team data
    public let teamID: String
    public let name: String
    public let ownerUserID: String
    public let totalQuota: Int64
    public let createdAt: Date
    public let updatedAt: Date

    // Optional metadata
    public let description: String?
    public let avatarURL: String?
    public let isActive: Bool

    public init(
        recordID: String = UUID().uuidString,
        version: Int = 1,
        modifiedAt: Date = Date(),
        lastModifiedDeviceID: String? = nil,
        teamID: String = UUID().uuidString,
        name: String,
        ownerUserID: String,
        totalQuota: Int64,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        description: String? = nil,
        avatarURL: String? = nil,
        isActive: Bool = true
    ) {
        self.recordID = recordID
        self.version = version
        self.modifiedAt = modifiedAt
        self.lastModifiedDeviceID = lastModifiedDeviceID
        self.teamID = teamID
        self.name = name
        self.ownerUserID = ownerUserID
        self.totalQuota = totalQuota
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.description = description
        self.avatarURL = avatarURL
        self.isActive = isActive
    }

    public func toCKRecord() throws -> CKRecord {
        let zoneID = TeamSyncZone.zoneID
        let record = CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: recordID, zoneID: zoneID)
        )

        // Sync metadata
        record["version"] = version as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = lastModifiedDeviceID as? CKRecordValue

        // Team data
        record["teamID"] = teamID as CKRecordValue
        record["name"] = name as CKRecordValue
        record["ownerUserID"] = ownerUserID as CKRecordValue
        record["totalQuota"] = totalQuota as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        record["isActive"] = (isActive ? 1 : 0) as CKRecordValue

        // Optional fields
        record["description"] = description as? CKRecordValue
        record["avatarURL"] = avatarURL as? CKRecordValue

        return record
    }

    public static func fromCKRecord(_ ckRecord: CKRecord) throws -> TeamRecord {
        guard let version = ckRecord["version"] as? Int,
              let modifiedAt = ckRecord["modifiedAt"] as? Date,
              let teamID = ckRecord["teamID"] as? String,
              let name = ckRecord["name"] as? String,
              let ownerUserID = ckRecord["ownerUserID"] as? String,
              let totalQuota = ckRecord["totalQuota"] as? Int64,
              let createdAt = ckRecord["createdAt"] as? Date,
              let updatedAt = ckRecord["updatedAt"] as? Date,
              let isActiveInt = ckRecord["isActive"] as? Int
        else {
            throw SyncError.invalidRecordFormat("Missing required fields in Team record")
        }

        return TeamRecord(
            recordID: ckRecord.recordID.recordName,
            version: version,
            modifiedAt: modifiedAt,
            lastModifiedDeviceID: ckRecord["lastModifiedDeviceID"] as? String,
            teamID: teamID,
            name: name,
            ownerUserID: ownerUserID,
            totalQuota: totalQuota,
            createdAt: createdAt,
            updatedAt: updatedAt,
            description: ckRecord["description"] as? String,
            avatarURL: ckRecord["avatarURL"] as? String,
            isActive: isActiveInt == 1
        )
    }
}

// MARK: - Team Membership Record

/// Team membership record for CloudKit synchronization
///
/// Represents a user's membership in a team with role and quota information.
/// - Record Type: "TeamMembership"
/// - Queryable by: teamID, userID
/// - References: Team record (parent)
/// - Zone: TeamCollaborationZone (custom zone)
public struct TeamMembershipRecord: SyncableRecord {
    public let recordID: String
    public let recordType: String = CloudKitRecordType.teamMembership
    public let version: Int
    public let modifiedAt: Date
    public let lastModifiedDeviceID: String?

    // Membership data
    public let membershipID: String
    public let teamID: String
    public let userID: String
    public let role: TeamRole
    public let quotaLimit: Int64?
    public let joinedAt: Date

    // Optional metadata
    public let email: String?
    public let displayName: String?
    public let invitedBy: String?
    public let acceptedAt: Date?
    public let isActive: Bool

    // Reference to parent team
    public let teamRecordName: String

    public enum TeamRole: String, Codable, Sendable {
        case owner = "owner"
        case admin = "admin"
        case member = "member"
        case viewer = "viewer"
    }

    public init(
        recordID: String = UUID().uuidString,
        version: Int = 1,
        modifiedAt: Date = Date(),
        lastModifiedDeviceID: String? = nil,
        membershipID: String = UUID().uuidString,
        teamID: String,
        userID: String,
        role: TeamRole,
        quotaLimit: Int64? = nil,
        joinedAt: Date = Date(),
        email: String? = nil,
        displayName: String? = nil,
        invitedBy: String? = nil,
        acceptedAt: Date? = nil,
        isActive: Bool = true,
        teamRecordName: String
    ) {
        self.recordID = recordID
        self.version = version
        self.modifiedAt = modifiedAt
        self.lastModifiedDeviceID = lastModifiedDeviceID
        self.membershipID = membershipID
        self.teamID = teamID
        self.userID = userID
        self.role = role
        self.quotaLimit = quotaLimit
        self.joinedAt = joinedAt
        self.email = email
        self.displayName = displayName
        self.invitedBy = invitedBy
        self.acceptedAt = acceptedAt
        self.isActive = isActive
        self.teamRecordName = teamRecordName
    }

    public func toCKRecord() throws -> CKRecord {
        let zoneID = TeamSyncZone.zoneID
        let record = CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: recordID, zoneID: zoneID)
        )

        // Sync metadata
        record["version"] = version as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = lastModifiedDeviceID as? CKRecordValue

        // Membership data
        record["membershipID"] = membershipID as CKRecordValue
        record["teamID"] = teamID as CKRecordValue
        record["userID"] = userID as CKRecordValue
        record["role"] = role.rawValue as CKRecordValue
        record["quotaLimit"] = quotaLimit as? CKRecordValue
        record["joinedAt"] = joinedAt as CKRecordValue
        record["isActive"] = (isActive ? 1 : 0) as CKRecordValue

        // Optional encrypted fields
        if let email = email {
            let encrypted = try encryptString(email)
            record["email"] = encrypted as CKRecordValue
        }
        record["displayName"] = displayName as? CKRecordValue
        record["invitedBy"] = invitedBy as? CKRecordValue
        record["acceptedAt"] = acceptedAt as? CKRecordValue

        // Reference to parent team
        let teamReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: teamRecordName, zoneID: zoneID),
            action: .deleteSelf
        )
        record["teamReference"] = teamReference as CKRecordValue

        return record
    }

    public static func fromCKRecord(_ ckRecord: CKRecord) throws -> TeamMembershipRecord {
        guard let version = ckRecord["version"] as? Int,
              let modifiedAt = ckRecord["modifiedAt"] as? Date,
              let membershipID = ckRecord["membershipID"] as? String,
              let teamID = ckRecord["teamID"] as? String,
              let userID = ckRecord["userID"] as? String,
              let roleString = ckRecord["role"] as? String,
              let role = TeamRole(rawValue: roleString),
              let joinedAt = ckRecord["joinedAt"] as? Date,
              let isActiveInt = ckRecord["isActive"] as? Int,
              let teamReference = ckRecord["teamReference"] as? CKRecord.Reference
        else {
            throw SyncError.invalidRecordFormat("Missing required fields in TeamMembership record")
        }

        var email: String?
        if let encryptedEmail = ckRecord["email"] as? String {
            email = try? decryptString(encryptedEmail)
        }

        return TeamMembershipRecord(
            recordID: ckRecord.recordID.recordName,
            version: version,
            modifiedAt: modifiedAt,
            lastModifiedDeviceID: ckRecord["lastModifiedDeviceID"] as? String,
            membershipID: membershipID,
            teamID: teamID,
            userID: userID,
            role: role,
            quotaLimit: ckRecord["quotaLimit"] as? Int64,
            joinedAt: joinedAt,
            email: email,
            displayName: ckRecord["displayName"] as? String,
            invitedBy: ckRecord["invitedBy"] as? String,
            acceptedAt: ckRecord["acceptedAt"] as? Date,
            isActive: isActiveInt == 1,
            teamRecordName: teamReference.recordID.recordName
        )
    }
}

// MARK: - Project Ownership Record

/// Project ownership record for CloudKit synchronization
///
/// Represents ownership and sharing permissions for a project.
/// - Record Type: "ProjectOwnership"
/// - Queryable by: ownerUserID, teamID, projectID
/// - References: Team record (optional - if team-owned)
/// - Zone: TeamCollaborationZone (custom zone)
public struct ProjectOwnershipRecord: SyncableRecord {
    public let recordID: String
    public let recordType: String = CloudKitRecordType.projectOwnership
    public let version: Int
    public let modifiedAt: Date
    public let lastModifiedDeviceID: String?

    // Project ownership data
    public let projectID: String
    public let teamID: String?
    public let ownerUserID: String
    public let sharedWith: [String]
    public let accessLevel: AccessLevel
    public let createdAt: Date

    // Optional metadata
    public let projectName: String?
    public let projectDescription: String?
    public let tags: [String]
    public let isArchived: Bool

    // Reference to team (if team-owned)
    public let teamRecordName: String?

    public enum AccessLevel: String, Codable, Sendable {
        case `private` = "private"
        case teamReadOnly = "team_read_only"
        case teamReadWrite = "team_read_write"
        case `public` = "public"
    }

    public init(
        recordID: String = UUID().uuidString,
        version: Int = 1,
        modifiedAt: Date = Date(),
        lastModifiedDeviceID: String? = nil,
        projectID: String = UUID().uuidString,
        teamID: String? = nil,
        ownerUserID: String,
        sharedWith: [String] = [],
        accessLevel: AccessLevel = .private,
        createdAt: Date = Date(),
        projectName: String? = nil,
        projectDescription: String? = nil,
        tags: [String] = [],
        isArchived: Bool = false,
        teamRecordName: String? = nil
    ) {
        self.recordID = recordID
        self.version = version
        self.modifiedAt = modifiedAt
        self.lastModifiedDeviceID = lastModifiedDeviceID
        self.projectID = projectID
        self.teamID = teamID
        self.ownerUserID = ownerUserID
        self.sharedWith = sharedWith
        self.accessLevel = accessLevel
        self.createdAt = createdAt
        self.projectName = projectName
        self.projectDescription = projectDescription
        self.tags = tags
        self.isArchived = isArchived
        self.teamRecordName = teamRecordName
    }

    public func toCKRecord() throws -> CKRecord {
        let zoneID = TeamSyncZone.zoneID
        let record = CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: recordID, zoneID: zoneID)
        )

        // Sync metadata
        record["version"] = version as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = lastModifiedDeviceID as? CKRecordValue

        // Project ownership data
        record["projectID"] = projectID as CKRecordValue
        record["teamID"] = teamID as? CKRecordValue
        record["ownerUserID"] = ownerUserID as CKRecordValue
        record["sharedWith"] = sharedWith as CKRecordValue
        record["accessLevel"] = accessLevel.rawValue as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["isArchived"] = (isArchived ? 1 : 0) as CKRecordValue

        // Optional metadata
        record["projectName"] = projectName as? CKRecordValue
        record["projectDescription"] = projectDescription as? CKRecordValue
        record["tags"] = tags as CKRecordValue

        // Reference to team (if team-owned)
        if let teamRecordName = teamRecordName {
            let teamReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: teamRecordName, zoneID: zoneID),
                action: .none
            )
            record["teamReference"] = teamReference as CKRecordValue
        }

        return record
    }

    public static func fromCKRecord(_ ckRecord: CKRecord) throws -> ProjectOwnershipRecord {
        guard let version = ckRecord["version"] as? Int,
              let modifiedAt = ckRecord["modifiedAt"] as? Date,
              let projectID = ckRecord["projectID"] as? String,
              let ownerUserID = ckRecord["ownerUserID"] as? String,
              let sharedWith = ckRecord["sharedWith"] as? [String],
              let accessLevelString = ckRecord["accessLevel"] as? String,
              let accessLevel = AccessLevel(rawValue: accessLevelString),
              let createdAt = ckRecord["createdAt"] as? Date,
              let isArchivedInt = ckRecord["isArchived"] as? Int
        else {
            throw SyncError.invalidRecordFormat("Missing required fields in ProjectOwnership record")
        }

        let teamReference = ckRecord["teamReference"] as? CKRecord.Reference

        return ProjectOwnershipRecord(
            recordID: ckRecord.recordID.recordName,
            version: version,
            modifiedAt: modifiedAt,
            lastModifiedDeviceID: ckRecord["lastModifiedDeviceID"] as? String,
            projectID: projectID,
            teamID: ckRecord["teamID"] as? String,
            ownerUserID: ownerUserID,
            sharedWith: sharedWith,
            accessLevel: accessLevel,
            createdAt: createdAt,
            projectName: ckRecord["projectName"] as? String,
            projectDescription: ckRecord["projectDescription"] as? String,
            tags: ckRecord["tags"] as? [String] ?? [],
            isArchived: isArchivedInt == 1,
            teamRecordName: teamReference?.recordID.recordName
        )
    }
}

// MARK: - Team Usage Snapshot Record

/// Team usage snapshot record for CloudKit synchronization
///
/// Aggregates usage data across team members for tracking and quota management.
/// - Record Type: "TeamUsageSnapshot"
/// - Queryable by: teamID, date
/// - References: Team record (parent)
/// - Zone: TeamCollaborationZone (custom zone)
public struct TeamUsageSnapshotRecord: SyncableRecord {
    public let recordID: String
    public let recordType: String = CloudKitRecordType.teamUsageSnapshot
    public let version: Int
    public let modifiedAt: Date
    public let lastModifiedDeviceID: String?

    // Team usage data
    public let teamID: String
    public let date: Date
    public let totalTokens: Int64
    public let totalCost: Double
    public let memberUsage: [String: MemberUsageData]
    public let quotaUsedPercent: Double

    // Additional metrics
    public let primaryProvider: String?
    public let mostActiveUser: String?
    public let averageTokensPerMember: Double

    // Reference to parent team
    public let teamRecordName: String

    public struct MemberUsageData: Codable, Sendable, Hashable {
        public let userID: String
        public let tokens: Int64
        public let cost: Double
        public let requestCount: Int

        public init(userID: String, tokens: Int64, cost: Double, requestCount: Int) {
            self.userID = userID
            self.tokens = tokens
            self.cost = cost
            self.requestCount = requestCount
        }
    }

    public init(
        recordID: String = UUID().uuidString,
        version: Int = 1,
        modifiedAt: Date = Date(),
        lastModifiedDeviceID: String? = nil,
        teamID: String,
        date: Date = Date(),
        totalTokens: Int64,
        totalCost: Double,
        memberUsage: [String: MemberUsageData] = [:],
        quotaUsedPercent: Double,
        primaryProvider: String? = nil,
        mostActiveUser: String? = nil,
        averageTokensPerMember: Double = 0.0,
        teamRecordName: String
    ) {
        self.recordID = recordID
        self.version = version
        self.modifiedAt = modifiedAt
        self.lastModifiedDeviceID = lastModifiedDeviceID
        self.teamID = teamID
        self.date = date
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.memberUsage = memberUsage
        self.quotaUsedPercent = quotaUsedPercent
        self.primaryProvider = primaryProvider
        self.mostActiveUser = mostActiveUser
        self.averageTokensPerMember = averageTokensPerMember
        self.teamRecordName = teamRecordName
    }

    public func toCKRecord() throws -> CKRecord {
        let zoneID = TeamSyncZone.zoneID
        let record = CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: recordID, zoneID: zoneID)
        )

        // Sync metadata
        record["version"] = version as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = lastModifiedDeviceID as? CKRecordValue

        // Team usage data
        record["teamID"] = teamID as CKRecordValue
        record["date"] = date as CKRecordValue
        record["totalTokens"] = totalTokens as CKRecordValue
        record["totalCost"] = totalCost as CKRecordValue
        record["quotaUsedPercent"] = quotaUsedPercent as CKRecordValue

        // Encode member usage as JSON
        let encoder = JSONEncoder()
        let memberUsageData = try encoder.encode(memberUsage)
        record["memberUsage"] = String(data: memberUsageData, encoding: .utf8) as? CKRecordValue

        // Optional metrics
        record["primaryProvider"] = primaryProvider as? CKRecordValue
        record["mostActiveUser"] = mostActiveUser as? CKRecordValue
        record["averageTokensPerMember"] = averageTokensPerMember as CKRecordValue

        // Reference to parent team
        let teamReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: teamRecordName, zoneID: zoneID),
            action: .deleteSelf
        )
        record["teamReference"] = teamReference as CKRecordValue

        return record
    }

    public static func fromCKRecord(_ ckRecord: CKRecord) throws -> TeamUsageSnapshotRecord {
        guard let version = ckRecord["version"] as? Int,
              let modifiedAt = ckRecord["modifiedAt"] as? Date,
              let teamID = ckRecord["teamID"] as? String,
              let date = ckRecord["date"] as? Date,
              let totalTokens = ckRecord["totalTokens"] as? Int64,
              let totalCost = ckRecord["totalCost"] as? Double,
              let quotaUsedPercent = ckRecord["quotaUsedPercent"] as? Double,
              let teamReference = ckRecord["teamReference"] as? CKRecord.Reference
        else {
            throw SyncError.invalidRecordFormat("Missing required fields in TeamUsageSnapshot record")
        }

        // Decode member usage from JSON
        var memberUsage: [String: MemberUsageData] = [:]
        if let memberUsageJSON = ckRecord["memberUsage"] as? String,
           let data = memberUsageJSON.data(using: .utf8) {
            let decoder = JSONDecoder()
            memberUsage = (try? decoder.decode([String: MemberUsageData].self, from: data)) ?? [:]
        }

        return TeamUsageSnapshotRecord(
            recordID: ckRecord.recordID.recordName,
            version: version,
            modifiedAt: modifiedAt,
            lastModifiedDeviceID: ckRecord["lastModifiedDeviceID"] as? String,
            teamID: teamID,
            date: date,
            totalTokens: totalTokens,
            totalCost: totalCost,
            memberUsage: memberUsage,
            quotaUsedPercent: quotaUsedPercent,
            primaryProvider: ckRecord["primaryProvider"] as? String,
            mostActiveUser: ckRecord["mostActiveUser"] as? String,
            averageTokensPerMember: ckRecord["averageTokensPerMember"] as? Double ?? 0.0,
            teamRecordName: teamReference.recordID.recordName
        )
    }
}

// MARK: - CloudKit Query Helpers

/// Helper methods for querying team-related records
public enum TeamRecordQuery {

    /// Creates a predicate to query teams by owner
    public static func teamsByOwner(_ ownerUserID: String) -> NSPredicate {
        NSPredicate(format: "ownerUserID == %@", ownerUserID)
    }

    /// Creates a predicate to query memberships by team
    public static func membershipsByTeam(_ teamID: String) -> NSPredicate {
        NSPredicate(format: "teamID == %@ AND isActive == 1", teamID)
    }

    /// Creates a predicate to query memberships by user
    public static func membershipsByUser(_ userID: String) -> NSPredicate {
        NSPredicate(format: "userID == %@ AND isActive == 1", userID)
    }

    /// Creates a predicate to query projects by owner
    public static func projectsByOwner(_ ownerUserID: String) -> NSPredicate {
        NSPredicate(format: "ownerUserID == %@ AND isArchived == 0", ownerUserID)
    }

    /// Creates a predicate to query projects by team
    public static func projectsByTeam(_ teamID: String) -> NSPredicate {
        NSPredicate(format: "teamID == %@ AND isArchived == 0", teamID)
    }

    /// Creates a predicate to query team usage snapshots by date range
    public static func teamUsageByDateRange(teamID: String, startDate: Date, endDate: Date) -> NSPredicate {
        NSPredicate(format: "teamID == %@ AND date >= %@ AND date <= %@", teamID, startDate as NSDate, endDate as NSDate)
    }

    /// Creates a predicate to query latest team usage
    public static func latestTeamUsage(_ teamID: String) -> NSPredicate {
        NSPredicate(format: "teamID == %@", teamID)
    }
}

// MARK: - CloudKit Index Configuration

/// Recommended CloudKit indexes for efficient querying
///
/// Configure these indexes in CloudKit Dashboard for optimal performance:
///
/// Team Record:
/// - ownerUserID (Queryable, Sortable)
/// - isActive (Queryable)
/// - createdAt (Sortable)
///
/// TeamMembership Record:
/// - teamID (Queryable, Sortable)
/// - userID (Queryable, Sortable)
/// - isActive (Queryable)
/// - role (Queryable)
/// - joinedAt (Sortable)
///
/// ProjectOwnership Record:
/// - ownerUserID (Queryable, Sortable)
/// - teamID (Queryable, Sortable)
/// - projectID (Queryable)
/// - isArchived (Queryable)
/// - accessLevel (Queryable)
/// - createdAt (Sortable)
///
/// TeamUsageSnapshot Record:
/// - teamID (Queryable, Sortable)
/// - date (Queryable, Sortable)
/// - quotaUsedPercent (Sortable)
public enum TeamRecordIndexes {
    // This is a documentation enum - configure actual indexes in CloudKit Dashboard
}

// MARK: - Encryption Helpers (Team-specific)

/// Encrypts a string using AES-GCM encryption (team-specific wrapper)
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
private func getOrCreateEncryptionKey() -> SymmetricKey {
    let keychainKey = "com.runic.sync.team.encryption.key"

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
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.sriinnu.athena.Runic",
        kSecAttrAccount as String: key,
        kSecUseDataProtectionKeychain as String: true,
        kSecReturnData as String: true
    ]
    let authContext = LAContext()
    authContext.interactionNotAllowed = true
    query[kSecUseAuthenticationContext as String] = authContext
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecInteractionNotAllowed {
        return nil
    }
    return status == errSecSuccess ? result as? Data : nil
}
