import AppKit
import RunicCore
import SwiftUI

// MARK: - Sidebar layout views

@MainActor
struct ProviderSidebarRow: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider
    @Bindable var store: UsageStore
    let isEnabled: Bool
    let isSelected: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
            if let brand = ProviderBrandIcon.image(for: self.provider, size: 22) {
                Image(nsImage: brand)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .opacity(self.isEnabled ? 1 : 0.48)
            } else {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 16))
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                    .frame(width: 22, height: 22)
            }
            Text(self.store.metadata(for: self.provider).displayName)
                .font(self.fonts.body)
                .foregroundStyle(self.isEnabled ? .primary : .secondary)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .fill(self.isSelected ? Color.accentColor.opacity(0.14) : .clear))
        .overlay(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .stroke(
                    self.isSelected ? Color.accentColor.opacity(0.45) : Color.clear,
                    lineWidth: 1))
        .contentShape(Rectangle())
        .opacity(self.isEnabled ? 1 : 0.6)
    }
}
struct ProviderSidebarSectionCard<Content: View>: View {
    @Environment(\.runicFonts) private var fonts
    private let content: Content
    @Environment(\.runicTheme) private var runicTheme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        self.content
            .padding(ProviderListMetrics.sidebarCardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: ProviderListMetrics.sidebarCardCornerRadius,
                    style: .continuous)
                    .fill(self.runicTheme.menuSubtleFill.opacity(
                        ProviderListMetrics.sidebarCardBackgroundOpacity + 0.16)))
            .overlay(
                RoundedRectangle(
                    cornerRadius: ProviderListMetrics.sidebarCardCornerRadius,
                    style: .continuous)
                    .strokeBorder(
                        self.runicTheme.menuSeparatorColor.opacity(ProviderListMetrics.sidebarCardBorderOpacity + 0.12),
                        lineWidth: 1))
    }
}

struct ProviderHistoryNavigationButton: View {
    @Environment(\.runicFonts) private var fonts
    let systemName: String
    let enabled: Bool
    let help: String
    let action: () -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            Image(systemName: self.systemName)
                .font(self.fonts.caption.weight(.semibold))
                .foregroundStyle(self.enabled ? .secondary : .tertiary)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(!self.enabled)
        .background(
            Circle()
                .fill(self.runicTheme.menuSubtleFill.opacity(self.enabled ? 0.82 : 0.32))
                .overlay(
                    Circle()
                        .strokeBorder(
                            self.runicTheme.menuSeparatorColor.opacity(self.enabled ? 0.40 : 0.16),
                            lineWidth: 1)))
        .help(self.help)
        .accessibilityLabel(self.help)
    }
}

struct ProviderSidebarSectionHeader: View {
    @Environment(\.runicFonts) private var fonts
    let title: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.title)
            .font(self.fonts.subheadline.weight(.semibold))
            .foregroundStyle(self.runicTheme.secondaryText)
    }
}

@MainActor
struct ProviderSidebarKeyValueRow: View {
    @Environment(\.runicFonts) private var fonts
    let label: String
    let value: String
    let helpText: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: RunicSpacing.xs) {
            Text("\(self.label):")
                .font(self.fonts.caption)
                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                .frame(width: ProviderListMetrics.sidebarStatusLabelWidth, alignment: .leading)
            if let helpText = self.helpText {
                Text(self.value)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .help(helpText)
            } else {
                Text(self.value)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

@MainActor
struct ProviderSidebarMetricChip: View {
    @Environment(\.runicFonts) private var fonts
    let title: String
    let value: String
    let helpText: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
            Text(self.title)
                .font(self.fonts.caption2.weight(.semibold))
                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                .textCase(.uppercase)
            Text(self.value)
                .font(self.fonts.caption.weight(.medium))
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.xs)
        .background(
            RoundedRectangle(
                cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor)
                    .opacity(ProviderListMetrics.sidebarMicroCardBackgroundOpacity)))
        .overlay(
            RoundedRectangle(
                cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                style: .continuous)
                .strokeBorder(Color(
                    nsColor: .separatorColor).opacity(ProviderListMetrics.sidebarMicroCardBorderOpacity), lineWidth: 1))
        .help(self.helpText ?? "")
    }
}

enum ProviderDetailSubview: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case history = "History"

    var id: String {
        self.rawValue
    }
}

enum ProviderHistoryMetricMode: String, CaseIterable, Identifiable {
    case tokens = "Tokens"
    case cost = "Cost"
    case requests = "Requests"

    var id: String {
        self.rawValue
    }
}

enum ProviderHistoryDayDetailMode: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case models = "Models"
    case projects = "Projects"

    var id: String {
        self.rawValue
    }
}

@MainActor
struct ProviderHistoryCalendarDayCell: View {
    @Environment(\.runicFonts) private var fonts
    let dayNumber: Int
    let isInMonth: Bool
    let isSelected: Bool
    let hasActivity: Bool
    let intensity: Double
    let action: () -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                Text("\(self.dayNumber)")
                    .font(self.fonts.caption.weight(self.isSelected ? .semibold : .regular))
                    .foregroundStyle(self.isInMonth ? .primary : .tertiary)
                Spacer(minLength: 0)
                if self.hasActivity {
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.35 + (0.45 * self.intensity)))
                        .frame(height: 4)
                } else {
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .separatorColor).opacity(self.isInMonth ? 0.14 : 0.08))
                        .frame(height: 2)
                }
            }
            .padding(RunicSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .topLeading)
            .background(
                RoundedRectangle(
                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                    style: .continuous)
                    .fill(self.backgroundColor))
            .overlay(
                RoundedRectangle(
                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                    style: .continuous)
                    .strokeBorder(self.borderColor, lineWidth: self.isSelected ? 1.5 : 1))
            .opacity(self.isInMonth ? 1 : 0.52)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if self.isSelected {
            return Color.accentColor.opacity(0.18)
        }
        if self.hasActivity {
            return Color.accentColor.opacity(0.06 + (0.18 * self.intensity))
        }
        return Color(nsColor: .textBackgroundColor).opacity(self.isInMonth ? 0.55 : 0.32)
    }

    private var borderColor: Color {
        if self.isSelected {
            return Color.accentColor.opacity(0.75)
        }
        return Color(nsColor: .separatorColor).opacity(self.isInMonth ? 0.22 : 0.12)
    }
}
