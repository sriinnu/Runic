import SwiftUI

@MainActor
struct CreateTeamSheet: View {
    @Environment(\.runicFonts) private var fonts
    @Binding var teamName: String
    let onCreate: () -> Void
    let onCancel: () -> Void
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            Text("Create Team")
                .font(self.fonts.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Team Name")
                    .font(self.fonts.subheadline.weight(.medium))
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
struct EditTeamSheet: View {
    @Environment(\.runicFonts) private var fonts
    let team: Team
    @Binding var teamName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            Text("Edit Team")
                .font(self.fonts.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Team Name")
                    .font(self.fonts.subheadline.weight(.medium))
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
struct MemberQuotaSheet: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let memberName: String
    @Binding var hasLimit: Bool
    @Binding var quotaLimit: Int
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Edit Quota")
                    .font(self.fonts.title2.weight(.semibold))
                Text("Set a monthly quota for \(self.memberName)")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
            }

            PreferencesDivider()

            Toggle("Enable quota limit", isOn: self.$hasLimit)
                .font(self.fonts.subheadline.weight(.medium))

            if self.hasLimit {
                HStack(spacing: RunicSpacing.sm) {
                    Text("Credits")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Stepper(value: self.$quotaLimit, in: 1000...1_000_000, step: 1000) {
                        TextField("", value: self.$quotaLimit, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                    }
                }
                Text("Monthly credit allocation for this member")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
            } else {
                Text("No limit — uses shared team quota")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
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
struct MemberRoleSheet: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let memberName: String
    @Binding var role: TeamRole
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Change Role")
                    .font(self.fonts.title2.weight(.semibold))
                Text("Update permissions for \(self.memberName)")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
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
