import SwiftUI

@MainActor
struct TeamRowView: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
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
                        .font(self.fonts.body)
                        .foregroundStyle(self.team.role.color)
                    Text(self.team.name)
                        .font(self.fonts.body.weight(.semibold))
                }

                Text(self.teamQuotaSummary)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
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
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(8), style: .continuous)
                .fill(self.isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.5) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { self.onSelect() }
        .onHover { hovering in self.isHovering = hovering }
    }

    private var teamQuotaSummary: String {
        let memberSuffix = self.team.members.count == 1 ? "" : "s"
        let usedQuota = self.team.usedQuota.formatted()
        let totalQuota = self.team.totalQuota.formatted()
        return "\(self.team.members.count) member\(memberSuffix) · " +
            "\(usedQuota) / \(totalQuota) credits"
    }
}
