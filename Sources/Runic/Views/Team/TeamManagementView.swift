import AppKit
import RunicCore
import SwiftUI

@MainActor
struct TeamManagementView: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    enum TeamSheet: Identifiable {
        case createTeam
        case editTeam(Team)
        case invite(Team)
        case quota(member: TeamMember, teamID: String)
        case role(member: TeamMember, teamID: String)

        var id: String {
            switch self {
            case .createTeam: "create"
            case let .editTeam(team): "edit-\(team.id)"
            case let .invite(team): "invite-\(team.id)"
            case let .quota(member, teamID): "quota-\(teamID)-\(member.id)"
            case let .role(member, teamID): "role-\(teamID)-\(member.id)"
            }
        }
    }

    @State var teams: [Team] = []
    @State var selectedTeam: Team?
    @State var activeSheet: TeamSheet?
    @State var showingDeleteConfirmation = false
    @State var teamToDelete: Team?
    @State var newTeamName = ""
    @State var editTeamName = ""
    @State var memberQuotaHasLimit = false
    @State var memberQuotaLimit = 10000
    @State var memberRoleSelection: TeamRole = .member
    @State var dashboardWindow: NSWindow?

    var body: some View {
        PreferencesPane {
            SettingsSection(title: "Local Teams", contentSpacing: RunicSpacing.md) {
                Text(
                    "Sketch local member and quota plans on this Mac. " +
                        "These plans do not sync or feed showback exports yet.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: RunicSpacing.md) {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    HStack {
                        Text("Your Teams")
                            .font(self.fonts.subheadline.weight(.semibold))
                        Spacer()
                        Button {
                            self.activeSheet = .createTeam
                        } label: {
                            Label("Create Team", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.runicProminent)
                        .controlSize(.small)
                    }

                    if self.teams.isEmpty {
                        VStack(spacing: RunicSpacing.sm) {
                            Image(systemName: "person.3")
                                .font(.system(size: 48))
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                            Text("No teams yet")
                                .font(self.fonts.body.weight(.semibold))
                                .foregroundStyle(self.runicTheme.secondaryText)
                            Text("Create a local planning group for quota what-ifs")
                                .font(self.fonts.footnote)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
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
                                        self.activeSheet = .editTeam(team)
                                    },
                                    onDelete: {
                                        self.teamToDelete = team
                                        self.showingDeleteConfirmation = true
                                    },
                                    onInvite: {
                                        self.selectedTeam = team
                                        self.activeSheet = .invite(team)
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
                                .font(self.fonts.footnote.weight(.semibold))
                                .foregroundStyle(self.runicTheme.secondaryText)
                            Spacer()
                            Button {
                                self.activeSheet = .invite(team)
                            } label: {
                                Label("Add Member", systemImage: "person.badge.plus")
                            }
                            .buttonStyle(.runicBordered)
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
                            .font(self.fonts.footnote.weight(.semibold))
                            .foregroundStyle(self.runicTheme.secondaryText)

                        HStack {
                            Text("Total quota")
                                .font(self.fonts.footnote)
                            Spacer()
                            Text("\(team.totalQuota, format: .number) credits")
                                .font(self.fonts.footnote.weight(.semibold))
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }

                        HStack {
                            Text("Used")
                                .font(self.fonts.footnote)
                            Spacer()
                            Text("\(team.usedQuota, format: .number) credits")
                                .font(self.fonts.footnote.weight(.semibold))
                                .foregroundStyle(self.runicTheme.secondaryText)
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
                    Button("View Local Plan") {
                        self.openTeamDashboard()
                    }
                    .buttonStyle(.bordered)
                    .disabled(self.selectedTeam == nil)
                }
            }
        }
        .runicTypography()
        .sheet(item: self.$activeSheet) { sheet in
            switch sheet {
            case .createTeam:
                CreateTeamSheet(
                    teamName: self.$newTeamName,
                    onCreate: {
                        self.createTeam(name: self.newTeamName)
                        self.activeSheet = nil
                        self.newTeamName = ""
                    },
                    onCancel: {
                        self.activeSheet = nil
                        self.newTeamName = ""
                    })
            case let .editTeam(team):
                EditTeamSheet(
                    team: team,
                    teamName: self.$editTeamName,
                    onSave: {
                        self.updateTeamName(team: team, newName: self.editTeamName)
                        self.activeSheet = nil
                    },
                    onCancel: {
                        self.activeSheet = nil
                    })
            case let .invite(team):
                TeamInviteSheet(
                    team: team,
                    onInvite: { invitation in
                        self.sendInvitation(invitation, to: team)
                        self.activeSheet = nil
                    },
                    onCancel: {
                        self.activeSheet = nil
                    })
            case let .quota(member, teamID):
                MemberQuotaSheet(
                    memberName: member.name,
                    hasLimit: self.$memberQuotaHasLimit,
                    quotaLimit: self.$memberQuotaLimit,
                    onSave: {
                        self.updateMemberQuota(
                            memberID: member.id,
                            teamID: teamID,
                            hasLimit: self.memberQuotaHasLimit,
                            limit: self.memberQuotaLimit)
                        self.activeSheet = nil
                    },
                    onCancel: {
                        self.activeSheet = nil
                    })
            case let .role(member, teamID):
                MemberRoleSheet(
                    memberName: member.name,
                    role: self.$memberRoleSelection,
                    onSave: {
                        self.updateMemberRole(
                            memberID: member.id,
                            teamID: teamID,
                            role: self.memberRoleSelection)
                        self.activeSheet = nil
                    },
                    onCancel: {
                        self.activeSheet = nil
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
}
