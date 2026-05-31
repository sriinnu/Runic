import CloudKit
import Foundation

/// Team usage snapshot record for CloudKit synchronization
///
/// Aggregates usage data across team members for tracking and quota management.
/// - Record Type: "TeamUsageSnapshot"
/// - Queryable by: teamID, date
/// - References: Team record (parent)
/// - Zone: TeamCollaborationZone (custom zone)
public struct TeamUsageSnapshotRecord: SyncableRecord {
    public let recordID: String
    public var recordType: String { CloudKitRecordType.teamUsageSnapshot }
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

    /// Reference to parent team
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
        teamRecordName: String)
    {
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
            recordID: CKRecord.ID(recordName: self.recordID, zoneID: zoneID))

        // Sync metadata
        record["version"] = self.version as CKRecordValue
        record["modifiedAt"] = self.modifiedAt as CKRecordValue
        record["lastModifiedDeviceID"] = self.lastModifiedDeviceID as? CKRecordValue

        // Team usage data
        record["teamID"] = self.teamID as CKRecordValue
        record["date"] = self.date as CKRecordValue
        record["totalTokens"] = self.totalTokens as CKRecordValue
        record["totalCost"] = self.totalCost as CKRecordValue
        record["quotaUsedPercent"] = self.quotaUsedPercent as CKRecordValue

        // Encode member usage as JSON
        let encoder = JSONEncoder()
        let memberUsageData = try encoder.encode(self.memberUsage)
        record["memberUsage"] = String(data: memberUsageData, encoding: .utf8) as? CKRecordValue

        // Optional metrics
        record["primaryProvider"] = self.primaryProvider as? CKRecordValue
        record["mostActiveUser"] = self.mostActiveUser as? CKRecordValue
        record["averageTokensPerMember"] = self.averageTokensPerMember as CKRecordValue

        // Reference to parent team
        let teamReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: self.teamRecordName, zoneID: zoneID),
            action: .deleteSelf)
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
           let data = memberUsageJSON.data(using: .utf8)
        {
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
            teamRecordName: teamReference.recordID.recordName)
    }
}
