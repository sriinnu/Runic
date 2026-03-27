import AppKit
import RunicCore
import SwiftUI

@MainActor
struct TeamManagementView: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var teams: [Team] = []
    @State private var selectedTeam: Team?
    @State private var showingCreateTeam = false
    @State private var showingEditTeam = false
    @State private var showingDeleteConfirmation = false
    @State private var showingInviteSheet = false
    @State private var teamToDelete: Team?
    @State private var newTeamName = ""
    @State private var editTeamName = ""
    @State private var editingMember: TeamMember?
    @State private var editingMemberTeamID: String?
    @State private var memberQuotaHasLimit = false
    @State private var memberQuotaLimit = 10000
    @State private var changingRoleMember: TeamMember?
    @State private var changingRoleTeamID: String?
    @State private var memberRoleSelection: TeamRole = .member
    @State private var showingQuotaSheet = false
    @State private var showingRoleSheet = false
    @State private var dashboardWindow: NSWindow?

    var body: some View {
        PreferencesPane {
            SettingsSection(title: "Teams", contentSpacing: RunicSpacing.md) {
                Text("Manage team workspaces, members, and quota allocation.")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: RunicSpacing.md) {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    HStack {
                        Text("Your Teams")
                            .font(RunicFont.subheadline.weight(.semibold))
                        Spacer()
                        Button {
                            self.showingCreateTeam = true
                        } label: {
                            Label("Create Team", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    if self.teams.isEmpty {
                        VStack(spacing: RunicSpacing.sm) {
                            Image(systemName: "person.3")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            Text("No teams yet")
                                .font(RunicFont.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Create a team to collaborate with others")
                                .font(RunicFont.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RunicSpacing.xl)
                    } else {
                        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                            ForEach(self.teams) { team in
                                TeamRowView(
                                    team: team,
                                    isSelected: self.selectedTeam?.id == team.id,
                                    onSelect: { self.selectedTeam = team },
                                    onEdit: {
                                        self.selectedTeam = team
                                        self.editTeamName = team.name
                                        self.showingEditTeam = true
                                    },
                                    onDelete: {
                                        self.teamToDelete = team
                                        self.showingDeleteConfirmation = true
                                    },
                                    onInvite: {
                                        self.selectedTeam = team
                                        self.showingInviteSheet = true
                                    })
                            }
                        }
                    }
                }
            }

            if let team = self.selectedTeam {
                PreferencesDivider()

                SettingsSection(
                    title: team.name,
                    caption: "\(team.members.count) member\(team.members.count == 1 ? "" : "s")",
                    contentSpacing: RunicSpacing.md)
                {
                    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                        HStack {
                            Text("Members")
                                .font(RunicFont.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                self.showingInviteSheet = true
                            } label: {
                                Label("Invite", systemImage: "person.badge.plus")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }

                        ForEach(team.members) { member in
                            TeamMemberRow(
                                member: member,
                                teamRole: team.role,
                                onEditQuota: { self.editMemberQuota(member: member, in: team) },
                                onChangeRole: { self.changeMemberRole(member: member, in: team) },
                                onRemove: { self.removeMember(member: member, from: team) })
                        }
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                        Text("Team Usage")
                            .font(RunicFont.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Total quota")
                                .font(RunicFont.footnote)
                            Spacer()
                            Text("\(team.totalQuota, format: .number) credits")
                                .font(RunicFont.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Used")
                                .font(RunicFont.footnote)
                            Spacer()
                            Text("\(team.usedQuota, format: .number) credits")
                                .font(RunicFont.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        UsageProgressBar(
                            percent: team.usagePercent,
                            tint: team.usageColor,
                            accessibilityLabel: "Team usage",
                            height: .regular)
                    }
                }
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: RunicSpacing.md) {
                HStack {
                    Spacer()
                    Button("View Team Dashboard") {
                        self.openTeamDashboard()
                    }
                    .buttonStyle(.bordered)
                    .disabled(self.selectedTeam == nil)
                }
            }
        }
        .runicTypography()
        .sheet(isPresented: self.$showingCreateTeam) {
            CreateTeamSheet(
                teamName: self.$newTeamName,
                onCreate: {
                    self.createTeam(name: self.newTeamName)
                    self.showingCreateTeam = false
                    self.newTeamName = ""
                },
                onCancel: {
                    self.showingCreateTeam = false
                    self.newTeamName = ""
                })
        }
        .sheet(isPresented: self.$showingEditTeam) {
            if let team = self.selectedTeam {
                EditTeamSheet(
                    team: team,
                    teamName: self.$editTeamName,
                    onSave: {
                        self.updateTeamName(team: team, newName: self.editTeamName)
                        self.showingEditTeam = false
                    },
                    onCancel: {
                        self.showingEditTeam = false
                    })
            }
        }
        .sheet(isPresented: self.$showingInviteSheet) {
            if let team = self.selectedTeam {
                TeamInviteSheet(
                    team: team,
                    onInvite: { invitation in
                        self.sendInvitation(invitation, to: team)
                        self.showingInviteSheet = false
                    },
                    onCancel: {
                        self.showingInviteSheet = false
                    })
            }
        }
        .sheet(isPresented: self.$showingQuotaSheet) {
            if let member = self.editingMember {
                MemberQuotaSheet(
                    memberName: member.name,
                    hasLimit: self.$memberQuotaHasLimit,
                    quotaLimit: self.$memberQuotaLimit,
                    onSave: {
                        guard let teamID = self.editingMemberTeamID else { return }
                        self.updateMemberQuota(
                            memberID: member.id,
                            teamID: teamID,
                            hasLimit: self.memberQuotaHasLimit,
                            limit: self.memberQuotaLimit)
                        self.showingQuotaSheet = false
                        self.editingMember = nil
                        self.editingMemberTeamID = nil
                    },
                    onCancel: {
                        self.showingQuotaSheet = false
                        self.editingMember = nil
                        self.editingMemberTeamID = nil
                    })
            }
        }
        .sheet(isPresented: self.$showingRoleSheet) {
            if let member = self.changingRoleMember {
                MemberRoleSheet(
                    memberName: member.name,
                    role: self.$memberRoleSelection,
                    onSave: {
                        guard let teamID = self.changingRoleTeamID else { return }
                        self.updateMemberRole(
                            memberID: member.id,
                            teamID: teamID,
                            role: self.memberRoleSelection)
                        self.showingRoleSheet = false
                        self.changingRoleMember = nil
                        self.changingRoleTeamID = nil
                    },
                    onCancel: {
                        self.showingRoleSheet = false
                        self.changingRoleMember = nil
                        self.changingRoleTeamID = nil
                    })
            }
        }
        .alert(
            "Delete Team",
            isPresented: self.$showingDeleteConfirmation,
            actions: {
                Button("Cancel", role: .cancel) {
                    self.teamToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let team = self.teamToDelete {
                        self.deleteTeam(team)
                    }
                    self.teamToDelete = nil
                }
            },
            message: {
                if let team = self.teamToDelete {
                    Text("Are you sure you want to delete \"\(team.name)\"? This action cannot be undone.")
                }
            })
        .onAppear {
            self.loadTeams()
        }
    }

    // MARK: - Actions

    private func loadTeams() {
        self.teams = Self.loadTeamsFromDefaults()
        self.selectedTeam = self.teams.first
    }

    private func createTeam(name: String) {
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

    private func updateTeamName(team: Team, newName: String) {
        if let index = self.teams.firstIndex(where: { $0.id == team.id }) {
            var updated = team
            updated.name = newName
            self.teams[index] = updated
            self.selectedTeam = updated
            self.persistTeams()
        }
    }

    private func deleteTeam(_ team: Team) {
        self.teams.removeAll { $0.id == team.id }
        if self.selectedTeam?.id == team.id {
            self.selectedTeam = self.teams.first
        }
        self.persistTeams()
    }

    private func editMemberQuota(member: TeamMember, in team: Team) {
        self.editingMember = member
        self.editingMemberTeamID = team.id
        self.memberQuotaHasLimit = member.quotaLimit != nil
        self.memberQuotaLimit = member.quotaLimit ?? 10000
        self.showingQuotaSheet = true
    }

    private func changeMemberRole(member: TeamMember, in team: Team) {
        self.changingRoleMember = member
        self.changingRoleTeamID = team.id
        self.memberRoleSelection = member.role
        self.showingRoleSheet = true
    }

    private func removeMember(member: TeamMember, from team: Team) {
        guard let teamIndex = self.teams.firstIndex(where: { $0.id == team.id }) else { return }
        var updated = team
        updated.members.removeAll { $0.id == member.id }
        self.teams[teamIndex] = updated
        self.selectedTeam = updated
        self.persistTeams()
    }

    private func sendInvitation(_ invitation: TeamInvitation, to team: Team) {
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

    private func updateMemberQuota(memberID: String, teamID: String, hasLimit: Bool, limit: Int) {
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

    private func updateMemberRole(memberID: String, teamID: String, role: TeamRole) {
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

    private func openTeamDashboard() {
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

    private func persistTeams() {
        Self.saveTeamsToDefaults(self.teams)
    }

    private static let teamsStorageKey = "runicTeamsStore.v1"

    private static func loadTeamsFromDefaults() -> [Team] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.teamsStorageKey) else { return [] }
        return (try? JSONDecoder().decode([Team].self, from: data)) ?? []
    }

    private static func saveTeamsToDefaults(_ teams: [Team]) {
        let defaults = UserDefaults.standard
        guard let data = try? JSONEncoder().encode(teams) else { return }
        defaults.set(data, forKey: Self.teamsStorageKey)
    }
}

@MainActor
private struct TeamRowView: View {
    let team: Team
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onInvite: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: RunicSpacing.sm) {
            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                HStack(spacing: RunicSpacing.xs) {
                    Image(systemName: self.team.role.icon)
                        .font(RunicFont.body)
                        .foregroundStyle(self.team.role.color)
                    Text(self.team.name)
                        .font(RunicFont.body.weight(.semibold))
                }

                Text(
                    "\(self.team.members.count) member\(self.team.members.count == 1 ? "" : "s") · \(self.team.usedQuota, format: .number) / \(self.team.totalQuota, format: .number) credits")
                    .font(RunicFont.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if self.isHovering || self.isSelected {
                HStack(spacing: RunicSpacing.xxs) {
                    Button {
                        self.onInvite()
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Invite member")

                    Button {
                        self.onEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Edit team")

                    if self.team.role == .owner {
                        Button {
                            self.onDelete()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                        .help("Delete team")
                    }
                }
            }
        }
        .padding(.horizontal, RunicSpacing.sm)
        .padding(.vertical, RunicSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(self.isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.5) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { self.onSelect() }
        .onHover { hovering in self.isHovering = hovering }
    }
}

@MainActor
private struct CreateTeamSheet: View {
    @Binding var teamName: String
    let onCreate: () -> Void
    let onCancel: () -> Void
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            Text("Create Team")
                .font(RunicFont.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Team Name")
                    .font(RunicFont.subheadline.weight(.medium))
                TextField("Enter team name", text: self.$teamName)
                    .textFieldStyle(.roundedBorder)
                    .focused(self.$isNameFieldFocused)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    self.onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    self.onCreate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(self.teamName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RunicSpacing.lg)
        .frame(width: 400)
        .onAppear {
            self.isNameFieldFocused = true
        }
    }
}

@MainActor
private struct EditTeamSheet: View {
    let team: Team
    @Binding var teamName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            Text("Edit Team")
                .font(RunicFont.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Team Name")
                    .font(RunicFont.subheadline.weight(.medium))
                TextField("Enter team name", text: self.$teamName)
                    .textFieldStyle(.roundedBorder)
                    .focused(self.$isNameFieldFocused)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    self.onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    self.onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(self.teamName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RunicSpacing.lg)
        .frame(width: 400)
        .onAppear {
            self.isNameFieldFocused = true
        }
    }
}

@MainActor
private struct MemberQuotaSheet: View {
    let memberName: String
    @Binding var hasLimit: Bool
    @Binding var quotaLimit: Int
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Edit Quota")
                    .font(RunicFont.title2.weight(.semibold))
                Text("Set a monthly quota for \(self.memberName)")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.tertiary)
            }

            PreferencesDivider()

            Toggle("Enable quota limit", isOn: self.$hasLimit)
                .font(RunicFont.subheadline.weight(.medium))

            if self.hasLimit {
                HStack(spacing: RunicSpacing.sm) {
                    Text("Credits")
                        .font(RunicFont.footnote)
                        .foregroundStyle(.secondary)
                    Stepper(value: self.$quotaLimit, in: 1000...1_000_000, step: 1000) {
                        TextField("", value: self.$quotaLimit, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                    }
                }
                Text("Monthly credit allocation for this member")
                    .font(RunicFont.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No limit — uses shared team quota")
                    .font(RunicFont.caption)
                    .foregroundStyle(.tertiary)
            }

            PreferencesDivider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { self.onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { self.onSave() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RunicSpacing.lg)
        .frame(width: 420)
    }
}

@MainActor
private struct MemberRoleSheet: View {
    let memberName: String
    @Binding var role: TeamRole
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Change Role")
                    .font(RunicFont.title2.weight(.semibold))
                Text("Update permissions for \(self.memberName)")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.tertiary)
            }

            PreferencesDivider()

            Picker("Role", selection: self.$role) {
                ForEach(TeamRole.allCases.filter { $0 != .owner }, id: \.self) { role in
                    HStack(spacing: RunicSpacing.xs) {
                        Image(systemName: role.icon)
                        Text(role.displayName)
                    }
                    .tag(role)
                }
            }
            .pickerStyle(.segmented)

            PreferencesDivider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { self.onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { self.onSave() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RunicSpacing.lg)
        .frame(width: 420)
    }
}

// MARK: - Models

struct Team: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var role: TeamRole
    var members: [TeamMember]
    var totalQuota: Int
    var usedQuota: Int

    var usagePercent: Double {
        guard self.totalQuota > 0 else { return 0 }
        return (Double(self.usedQuota) / Double(self.totalQuota)) * 100
    }

    var usageColor: Color {
        let percent = self.usagePercent
        if percent >= 90 { return Color(nsColor: .systemRed) }
        if percent >= 75 { return Color(nsColor: .systemOrange) }
        return Color(nsColor: .systemBlue)
    }
}

enum TeamRole: String, CaseIterable, Codable {
    case owner
    case admin
    case member
    case viewer

    var displayName: String {
        switch self {
        case .owner: "Owner"
        case .admin: "Admin"
        case .member: "Member"
        case .viewer: "Viewer"
        }
    }

    var icon: String {
        switch self {
        case .owner: "crown.fill"
        case .admin: "star.fill"
        case .member: "person.fill"
        case .viewer: "eye.fill"
        }
    }

    var color: Color {
        switch self {
        case .owner: Color(nsColor: .systemYellow)
        case .admin: Color(nsColor: .systemBlue)
        case .member: Color(nsColor: .systemGreen)
        case .viewer: Color(nsColor: .systemGray)
        }
    }

    var canInvite: Bool {
        switch self {
        case .owner, .admin: true
        case .member, .viewer: false
        }
    }

    var canEditQuota: Bool {
        switch self {
        case .owner, .admin: true
        case .member, .viewer: false
        }
    }

    var canRemoveMembers: Bool {
        switch self {
        case .owner, .admin: true
        case .member, .viewer: false
        }
    }
}
