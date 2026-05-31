import Foundation

extension TeamStore {
    public static func createInvitation(
        teamID: String,
        email: String,
        role: TeamRole,
        invitedBy: String) throws -> TeamInvitation
    {
        var data = self.load()

        guard data.teams[teamID] != nil else {
            throw TeamStoreError.teamNotFound
        }

        guard email.contains("@"), email.contains(".") else {
            throw TeamStoreError.invalidEmailFormat
        }

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
            invitedBy: invitedBy)
        data.invitations[invitation.id] = invitation

        try self.save(data)
        return invitation
    }

    public static func acceptInvitation(id: String, userID: String) throws {
        var data = self.load()
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
            try self.save(data)
            throw TeamStoreError.invitationExpired
        }

        let membership = TeamMembership(
            teamID: invitation.teamID,
            userID: userID,
            role: invitation.role)
        data.memberships[membership.id] = membership

        invitation.status = .accepted
        invitation.respondedAt = Date()
        data.invitations[id] = invitation

        try self.save(data)
    }

    public static func declineInvitation(id: String) throws {
        var data = self.load()
        guard var invitation = data.invitations[id] else {
            throw TeamStoreError.invitationNotFound
        }

        invitation.status = .declined
        invitation.respondedAt = Date()
        data.invitations[id] = invitation

        try self.save(data)
    }

    public static func cancelInvitation(id: String) throws {
        var data = self.load()
        guard data.invitations[id] != nil else {
            throw TeamStoreError.invitationNotFound
        }

        data.invitations.removeValue(forKey: id)
        try self.save(data)
    }

    public static func getPendingInvitations(email: String) -> [TeamInvitation] {
        self.load().invitations.values
            .filter { $0.email.lowercased() == email.lowercased() && $0.status == .pending && !$0.isExpired }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public static func getTeamInvitations(teamID: String) -> [TeamInvitation] {
        self.load().invitations.values
            .filter { $0.teamID == teamID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public static func cleanupExpiredInvitations() throws {
        var data = self.load()
        let expiredIDs = data.invitations.filter(\.value.isExpired).map(\.key)

        for id in expiredIDs {
            data.invitations[id]?.status = .expired
            data.invitations[id]?.respondedAt = Date()
        }

        try self.save(data)
    }
}
