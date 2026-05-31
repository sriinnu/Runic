import Foundation

extension TeamStore {
    public static func incrementTeamUsage(teamID: String, amount: Int) throws {
        guard amount >= 0 else {
            throw TeamStoreError.invalidQuota
        }

        var data = self.load()
        guard var team = data.teams[teamID] else {
            throw TeamStoreError.teamNotFound
        }

        team.usedQuota += amount
        team.updatedAt = Date()

        if team.usedQuota > team.quota {
            data.teams[teamID] = team
            try self.save(data)
            throw TeamStoreError.teamQuotaExceeded
        }

        data.teams[teamID] = team
        try self.save(data)
    }

    public static func incrementMemberUsage(membershipID: String, amount: Int) throws {
        guard amount >= 0 else {
            throw TeamStoreError.invalidQuota
        }

        var data = self.load()
        guard var membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        membership.usedQuota += amount
        membership.updatedAt = Date()

        if let quota = membership.quota, membership.usedQuota > quota {
            data.memberships[membershipID] = membership
            try self.save(data)
            throw TeamStoreError.memberQuotaExceeded
        }

        data.memberships[membershipID] = membership
        try self.save(data)
    }

    public static func resetTeamUsage(teamID: String) throws {
        var data = self.load()
        guard var team = data.teams[teamID] else {
            throw TeamStoreError.teamNotFound
        }

        team.usedQuota = 0
        team.updatedAt = Date()
        data.teams[teamID] = team

        try self.save(data)
    }

    public static func resetMemberUsage(membershipID: String) throws {
        var data = self.load()
        guard var membership = data.memberships[membershipID] else {
            throw TeamStoreError.membershipNotFound
        }

        membership.usedQuota = 0
        membership.updatedAt = Date()
        data.memberships[membershipID] = membership

        try self.save(data)
    }

    public static func resetAllTeamUsages() throws {
        var data = self.load()

        for (id, var team) in data.teams {
            team.usedQuota = 0
            team.updatedAt = Date()
            data.teams[id] = team
        }

        for (id, var membership) in data.memberships {
            membership.usedQuota = 0
            membership.updatedAt = Date()
            data.memberships[id] = membership
        }

        try self.save(data)
    }
}
