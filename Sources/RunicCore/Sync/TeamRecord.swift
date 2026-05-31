import CloudKit
import Foundation

/// Team record for CloudKit synchronization
///
/// Represents a collaborative team that can share usage quotas and projects.
/// - Record Type: "Team"
/// - Queryable by: ownerUserID
/// - Zone: TeamCollaborationZone (custom zone)
public struct TeamRecord: SyncableRecord {
    public let recordID: String
    public var recordType: String { CloudKitRecordType.team }
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
        isActive: Bool = true)
    {
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
            recordID: CKRecord.ID(recordName: self.recordID, zoneID: zoneID))

        // Sync metadata
        record["version"] = self.version as CKRecordValue
        record["modifiedAt"] = self.modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = self.lastModifiedDeviceID as? CKRecordValue

        // Team data
        record["teamID"] = self.teamID as CKRecordValue
        record["name"] = self.name as CKRecordValue
        record["ownerUserID"] = self.ownerUserID as CKRecordValue
        record["totalQuota"] = self.totalQuota as CKRecordValue
        record["createdAt"] = self.createdAt as CKRecordValue
        record["updatedAt"] = self.updatedAt as CKRecordValue
        record["isActive"] = (self.isActive ? 1 : 0) as CKRecordValue

        // Optional fields
        record["description"] = self.description as? CKRecordValue
        record["avatarURL"] = self.avatarURL as? CKRecordValue

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
            isActive: isActiveInt == 1)
    }
}
