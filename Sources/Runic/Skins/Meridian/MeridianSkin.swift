import AppKit
import RunicCore
import SwiftUI

// MARK: - Meridian Skin

/// Fine Horology chronometer skin — Porcelain Enamel in daylight and Grand Feu
/// Midnight in dark appearance. Pages: `MeridianFrontPage`, `MeridianProviderPage`,
/// `MeridianResetsPage`. Kit: `RunicMeridianKit.swift`.
struct MeridianSkin: RunicSkin {
    static let skinID = "meridian"
    var id: String {
        Self.skinID
    }

    var showsTabTray: Bool {
        false
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(MeridianProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(MeridianFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(MeridianResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(MeridianPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(MeridianTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(MeridianChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(MeridianActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(MeridianSectionTitle(title: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(MeridianNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(MeridianFooter(context: context))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        RunicSkinPopoverChrome(
            cornerRadius: RunicMeridian.popoverRadius,
            strokeWidth: 0.75,
            strokeColor: palette.cardStroke)
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        RunicMeridian.panelInset
    }

    @MainActor func stageOverlay() -> AnyView? {
        AnyView(MeridianCaseBezelOverlay())
    }
}

// MARK: - Stage Overlay

/// Double-bezel watch case rim around the popover with subtle cardinal micro-batons.
private struct MeridianCaseBezelOverlay: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RunicMeridian.popoverRadius, style: .continuous)
        ZStack {
            shape
                .inset(by: 3)
                .strokeBorder(self.runicTheme.cardStroke.opacity(0.45), lineWidth: 0.5)
            VStack {
                Rectangle()
                    .fill(self.runicTheme.accent.opacity(0.50))
                    .frame(width: 14, height: 1.5)
                Spacer()
                Rectangle()
                    .fill(self.runicTheme.accent.opacity(0.35))
                    .frame(width: 10, height: 1.5)
            }
            .padding(.vertical, 3.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Panel

private struct MeridianPanel: View {
    let content: AnyView

    var body: some View {
        self.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: RunicMeridian.plateRadius, style: .continuous))
            .background(MeridianDialPlateBackground())
    }
}

// MARK: - Tabs

private struct MeridianTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(self.items) { item in
                    MeridianTab(item: item) { self.onSelect(item.provider) }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .frame(minWidth: self.width, maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider tabs")
    }
}

private struct MeridianTab: View {
    let item: ProviderTabBarView.TabItem
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RunicMeridian.jewelPillRadius + 2, style: .continuous)
        Button(action: self.action) {
            HStack(spacing: 6) {
                if let icon = self.item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .accessibilityHidden(true)
                } else if self.item.provider == nil {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 10, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(self.item.label)
                    .font(RunicMeridian.body(11.5, self.item.isSelected ? .semibold : .medium))
                    .skinFace()
                    .lineLimit(1)
            }
            .foregroundStyle(self.foreground)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background {
                if self.item.isSelected {
                    ZStack {
                        shape.fill(self.runicTheme.cardFill)
                        shape.fill(self.runicTheme.accent.opacity(0.12))
                        shape.strokeBorder(self.runicTheme.accent.opacity(0.65), lineWidth: 0.75)
                    }
                } else if self.isHovered {
                    shape.fill(self.runicTheme.primaryText.opacity(0.06))
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityLabel(self.item.label)
        .accessibilityAddTraits(self.item.isSelected ? [.isSelected] : [])
    }

    private var foreground: Color {
        if self.item.isSelected { return self.runicTheme.accent }
        return self.isHovered ? self.runicTheme.primaryText : self.runicTheme.secondaryText
    }
}

// MARK: - Chip, Action Rows & Notes

private struct MeridianChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RunicMeridian.jewelPillRadius, style: .continuous)
        Button(action: self.chip.action) {
            HStack(spacing: 6) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                    .accessibilityHidden(true)
                Text(self.chip.title)
                    .font(RunicMeridian.body(11.5, self.chip.isSelected ? .semibold : .medium))
                    .skinFace()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(self.chip.isSelected
                ? self.runicTheme.accent
                : (self.isHovered ? self.runicTheme.primaryText : self.runicTheme.secondaryText))
            .background {
                if self.chip.isSelected {
                    shape.fill(self.runicTheme.accent.opacity(0.14))
                        .overlay(shape.strokeBorder(self.runicTheme.accent.opacity(0.5), lineWidth: 0.7))
                } else {
                    shape.fill(self.runicTheme.primaryText.opacity(self.isHovered ? 0.07 : 0.04))
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityAddTraits(self.chip.isSelected ? [.isSelected] : [])
    }
}

private struct MeridianActionRow: View {
    let row: RunicSkinActionRow
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.row.isCompact {
            MeridianButton(title: self.row.title, systemImage: self.row.systemImage, action: self.row.action)
                .frame(maxWidth: .infinity)
        } else {
            let shape = RoundedRectangle(cornerRadius: RunicMeridian.jewelPillRadius, style: .continuous)
            Button(action: self.row.action) {
                HStack(spacing: 10) {
                    Group {
                        if let systemImage = self.row.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(self.runicTheme.iconColor(
                                    for: self.row.iconIntent,
                                    hovered: self.isHovered))
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: RunicSpacing.menuActionIconColumnWidth)
                    .accessibilityHidden(true)
                    Text(self.row.title)
                        .font(RunicMeridian.body(12, .medium))
                        .skinFace()
                        .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if self.isHovered {
                        shape.fill(self.runicTheme.menuHoverFill)
                    }
                }
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
            }
        }
    }
}

private struct MeridianNote: View {
    let text: String
    let isHeadline: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: RunicSpacing.menuActionIconColumnWidth, height: 1)
            Text(self.text)
                .font(self.isHeadline ? RunicMeridian.body(11.5, .semibold) : RunicMeridian.body(11))
                .skinFace()
                .foregroundStyle(self.isHeadline ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
    }
}

// MARK: - Caseback Footer

private struct MeridianFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 8) {
            MeridianCasebackRule()
            HStack(alignment: .center, spacing: 8) {
                Text(RunicSkinImprint.line)
                    .font(RunicMeridian.mono(9.5, .medium))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button {
                    NSWorkspace.shared.open(RunicSkinImprint.authorURL)
                } label: {
                    Text("CHRONOMETER \u{00B7} \(RunicSkinImprint.author.uppercased())")
                        .font(RunicMeridian.label(9))
                        .skinFace()
                        .tracking(0.8)
                        .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.secondaryText)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { self.isHovered = $0 }
                .accessibilityLabel("by \(RunicSkinImprint.author), opens GitHub")
                MeridianButton(title: "About", action: self.context.openAbout)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: self.context.width)
    }
}
