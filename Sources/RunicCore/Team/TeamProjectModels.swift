import Foundation

// MARK: - ProjectOwnership

/// Defines ownership and sharing settings for a project
public struct ProjectOwnership: Codable, Sendable, Identifiable {
    public let id: String
    public let projectID: String
    public let teamID: String?
    public let ownerUserID: String
    public var sharedWith: [String] // User IDs
    public var accessLevel: AccessLevel
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        projectID: String,
        teamID: String? = nil,
        ownerUserID: String,
        sharedWith: [String] = [],
        accessLevel: AccessLevel = .privateAccess,
        createdAt: Date = Date())
    {
        self.id = id
        self.projectID = projectID
        self.teamID = teamID
        self.ownerUserID = ownerUserID
        self.sharedWith = sharedWith
        self.accessLevel = accessLevel
        self.createdAt = createdAt
    }
}

extension ProjectOwnership {
    /// Check if a user has access to this project
    public func hasAccess(userID: String) -> Bool {
        // Owner always has access
        if userID == self.ownerUserID {
            return true
        }

        // Check access level
        switch self.accessLevel {
        case .privateAccess:
            return self.sharedWith.contains(userID)
        case .team:
            // User must be in the team
            return self.teamID != nil
        case .public:
            return true
        }
    }

    /// Check if a user can edit this project
    public func canEdit(userID: String) -> Bool {
        userID == self.ownerUserID || self.sharedWith.contains(userID)
    }

    /// Add a user to the shared list
    public mutating func share(with userID: String) {
        if !self.sharedWith.contains(userID) {
            self.sharedWith.append(userID)
        }
    }

    /// Remove a user from the shared list
    public mutating func unshare(with userID: String) {
        self.sharedWith.removeAll { $0 == userID }
    }

    /// Check if project is owned by a team
    public var isTeamOwned: Bool {
        self.teamID != nil
    }
}

// MARK: - AccessLevel

/// Defines who can access a project
public enum AccessLevel: String, Codable, Sendable, CaseIterable {
    case privateAccess = "private" // Only owner and explicitly shared users
    case team // All team members
    case `public` // Anyone with link

    /// Display name for the access level
    public var displayName: String {
        switch self {
        case .privateAccess: "Private"
        case .team: "Team"
        case .public: "Public"
        }
    }

    /// Icon representing the access level
    public var icon: String {
        switch self {
        case .privateAccess: "lock.fill"
        case .team: "person.2.fill"
        case .public: "globe"
        }
    }

    /// Description of access level
    public var description: String {
        switch self {
        case .privateAccess:
            "Only you and people you share with"
        case .team:
            "All team members can access"
        case .public:
            "Anyone with the link can view"
        }
    }
}
