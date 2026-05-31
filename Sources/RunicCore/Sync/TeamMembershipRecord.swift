import CloudKit
import Foundation

/// Team membership record for CloudKit synchronization
///
/// Represents a user's membership in a team with role and quota information.
/// - Record Type: "TeamMembership"
/// - Queryable by: teamID, userID
/// - References: Team record (parent)
/// - Zone: TeamCollaborationZone (custom zone)
public struct TeamMembershipRecord: SyncableRecord {
    public let recordID: String
    public var recordType: String { CloudKitRecordType.teamMembership }
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

    /// Reference to parent team
    public let teamRecordName: String

    public enum TeamRole: String, Codable, Sendable {
        case owner
        case admin
        case member
        case viewer
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
        teamRecordName: String)
    {
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
            recordID: CKRecord.ID(recordName: self.recordID, zoneID: zoneID))

        // Sync metadata
        record["version"] = self.version as CKRecordValue
        record["modifiedAt"] = self.modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = self.lastModifiedDeviceID as? CKRecordValue

        // Membership data
        record["membershipID"] = self.membershipID as CKRecordValue
        record["teamID"] = self.teamID as CKRecordValue
        record["userID"] = self.userID as CKRecordValue
        record["role"] = self.role.rawValue as CKRecordValue
        record["quotaLimit"] = self.quotaLimit as? CKRecordValue
        record["joinedAt"] = self.joinedAt as CKRecordValue
        record["isActive"] = (self.isActive ? 1 : 0) as CKRecordValue

        // Optional encrypted fields
        if let email {
            let encrypted = try teamSyncEncryptString(email)
            record["email"] = encrypted as CKRecordValue
        }
        record["displayName"] = self.displayName as? CKRecordValue
        record["invitedBy"] = self.invitedBy as? CKRecordValue
        record["acceptedAt"] = self.acceptedAt as? CKRecordValue

        // Reference to parent team
        let teamReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: self.teamRecordName, zoneID: zoneID),
            action: .deleteSelf)
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
            email = try? teamSyncDecryptString(encryptedEmail)
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
            teamRecordName: teamReference.recordID.recordName)
    }
}
