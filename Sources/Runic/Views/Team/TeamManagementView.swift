import AppKit
import RunicCore
import SwiftUI

@MainActor
struct TeamManagementView: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State var teams: [Team] = []
    @State var selectedTeam: Team?
    @State var showingCreateTeam = false
    @State var showingEditTeam = false
    @State var showingDeleteConfirmation = false
    @State var showingInviteSheet = false
    @State var teamToDelete: Team?
    @State var newTeamName = ""
    @State var editTeamName = ""
    @State var editingMember: TeamMember?
    @State var editingMemberTeamID: String?
    @State var memberQuotaHasLimit = false
    @State var memberQuotaLimit = 10000
    @State var changingRoleMember: TeamMember?
    @State var changingRoleTeamID: String?
    @State var memberRoleSelection: TeamRole = .member
    @State var showingQuotaSheet = false
    @State var showingRoleSheet = false
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
                                .font(self.fonts.footnote.weight(.semibold))
                                .foregroundStyle(self.runicTheme.secondaryText)
                            Spacer()
                            Button {
                                self.showingInviteSheet = true
                            } label: {
                                Label("Add Member", systemImage: "person.badge.plus")
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
}
