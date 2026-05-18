import AppKit
import SwiftUI

@MainActor
struct TeamInviteSheet: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let team: Team
    let onInvite: (TeamInvitation) -> Void
    let onCancel: () -> Void

    @State private var email = ""
    @State private var selectedRole: TeamRole = .member
    @State private var hasQuotaLimit = false
    @State private var quotaLimit = 10000
    @State private var emailError: String?
    @FocusState private var isEmailFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Invite to \(self.team.name)")
                    .font(self.fonts.title2.weight(.semibold))
                Text("Send an invitation to join your team")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
            }

            PreferencesDivider()

            VStack(alignment: .leading, spacing: RunicSpacing.md) {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Email Address")
                        .font(self.fonts.subheadline.weight(.medium))

                    TextField("colleague@example.com", text: self.$email)
                        .textFieldStyle(.roundedBorder)
                        .focused(self.$isEmailFieldFocused)
                        .onChange(of: self.email) { _, _ in
                            self.emailError = nil
                        }

                    if let error = self.emailError {
                        Text(error)
                            .font(self.fonts.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("They will receive an email invitation")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                    }
                }

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Role")
                        .font(self.fonts.subheadline.weight(.medium))

                    Picker("Role", selection: self.$selectedRole) {
                        ForEach(TeamRole.allCases.filter { $0 != .owner }, id: \.self) { role in
                            HStack(spacing: RunicSpacing.xs) {
                                Image(systemName: role.icon)
                                Text(role.displayName)
                            }
                            .tag(role)
                        }
                    }
                    .pickerStyle(.segmented)

                    self.roleDescription
                }

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Toggle("Set quota limit", isOn: self.$hasQuotaLimit)
                        .font(self.fonts.subheadline.weight(.medium))

                    if self.hasQuotaLimit {
                        HStack(spacing: RunicSpacing.sm) {
                            Text("Credits")
                                .font(self.fonts.footnote)
                                .foregroundStyle(self.runicTheme.secondaryText)

                            Stepper(
                                value: self.$quotaLimit,
                                in: 1000...1_000_000,
                                step: 1000)
                            {
                                TextField(
                                    "",
                                    value: self.$quotaLimit,
                                    format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }

                        Text("Monthly credit allocation for this member")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                    } else {
                        Text("No quota limit - uses shared team quota")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                    }
                }
            }

            PreferencesDivider()

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    self.onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Send Invitation") {
                    self.sendInvitation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!self.isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RunicSpacing.lg)
        .frame(width: 480)
        .onAppear {
            self.isEmailFieldFocused = true
        }
    }

    private var roleDescription: some View {
        Group {
            switch self.selectedRole {
            case .admin:
                Text("Can invite members, manage quotas, and view all usage")
            case .member:
                Text("Can use the team workspace and view own usage")
            case .viewer:
                Text("Read-only access to team usage and reports")
            case .owner:
                Text("")
            }
        }
        .font(self.fonts.caption)
        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var isValid: Bool {
        !self.email.trimmingCharacters(in: .whitespaces).isEmpty &&
            self.email.contains("@") &&
            self.email.contains(".")
    }

    private func sendInvitation() {
        guard self.isValid else {
            self.emailError = "Please enter a valid email address"
            return
        }

        let invitation = TeamInvitation(
            email: self.email.trimmingCharacters(in: .whitespaces),
            role: self.selectedRole,
            quotaLimit: self.hasQuotaLimit ? self.quotaLimit : nil)

        self.onInvite(invitation)
    }
}

// MARK: - Models

struct TeamInvitation {
    let email: String
    let role: TeamRole
    let quotaLimit: Int?
}
