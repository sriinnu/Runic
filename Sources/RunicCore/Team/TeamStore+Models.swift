import Foundation

extension TeamStore {
    public enum TeamRole: String, Codable, Sendable {
        case owner
        case admin
        case member
        case viewer

        public var canManageMembers: Bool {
            self == .owner || self == .admin
        }

        public var canManageProjects: Bool {
            self == .owner || self == .admin
        }

        public var canEditTeam: Bool {
            self == .owner || self == .admin
        }

        public var canDeleteTeam: Bool {
            self == .owner
        }
    }

    public enum AccessLevel: String, Codable, Sendable {
        case `private`
        case team
        case shared
        case `public`
    }

    public enum InvitationStatus: String, Codable, Sendable {
        case pending
        case accepted
        case declined
        case expired
    }

    public struct Team: Codable, Sendable, Identifiable {
        public let id: String
        public var name: String
        public var ownerUserID: String
        public var quota: Int
        public var usedQuota: Int
        public let createdAt: Date
        public var updatedAt: Date

        public init(
            id: String = UUID().uuidString,
            name: String,
            ownerUserID: String,
            quota: Int,
            usedQuota: Int = 0,
            createdAt: Date = Date(),
            updatedAt: Date = Date())
        {
            self.id = id
            self.name = name
            self.ownerUserID = ownerUserID
            self.quota = quota
            self.usedQuota = usedQuota
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    public struct TeamMembership: Codable, Sendable, Identifiable {
        public let id: String
        public let teamID: String
        public let userID: String
        public var role: TeamRole
        public var quota: Int?
        public var usedQuota: Int
        public let joinedAt: Date
        public var updatedAt: Date

        public init(
            id: String = UUID().uuidString,
            teamID: String,
            userID: String,
            role: TeamRole,
            quota: Int? = nil,
            usedQuota: Int = 0,
            joinedAt: Date = Date(),
            updatedAt: Date = Date())
        {
            self.id = id
            self.teamID = teamID
            self.userID = userID
            self.role = role
            self.quota = quota
            self.usedQuota = usedQuota
            self.joinedAt = joinedAt
            self.updatedAt = updatedAt
        }
    }

    public struct ProjectOwnership: Codable, Sendable, Identifiable {
        public var id: String {
            self.projectID
        }

        public let projectID: String
        public var ownerUserID: String
        public var teamID: String?
        public var accessLevel: AccessLevel
        public var sharedWithUserIDs: [String]
        public let createdAt: Date
        public var updatedAt: Date

        public init(
            projectID: String,
            ownerUserID: String,
            teamID: String? = nil,
            accessLevel: AccessLevel = .private,
            sharedWithUserIDs: [String] = [],
            createdAt: Date = Date(),
            updatedAt: Date = Date())
        {
            self.projectID = projectID
            self.ownerUserID = ownerUserID
            self.teamID = teamID
            self.accessLevel = accessLevel
            self.sharedWithUserIDs = sharedWithUserIDs
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    public struct TeamInvitation: Codable, Sendable, Identifiable {
        public let id: String
        public let teamID: String
        public let email: String
        public var role: TeamRole
        public let invitedBy: String
        public var status: InvitationStatus
        public let createdAt: Date
        public var expiresAt: Date
        public var respondedAt: Date?

        public init(
            id: String = UUID().uuidString,
            teamID: String,
            email: String,
            role: TeamRole,
            invitedBy: String,
            status: InvitationStatus = .pending,
            createdAt: Date = Date(),
            expiresAt: Date = Date().addingTimeInterval(7 * 24 * 60 * 60),
            respondedAt: Date? = nil)
        {
            self.id = id
            self.teamID = teamID
            self.email = email
            self.role = role
            self.invitedBy = invitedBy
            self.status = status
            self.createdAt = createdAt
            self.expiresAt = expiresAt
            self.respondedAt = respondedAt
        }

        public var isExpired: Bool {
            Date() > self.expiresAt && self.status == .pending
        }
    }

    public struct TeamsData: Codable {
        public let version: Int
        public var currentUserID: String?
        public var teams: [String: Team]
        public var memberships: [String: TeamMembership]
        public var projectOwnership: [String: ProjectOwnership]
        public var invitations: [String: TeamInvitation]

        public init(
            version: Int = 1,
            currentUserID: String? = nil,
            teams: [String: Team] = [:],
            memberships: [String: TeamMembership] = [:],
            projectOwnership: [String: ProjectOwnership] = [:],
            invitations: [String: TeamInvitation] = [:])
        {
            self.version = version
            self.currentUserID = currentUserID
            self.teams = teams
            self.memberships = memberships
            self.projectOwnership = projectOwnership
            self.invitations = invitations
        }
    }
}
