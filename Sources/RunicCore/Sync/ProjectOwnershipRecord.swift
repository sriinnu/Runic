import CloudKit
import Foundation

/// Project ownership record for CloudKit synchronization
///
/// Represents ownership and sharing permissions for a project.
/// - Record Type: "ProjectOwnership"
/// - Queryable by: ownerUserID, teamID, projectID
/// - References: Team record (optional - if team-owned)
/// - Zone: TeamCollaborationZone (custom zone)
public struct ProjectOwnershipRecord: SyncableRecord {
    public let recordID: String
    public var recordType: String { CloudKitRecordType.projectOwnership }
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

    /// Reference to team (if team-owned)
    public let teamRecordName: String?

    public enum AccessLevel: String, Codable, Sendable {
        case `private`
        case teamReadOnly = "team_read_only"
        case teamReadWrite = "team_read_write"
        case `public`
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
        teamRecordName: String? = nil)
    {
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
            recordID: CKRecord.ID(recordName: self.recordID, zoneID: zoneID))

        // Sync metadata
        record["version"] = self.version as CKRecordValue
        record["modifiedAt"] = self.modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = self.lastModifiedDeviceID as? CKRecordValue

        // Project ownership data
        record["projectID"] = self.projectID as CKRecordValue
        record["teamID"] = self.teamID as? CKRecordValue
        record["ownerUserID"] = self.ownerUserID as CKRecordValue
        record["sharedWith"] = self.sharedWith as CKRecordValue
        record["accessLevel"] = self.accessLevel.rawValue as CKRecordValue
        record["createdAt"] = self.createdAt as CKRecordValue
        record["isArchived"] = (self.isArchived ? 1 : 0) as CKRecordValue

        // Optional metadata
        record["projectName"] = self.projectName as? CKRecordValue
        record["projectDescription"] = self.projectDescription as? CKRecordValue
        record["tags"] = self.tags as CKRecordValue

        // Reference to team (if team-owned)
        if let teamRecordName {
            let teamReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: teamRecordName, zoneID: zoneID),
                action: .none)
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
            teamRecordName: teamReference?.recordID.recordName)
    }
}
