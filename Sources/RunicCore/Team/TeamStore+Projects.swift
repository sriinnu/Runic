import Foundation

extension TeamStore {
    public static func setProjectOwnership(
        projectID: String,
        ownerUserID: String,
        teamID: String? = nil,
        accessLevel: AccessLevel) throws
    {
        var data = self.load()

        if let teamID {
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
                accessLevel: accessLevel)
            data.projectOwnership[projectID] = ownership
        }

        try self.save(data)
    }

    public static func shareProject(projectID: String, withUserIDs: [String]) throws {
        var data = self.load()
        guard var ownership = data.projectOwnership[projectID] else {
            throw TeamStoreError.projectNotFound
        }

        ownership.sharedWithUserIDs = Array(Set(ownership.sharedWithUserIDs + withUserIDs))
        ownership.accessLevel = .shared
        ownership.updatedAt = Date()
        data.projectOwnership[projectID] = ownership

        try self.save(data)
    }

    public static func unshareProject(projectID: String, withUserIDs: [String]) throws {
        var data = self.load()
        guard var ownership = data.projectOwnership[projectID] else {
            throw TeamStoreError.projectNotFound
        }

        ownership.sharedWithUserIDs = ownership.sharedWithUserIDs.filter { !withUserIDs.contains($0) }
        ownership.updatedAt = Date()

        if ownership.sharedWithUserIDs.isEmpty, ownership.accessLevel == .shared {
            ownership.accessLevel = .private
        }

        data.projectOwnership[projectID] = ownership
        try self.save(data)
    }

    public static func getProjectOwnership(projectID: String) -> ProjectOwnership? {
        self.load().projectOwnership[projectID]
    }

    public static func getUserProjects(userID: String) -> [ProjectOwnership] {
        let data = self.load()
        return data.projectOwnership.values
            .filter { $0.ownerUserID == userID || $0.sharedWithUserIDs.contains(userID) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public static func getTeamProjects(teamID: String) -> [ProjectOwnership] {
        self.load().projectOwnership.values
            .filter { $0.teamID == teamID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public static func deleteProjectOwnership(projectID: String) throws {
        var data = self.load()
        guard data.projectOwnership[projectID] != nil else {
            throw TeamStoreError.projectNotFound
        }

        data.projectOwnership.removeValue(forKey: projectID)
        try self.save(data)
    }
}
