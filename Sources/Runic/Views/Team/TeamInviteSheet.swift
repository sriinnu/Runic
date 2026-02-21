import AppKit
import SwiftUI

@MainActor
struct TeamInviteSheet: View {
    let team: Team
    let onInvite: (TeamInvitation) -> Void
    let onCancel: () -> Void

    @State private var email = ""
    @State private var selectedRole: TeamRole = .member
    @State private var hasQuotaLimit = false
    @State private var quotaLimit = 10_000
    @State private var emailError: String?
    @FocusState private var isEmailFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Invite to \(self.team.name)")
                    .font(.title2.weight(.semibold))
                Text("Send an invitation to join your team")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            PreferencesDivider()

            VStack(alignment: .leading, spacing: RunicSpacing.md) {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Email Address")
                        .font(.subheadline.weight(.medium))

                    TextField("colleague@example.com", text: self.$email)
                        .textFieldStyle(.roundedBorder)
                        .focused(self.$isEmailFieldFocused)
                        .onChange(of: self.email) { _, _ in
                            self.emailError = nil
                        }

                    if let error = self.emailError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("They will receive an email invitation")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Role")
                        .font(.subheadline.weight(.medium))

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
                        .font(.subheadline.weight(.medium))

                    if self.hasQuotaLimit {
                        HStack(spacing: RunicSpacing.sm) {
                            Text("Credits")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Stepper(
                                value: self.$quotaLimit,
                                in: 1_000...1_000_000,
                                step: 1_000)
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
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("No quota limit - uses shared team quota")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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
        .font(.caption)
        .foregroundStyle(.tertiary)
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
