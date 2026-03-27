import AppKit
import SwiftUI

@MainActor
struct TeamMemberRow: View {
    let member: TeamMember
    let teamRole: TeamRole
    let onEditQuota: () -> Void
    let onChangeRole: () -> Void
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: RunicSpacing.sm) {
            self.avatarView

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                HStack(spacing: RunicSpacing.xs) {
                    Text(self.member.name)
                        .font(RunicFont.body.weight(.medium))

                    self.roleBadge
                }

                Text(self.member.email)
                    .font(RunicFont.caption)
                    .foregroundStyle(.tertiary)

                if let quota = self.member.quotaLimit {
                    HStack(spacing: RunicSpacing.xxs) {
                        Text("\(self.member.usedQuota, format: .number) / \(quota, format: .number)")
                            .font(RunicFont.caption2)
                            .foregroundStyle(.secondary)

                        UsageProgressBar(
                            percent: self.member.quotaUsagePercent,
                            tint: self.quotaColor,
                            accessibilityLabel: "\(self.member.name) quota usage",
                            height: .compact)
                            .frame(maxWidth: 120)
                    }
                }
            }

            Spacer()

            if self.isHovering, self.canModify {
                HStack(spacing: RunicSpacing.xxxs) {
                    if self.teamRole.canEditQuota {
                        Button {
                            self.onEditQuota()
                        } label: {
                            Image(systemName: "chart.bar.fill")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Edit quota")
                    }

                    if self.teamRole.canRemoveMembers, !self.member.isCurrentUser {
                        Button {
                            self.onChangeRole()
                        } label: {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Change role")

                        Button {
                            self.onRemove()
                        } label: {
                            Image(systemName: "person.crop.circle.badge.minus")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                        .help("Remove member")
                    }
                }
            }
        }
        .padding(.horizontal, RunicSpacing.sm)
        .padding(.vertical, RunicSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(self.isHovering ? Color(nsColor: .controlBackgroundColor) : Color.clear))
        .onHover { hovering in self.isHovering = hovering }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(self.member.avatarColor)
                .frame(width: 36, height: 36)

            Text(self.member.initials)
                .font(RunicFont.footnote.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var roleBadge: some View {
        HStack(spacing: RunicSpacing.xxxs) {
            Image(systemName: self.member.role.icon)
                .font(RunicFont.caption2)
            Text(self.member.role.displayName)
                .font(RunicFont.caption2.weight(.medium))
        }
        .padding(.horizontal, RunicSpacing.xxs + RunicSpacing.xxxs)
        .padding(.vertical, RunicSpacing.xxxs)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(self.member.role.color.opacity(0.15)))
        .foregroundStyle(self.member.role.color)
    }

    private var quotaColor: Color {
        let percent = self.member.quotaUsagePercent
        if percent >= 90 { return Color(nsColor: .systemRed) }
        if percent >= 75 { return Color(nsColor: .systemOrange) }
        return Color(nsColor: .systemBlue)
    }

    private var canModify: Bool {
        self.teamRole.canEditQuota || self.teamRole.canRemoveMembers
    }
}

// MARK: - Models

struct TeamMember: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let email: String
    var role: TeamRole
    var quotaLimit: Int?
    var usedQuota: Int
    let isCurrentUser: Bool

    var initials: String {
        let components = self.name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
        return String(self.name.prefix(2)).uppercased()
    }

    var avatarColor: Color {
        let colors: [Color] = [
            Color(red: 0.26, green: 0.55, blue: 0.96),
            Color(red: 0.46, green: 0.75, blue: 0.36),
            Color(red: 0.94, green: 0.53, blue: 0.18),
            Color(red: 0.80, green: 0.45, blue: 0.92),
            Color(red: 0.26, green: 0.78, blue: 0.86),
        ]
        let index = abs(self.id.hashValue) % colors.count
        return colors[index]
    }

    var quotaUsagePercent: Double {
        guard let limit = self.quotaLimit, limit > 0 else { return 0 }
        return (Double(self.usedQuota) / Double(limit)) * 100
    }

    static func currentUser(email: String?) -> TeamMember {
        let resolvedEmail = (email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            ? "you@example.com"
            : (email ?? "you@example.com")
        return TeamMember(
            id: "current",
            name: "You",
            email: resolvedEmail,
            role: .owner,
            quotaLimit: 50000,
            usedQuota: 12500,
            isCurrentUser: true)
    }
}
