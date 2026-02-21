import Foundation

/// Storage for team management, memberships, project ownership, and invitations
public struct TeamStore {
    // MARK: - Types

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
        public var quota: Int // Monthly quota in tokens or cost units
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
            updatedAt: Date = Date()
        ) {
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
        public var quota: Int? // Individual quota override, nil means use team quota
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
            updatedAt: Date = Date()
        ) {
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
        public var id: String { projectID }
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
            updatedAt: Date = Date()
        ) {
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
        public let invitedBy: String // userID
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
            expiresAt: Date = Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            respondedAt: Date? = nil
        ) {
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
            Date() > expiresAt && status == .pending
        }
    }

    public struct TeamsData: Codable {
        public let version: Int
        public var currentUserID: String?
        public var teams: [String: Team] // teamID -> Team
        public var memberships: [String: TeamMembership] // membershipID -> TeamMembership
        public var projectOwnership: [String: ProjectOwnership] // projectID -> ProjectOwnership
        public var invitations: [String: TeamInvitation] // invitationID -> TeamInvitation

        public init(
            version: Int = 1,
            currentUserID: String? = nil,
            teams: [String: Team] = [:],
            memberships: [String: TeamMembership] = [:],
            projectOwnership: [String: ProjectOwnership] = [:],
            invitations: [String: TeamInvitation] = [:]
        ) {
            self.version = version
            self.currentUserID = currentUserID
            self.teams = teams
            self.memberships = memberships
            self.projectOwnership = projectOwnership
            self.invitations = invitations
        }
    }

    // MARK: - Errors

    public enum TeamStoreError: LocalizedError {
        case teamNotFound
        case membershipNotFound
        case projectNotFound
        case invitationNotFound
        case invalidQuota
        case insufficientPermissions
        case duplicateMembership
        case duplicateInvitation
        case invitationExpired
        case ownerCannotLeave
        case invalidEmailFormat
        case teamQuotaExceeded
        case memberQuotaExceeded

        public var errorDescription: String? {
            switch self {
            case .teamNotFound:
                return "Team not found"
            case .membershipNotFound:
                return "Membership not found"
            case .projectNotFound:
                return "Project not found"
            case .invitationNotFound:
                return "Invitation not found"
            case .invalidQuota:
                return "Invalid quota value"
            case .insufficientPermissions:
                return "Insufficient permissions to perform this action"
            case .duplicateMembership:
                return "User is already a member of this team"
            case .duplicateInvitation:
                return "An invitation has already been sent to this email"
            case .invitationExpired:
                return "This invitation has expired"
            case .ownerCannotLeave:
                return "Team owner cannot leave the team. Transfer ownership first."
            case .invalidEmailFormat:
                return "Invalid email format"
            case .teamQuotaExceeded:
                return "Team quota exceeded"
            case .memberQuotaExceeded:
                return "Member quota exceeded"
            }
        }
    }

    // MARK: - Storage Location

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let runicDir = appSupport.appendingPathComponent("Runic", isDirectory: true)
        try? FileManager.default.createDirectory(at: runicDir, withIntermediateDirectories: true)
        return runicDir.appendingPathComponent("teams.json")
    }

    // MARK: - Storage Operations

    public static func load() -> TeamsData {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return TeamsData()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TeamsData.self, from: data)
        } catch {
            print("[TeamStore] Failed to load teams: \(error)")
            return TeamsData()
        }
    }

    public static func save(_ teamsData: TeamsData) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(teamsData)
        try data.write(to: storageURL, options: .atomic)
    }

    // MARK: - Team Management

    public static func createTeam(name: String, ownerUserID: String, quota: Int) throws -> Team {
        guard quota > 0 else {
            throw TeamStoreError.invalidQuota
        }

        var data = load()
        let team = Team(name: name, ownerUserID: ownerUserID, quota: quota)
        data.teams[team.id] = team

        // Automatically add owner as a member with owner role
        let ownerMembership = TeamMembership(
            teamID: team.id,
            userID: ownerUserID,
            role: .owner
        )
        data.memberships[ownerMembership.id] = ownerMembership

        try save(data)
        return team
    }

    public static func getTeam(id: String) -> Team? {
        load().teams[id]
    }

    public static func updateTeam(_ team: Team) throws {
        var data = load()
        guard data.teams[team.id] != nil else {
            throw TeamStoreError.teamNotFound
        }

        var updatedTeam = team
        updatedTeam.updatedAt = Date()
        data.teams[team.id] = updatedTeam
        try save(data)
    }

    public static func deleteTeam(id: String) throws {
        var data = load()
        guard data.teams[id] != nil else {
            throw TeamStoreError.teamNotFound
        }

        // Remove team
        data.teams.removeValue(forKey: id)

        // Remove all memberships
        data.memberships = data.memberships.filter { $0.value.teamID != id }

        // Remove all invitations
        data.invitations = data.invitations.filter { $0.value.teamID != id }

        // Update project ownership (set teamID to nil for projects owned by this team)
        for (projectID, ownership) in data.projectOwnership where ownership.teamID == id {
            var updatedOwnership = ownership
            updatedOwnership.teamID = nil
            updatedOwnership.accessLevel = .private
            updatedOwnership.updatedAt = Date()
            data.projectOwnership[projectID] = updatedOwnership
        }

        try save(data)
    }

    public static func getUserTeams(userID: String) -> [Team] {
        let data = load()
        let userMemberships = data.memberships.values.filter { $0.userID == userID }
        let teamIDs = Set(userMemberships.map { $0.teamID })
        return teamIDs.compactMap { data.teams[$0] }.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Membership Management

    public static func addMember(teamID: String, userID: String, role: TeamRole, quota: Int? = nil) throws -> TeamMembership {
        var data = load()

        guard data.teams[teamID] != nil else {
            throw TeamStoreError.teamNotFound
        }

        // Check for duplicate membership
        let existingMembership = data.memberships.values.first { $0.teamID == teamID && $0.userID == userID }
        if existingMembership != nil {
            throw TeamStoreError.duplicateMembership
        }

        // Validate quota if provided
        if let quota = quota, quota < 0 {
            throw TeamStoreError.invalidQuota
        }

        let membership = TeamMembership(
            teamID: teamID,
            userID: userID,
            role: role,
            quota: quota
        )
        data.memberships[membership.id] = membership

        try save(data)
        return membership
    }

    public static func updateMemberRole(membershipID: String, newRole: TeamRole) throws {
        var data = load()
        guard var membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        // Prevent changing owner role (should use transfer ownership instead)
        if membership.role == .owner && newRole != .owner {
            throw TeamStoreError.insufficientPermissions
        }

        membership.role = newRole
        membership.updatedAt = Date()
        data.memberships[membershipID] = membership

        try save(data)
    }

    public static func updateMemberQuota(membershipID: String, newQuota: Int?) throws {
        var data = load()
        guard var membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        if let quota = newQuota, quota < 0 {
            throw TeamStoreError.invalidQuota
        }

        membership.quota = newQuota
        membership.updatedAt = Date()
        data.memberships[membershipID] = membership

        try save(data)
    }

    public static func removeMember(membershipID: String) throws {
        var data = load()
        guard let membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        // Prevent removing the owner
        if membership.role == .owner {
            throw TeamStoreError.ownerCannotLeave
        }

        data.memberships.removeValue(forKey: membershipID)
        try save(data)
    }

    public static func getTeamMembers(teamID: String) -> [TeamMembership] {
        load().memberships.values
            .filter { $0.teamID == teamID }
            .sorted { $0.joinedAt < $1.joinedAt }
    }

    public static func getUserMembership(teamID: String, userID: String) -> TeamMembership? {
        load().memberships.values.first { $0.teamID == teamID && $0.userID == userID }
    }

    public static func transferOwnership(teamID: String, newOwnerUserID: String) throws {
        var data = load()
        guard var team = data.teams[teamID] else {
            throw TeamStoreError.teamNotFound
        }

        // Get current owner membership
        guard let currentOwnerMembership = data.memberships.values.first(where: { $0.teamID == teamID && $0.userID == team.ownerUserID }) else {
            throw TeamStoreError.membershipNotFound
        }

        // Get new owner membership
        guard let newOwnerMembership = data.memberships.values.first(where: { $0.teamID == teamID && $0.userID == newOwnerUserID }) else {
            throw TeamStoreError.membershipNotFound
        }

        // Update team owner
        team.ownerUserID = newOwnerUserID
        team.updatedAt = Date()
        data.teams[teamID] = team

        // Update memberships
        var updatedCurrentOwner = currentOwnerMembership
        updatedCurrentOwner.role = .admin
        updatedCurrentOwner.updatedAt = Date()
        data.memberships[currentOwnerMembership.id] = updatedCurrentOwner

        var updatedNewOwner = newOwnerMembership
        updatedNewOwner.role = .owner
        updatedNewOwner.updatedAt = Date()
        data.memberships[newOwnerMembership.id] = updatedNewOwner

        try save(data)
    }

    // MARK: - Project Ownership Management

    public static func setProjectOwnership(projectID: String, ownerUserID: String, teamID: String? = nil, accessLevel: AccessLevel) throws {
        var data = load()

        // Validate team exists if provided
        if let teamID = teamID {
            guard data.teams[teamID] != nil else {
                throw TeamStoreError.teamNotFound
            }
        }

        if let existing = data.projectOwnership[projectID] {
            var updated = existing
            updated.ownerUserID = ownerUserID
            updated.teamID = teamID
            updated.accessLevel = accessLevel
            updated.updatedAt = Date()
            data.projectOwnership[projectID] = updated
        } else {
            let ownership = ProjectOwnership(
                projectID: projectID,
                ownerUserID: ownerUserID,
                teamID: teamID,
                accessLevel: accessLevel
            )
            data.projectOwnership[projectID] = ownership
        }

        try save(data)
    }

    public static func shareProject(projectID: String, withUserIDs: [String]) throws {
        var data = load()
        guard var ownership = data.projectOwnership[projectID] else {
            throw TeamStoreError.projectNotFound
        }

        ownership.sharedWithUserIDs = Array(Set(ownership.sharedWithUserIDs + withUserIDs))
        ownership.accessLevel = .shared
        ownership.updatedAt = Date()
        data.projectOwnership[projectID] = ownership

        try save(data)
    }

    public static func unshareProject(projectID: String, withUserIDs: [String]) throws {
        var data = load()
        guard var ownership = data.projectOwnership[projectID] else {
            throw TeamStoreError.projectNotFound
        }

        ownership.sharedWithUserIDs = ownership.sharedWithUserIDs.filter { !withUserIDs.contains($0) }
        ownership.updatedAt = Date()

        // If no users are shared with, revert to private
        if ownership.sharedWithUserIDs.isEmpty && ownership.accessLevel == .shared {
            ownership.accessLevel = .private
        }

        data.projectOwnership[projectID] = ownership
        try save(data)
    }

    public static func getProjectOwnership(projectID: String) -> ProjectOwnership? {
        load().projectOwnership[projectID]
    }

    public static func getUserProjects(userID: String) -> [ProjectOwnership] {
        let data = load()
        return data.projectOwnership.values
            .filter { $0.ownerUserID == userID || $0.sharedWithUserIDs.contains(userID) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public static func getTeamProjects(teamID: String) -> [ProjectOwnership] {
        load().projectOwnership.values
            .filter { $0.teamID == teamID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public static func deleteProjectOwnership(projectID: String) throws {
        var data = load()
        guard data.projectOwnership[projectID] != nil else {
            throw TeamStoreError.projectNotFound
        }

        data.projectOwnership.removeValue(forKey: projectID)
        try save(data)
    }

    // MARK: - Invitation Management

    public static func createInvitation(teamID: String, email: String, role: TeamRole, invitedBy: String) throws -> TeamInvitation {
        var data = load()

        guard data.teams[teamID] != nil else {
            throw TeamStoreError.teamNotFound
        }

        // Validate email format (basic validation)
        guard email.contains("@") && email.contains(".") else {
            throw TeamStoreError.invalidEmailFormat
        }

        // Check for duplicate pending invitation
        let existingInvitation = data.invitations.values.first {
            $0.teamID == teamID && $0.email.lowercased() == email.lowercased() && $0.status == .pending
        }
        if existingInvitation != nil {
            throw TeamStoreError.duplicateInvitation
        }

        let invitation = TeamInvitation(
            teamID: teamID,
            email: email,
            role: role,
            invitedBy: invitedBy
        )
        data.invitations[invitation.id] = invitation

        try save(data)
        return invitation
    }

    public static func acceptInvitation(id: String, userID: String) throws {
        var data = load()
        guard var invitation = data.invitations[id] else {
            throw TeamStoreError.invitationNotFound
        }

        guard invitation.status == .pending else {
            throw TeamStoreError.invitationExpired
        }

        if invitation.isExpired {
            invitation.status = .expired
            invitation.respondedAt = Date()
            data.invitations[id] = invitation
            try save(data)
            throw TeamStoreError.invitationExpired
        }

        // Create membership
        let membership = TeamMembership(
            teamID: invitation.teamID,
            userID: userID,
            role: invitation.role
        )
        data.memberships[membership.id] = membership

        // Update invitation status
        invitation.status = .accepted
        invitation.respondedAt = Date()
        data.invitations[id] = invitation

        try save(data)
    }

    public static func declineInvitation(id: String) throws {
        var data = load()
        guard var invitation = data.invitations[id] else {
            throw TeamStoreError.invitationNotFound
        }

        invitation.status = .declined
        invitation.respondedAt = Date()
        data.invitations[id] = invitation

        try save(data)
    }

    public static func cancelInvitation(id: String) throws {
        var data = load()
        guard data.invitations[id] != nil else {
            throw TeamStoreError.invitationNotFound
        }

        data.invitations.removeValue(forKey: id)
        try save(data)
    }

    public static func getPendingInvitations(email: String) -> [TeamInvitation] {
        load().invitations.values
            .filter { $0.email.lowercased() == email.lowercased() && $0.status == .pending && !$0.isExpired }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public static func getTeamInvitations(teamID: String) -> [TeamInvitation] {
        load().invitations.values
            .filter { $0.teamID == teamID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public static func cleanupExpiredInvitations() throws {
        var data = load()
        let expiredIDs = data.invitations.filter { $0.value.isExpired }.map { $0.key }

        for id in expiredIDs {
            data.invitations[id]?.status = .expired
            data.invitations[id]?.respondedAt = Date()
        }

        try save(data)
    }

    // MARK: - Current User Management

    public static func setCurrentUser(userID: String) throws {
        var data = load()
        data.currentUserID = userID
        try save(data)
    }

    public static func getCurrentUser() -> String? {
        load().currentUserID
    }

    // MARK: - Usage Tracking

    public static func incrementTeamUsage(teamID: String, amount: Int) throws {
        guard amount >= 0 else {
            throw TeamStoreError.invalidQuota
        }

        var data = load()
        guard var team = data.teams[teamID] else {
            throw TeamStoreError.teamNotFound
        }

        team.usedQuota += amount
        team.updatedAt = Date()

        if team.usedQuota > team.quota {
            data.teams[teamID] = team
            try save(data)
            throw TeamStoreError.teamQuotaExceeded
        }

        data.teams[teamID] = team
        try save(data)
    }

    public static func incrementMemberUsage(membershipID: String, amount: Int) throws {
        guard amount >= 0 else {
            throw TeamStoreError.invalidQuota
        }

        var data = load()
        guard var membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        membership.usedQuota += amount
        membership.updatedAt = Date()

        // Check individual quota if set
        if let quota = membership.quota, membership.usedQuota > quota {
            data.memberships[membershipID] = membership
            try save(data)
            throw TeamStoreError.memberQuotaExceeded
        }

        data.memberships[membershipID] = membership
        try save(data)
    }

    public static func resetTeamUsage(teamID: String) throws {
        var data = load()
        guard var team = data.teams[teamID] else {
            throw TeamStoreError.teamNotFound
        }

        team.usedQuota = 0
        team.updatedAt = Date()
        data.teams[teamID] = team

        try save(data)
    }

    public static func resetMemberUsage(membershipID: String) throws {
        var data = load()
        guard var membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        membership.usedQuota = 0
        membership.updatedAt = Date()
        data.memberships[membershipID] = membership

        try save(data)
    }

    public static func resetAllTeamUsages() throws {
        var data = load()

        // Reset all teams
        for (id, var team) in data.teams {
            team.usedQuota = 0
            team.updatedAt = Date()
            data.teams[id] = team
        }

        // Reset all memberships
        for (id, var membership) in data.memberships {
            membership.usedQuota = 0
            membership.updatedAt = Date()
            data.memberships[id] = membership
        }

        try save(data)
    }
}
