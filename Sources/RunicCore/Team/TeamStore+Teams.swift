import Foundation

extension TeamStore {
    public static func createTeam(name: String, ownerUserID: String, quota: Int) throws -> Team {
        guard quota > 0 else {
            throw TeamStoreError.invalidQuota
        }

        var data = self.load()
        let team = Team(name: name, ownerUserID: ownerUserID, quota: quota)
        data.teams[team.id] = team

        let ownerMembership = TeamMembership(
            teamID: team.id,
            userID: ownerUserID,
            role: .owner)
        data.memberships[ownerMembership.id] = ownerMembership

        try self.save(data)
        return team
    }

    public static func getTeam(id: String) -> Team? {
        self.load().teams[id]
    }

    public static func updateTeam(_ team: Team) throws {
        var data = self.load()
        guard data.teams[team.id] != nil else {
            throw TeamStoreError.teamNotFound
        }

        var updatedTeam = team
        updatedTeam.updatedAt = Date()
        data.teams[team.id] = updatedTeam
        try self.save(data)
    }

    public static func deleteTeam(id: String) throws {
        var data = self.load()
        guard data.teams[id] != nil else {
            throw TeamStoreError.teamNotFound
        }

        data.teams.removeValue(forKey: id)
        data.memberships = data.memberships.filter { $0.value.teamID != id }
        data.invitations = data.invitations.filter { $0.value.teamID != id }

        for (projectID, ownership) in data.projectOwnership where ownership.teamID == id {
            var updatedOwnership = ownership
            updatedOwnership.teamID = nil
            updatedOwnership.accessLevel = .private
            updatedOwnership.updatedAt = Date()
            data.projectOwnership[projectID] = updatedOwnership
        }

        try self.save(data)
    }

    public static func getUserTeams(userID: String) -> [Team] {
        let data = self.load()
        let userMemberships = data.memberships.values.filter { $0.userID == userID }
        let teamIDs = Set(userMemberships.map(\.teamID))
        return teamIDs.compactMap { data.teams[$0] }.sorted { $0.createdAt < $1.createdAt }
    }

    public static func addMember(
        teamID: String,
        userID: String,
        role: TeamRole,
        quota: Int? = nil) throws -> TeamMembership
    {
        var data = self.load()

        guard data.teams[teamID] != nil else {
            throw TeamStoreError.teamNotFound
        }

        let existingMembership = data.memberships.values.first { $0.teamID == teamID && $0.userID == userID }
        if existingMembership != nil {
            throw TeamStoreError.duplicateMembership
        }

        if let quota, quota < 0 {
            throw TeamStoreError.invalidQuota
        }

        let membership = TeamMembership(
            teamID: teamID,
            userID: userID,
            role: role,
            quota: quota)
        data.memberships[membership.id] = membership

        try self.save(data)
        return membership
    }

    public static func updateMemberRole(membershipID: String, newRole: TeamRole) throws {
        var data = self.load()
        guard var membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        if membership.role == .owner, newRole != .owner {
            throw TeamStoreError.insufficientPermissions
        }

        membership.role = newRole
        membership.updatedAt = Date()
        data.memberships[membershipID] = membership

        try self.save(data)
    }

    public static func updateMemberQuota(membershipID: String, newQuota: Int?) throws {
        var data = self.load()
        guard var membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        if let quota = newQuota, quota < 0 {
            throw TeamStoreError.invalidQuota
        }

        membership.quota = newQuota
        membership.updatedAt = Date()
        data.memberships[membershipID] = membership

        try self.save(data)
    }

    public static func removeMember(membershipID: String) throws {
        var data = self.load()
        guard let membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        if membership.role == .owner {
            throw TeamStoreError.ownerCannotLeave
        }

        data.memberships.removeValue(forKey: membershipID)
        try self.save(data)
    }

    public static func getTeamMembers(teamID: String) -> [TeamMembership] {
        self.load().memberships.values
            .filter { $0.teamID == teamID }
            .sorted { $0.joinedAt < $1.joinedAt }
    }

    public static func getUserMembership(teamID: String, userID: String) -> TeamMembership? {
        self.load().memberships.values.first { $0.teamID == teamID && $0.userID == userID }
    }

    public static func transferOwnership(teamID: String, newOwnerUserID: String) throws {
        var data = self.load()
        guard var team = data.teams[teamID] else {
            throw TeamStoreError.teamNotFound
        }

        guard let currentOwnerMembership = data.memberships.values
            .first(where: { $0.teamID == teamID && $0.userID == team.ownerUserID })
        else {
            throw TeamStoreError.membershipNotFound
        }

        guard let newOwnerMembership = data.memberships.values
            .first(where: { $0.teamID == teamID && $0.userID == newOwnerUserID })
        else {
            throw TeamStoreError.membershipNotFound
        }

        team.ownerUserID = newOwnerUserID
        team.updatedAt = Date()
        data.teams[teamID] = team

        var updatedCurrentOwner = currentOwnerMembership
        updatedCurrentOwner.role = .admin
        updatedCurrentOwner.updatedAt = Date()
        data.memberships[currentOwnerMembership.id] = updatedCurrentOwner

        var updatedNewOwner = newOwnerMembership
        updatedNewOwner.role = .owner
        updatedNewOwner.updatedAt = Date()
        data.memberships[newOwnerMembership.id] = updatedNewOwner

        try self.save(data)
    }
}
