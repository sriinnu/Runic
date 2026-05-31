import Foundation

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
        NSPredicate(
            format: "teamID == %@ AND date >= %@ AND date <= %@",
            teamID,
            startDate as NSDate,
            endDate as NSDate)
    }

    /// Creates a predicate to query latest team usage
    public static func latestTeamUsage(_ teamID: String) -> NSPredicate {
        NSPredicate(format: "teamID == %@", teamID)
    }
}

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
