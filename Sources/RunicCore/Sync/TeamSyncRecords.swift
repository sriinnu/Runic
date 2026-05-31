import CloudKit

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
public enum TeamSyncZone {
    public static let zoneName = "TeamCollaborationZone"
    public static let ownerName = CKCurrentUserDefaultName

    public static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
    }

    public static func createZone() -> CKRecordZone {
        CKRecordZone(zoneID: self.zoneID)
    }
}
