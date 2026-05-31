import AppKit
import RunicCore
import SwiftUI

extension TeamManagementView {
    func loadTeams() {
        self.teams = Self.loadTeamsFromDefaults()
        self.selectedTeam = self.teams.first
    }

    func createTeam(name: String) {
        let email = self.store.codexAccountEmailForOpenAIDashboard()
        let newTeam = Team(
            id: UUID().uuidString,
            name: name,
            role: .owner,
            members: [TeamMember.currentUser(email: email)],
            totalQuota: 100_000,
            usedQuota: 0)
        self.teams.append(newTeam)
        self.selectedTeam = newTeam
        self.persistTeams()
    }

    func updateTeamName(team: Team, newName: String) {
        if let index = self.teams.firstIndex(where: { $0.id == team.id }) {
            var updated = team
            updated.name = newName
            self.teams[index] = updated
            self.selectedTeam = updated
            self.persistTeams()
        }
    }

    func deleteTeam(_ team: Team) {
        self.teams.removeAll { $0.id == team.id }
        if self.selectedTeam?.id == team.id {
            self.selectedTeam = self.teams.first
        }
        self.persistTeams()
    }

    func editMemberQuota(member: TeamMember, in team: Team) {
        self.editingMember = member
        self.editingMemberTeamID = team.id
        self.memberQuotaHasLimit = member.quotaLimit != nil
        self.memberQuotaLimit = member.quotaLimit ?? 10000
        self.showingQuotaSheet = true
    }

    func changeMemberRole(member: TeamMember, in team: Team) {
        self.changingRoleMember = member
        self.changingRoleTeamID = team.id
        self.memberRoleSelection = member.role
        self.showingRoleSheet = true
    }

    func removeMember(member: TeamMember, from team: Team) {
        guard let teamIndex = self.teams.firstIndex(where: { $0.id == team.id }) else { return }
        var updated = team
        updated.members.removeAll { $0.id == member.id }
        self.teams[teamIndex] = updated
        self.selectedTeam = updated
        self.persistTeams()
    }

    func sendInvitation(_ invitation: TeamInvitation, to team: Team) {
        guard let teamIndex = self.teams.firstIndex(where: { $0.id == team.id }) else { return }
        var updated = team
        let memberName = invitation.email.split(separator: "@").first.map(String.init) ?? "New Member"
        let newMember = TeamMember(
            id: UUID().uuidString,
            name: memberName.capitalized,
            email: invitation.email,
            role: invitation.role,
            quotaLimit: invitation.quotaLimit,
            usedQuota: 0,
            isCurrentUser: false)
        updated.members.append(newMember)
        self.teams[teamIndex] = updated
        self.selectedTeam = updated
        self.persistTeams()
    }

    func updateMemberQuota(memberID: String, teamID: String, hasLimit: Bool, limit: Int) {
        guard let teamIndex = self.teams.firstIndex(where: { $0.id == teamID }) else { return }
        var updated = self.teams[teamIndex]
        guard let memberIndex = updated.members.firstIndex(where: { $0.id == memberID }) else { return }
        var member = updated.members[memberIndex]
        member.quotaLimit = hasLimit ? max(1000, limit) : nil
        updated.members[memberIndex] = member
        self.teams[teamIndex] = updated
        self.selectedTeam = updated
        self.persistTeams()
    }

    func updateMemberRole(memberID: String, teamID: String, role: TeamRole) {
        guard let teamIndex = self.teams.firstIndex(where: { $0.id == teamID }) else { return }
        var updated = self.teams[teamIndex]
        guard let memberIndex = updated.members.firstIndex(where: { $0.id == memberID }) else { return }
        var member = updated.members[memberIndex]
        member.role = role
        updated.members[memberIndex] = member
        self.teams[teamIndex] = updated
        self.selectedTeam = updated
        self.persistTeams()
    }

    func openTeamDashboard() {
        guard let team = self.selectedTeam else { return }
        let controller = NSHostingController(rootView: TeamDashboardView(team: team))
        let window = NSWindow(contentViewController: controller)
        window.title = "\(team.name) Dashboard"
        window.setContentSize(NSSize(width: 700, height: 600))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.dashboardWindow = window
    }

    func persistTeams() {
        Self.saveTeamsToDefaults(self.teams)
    }

    private static let teamsStorageKey = "runicTeamsStore.v1"

    static func loadTeamsFromDefaults() -> [Team] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.teamsStorageKey) else { return [] }
        return (try? JSONDecoder().decode([Team].self, from: data)) ?? []
    }

    static func saveTeamsToDefaults(_ teams: [Team]) {
        let defaults = UserDefaults.standard
        guard let data = try? JSONEncoder().encode(teams) else { return }
        defaults.set(data, forKey: Self.teamsStorageKey)
    }
}
