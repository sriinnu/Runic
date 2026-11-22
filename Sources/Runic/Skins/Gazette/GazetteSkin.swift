import AppKit
import RunicCore
import SwiftUI

/// The printed broadsheet edition — WSJ / NY Times editorial grammar with
/// Morning (`#FAF8F3`) and Evening (`#141311`) newsprint palettes, Baskerville
/// mastheads, Georgia numerals and italic decks, Archivo Narrow condensed
/// datelines/kickers/tabs, and crisp horizontal ink rules.
struct GazetteSkin: RunicSkin {
    static let skinID = "gazette"
    var id: String {
        Self.skinID
    }

    var showsTabTray: Bool {
        false
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(GazetteUsageCard(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(GazetteOverviewBody(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(GazetteResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(GazettePanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(GazetteTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(GazetteChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(GazetteActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(GazetteKicker(text: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(GazetteNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(
            GazetteFooter(
                byline: "By \(RunicSkinImprint.author)",
                bylineURL: RunicSkinImprint.authorURL,
                imprint: "Runic \(RunicVersion.marketing) \u{00B7} \(RunicGazette.edition)",
                buttonTitle: "About \u{2197}",
                action: context.openAbout)
                .frame(width: context.width)
                .padding(.top, RunicSpacing.xxs))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        RunicSkinPopoverChrome(
            cornerRadius: 8,
            strokeWidth: 1,
            strokeColor: palette.primaryText.opacity(0.85))
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        RunicGazette.pageHorizontalInset
    }
}

// MARK: - Broadsheet Panel

private struct GazettePanel: View {
    let content: AnyView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GazetteRule(weight: .single)
                .padding(.horizontal, RunicGazette.pageHorizontalInset)
            self.content
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.runicTheme.surface)
    }
}

// MARK: - Single-Row Broadsheet Tab Strip

private struct GazetteTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(self.items) { item in
                    GazetteTabButton(item: item) { self.onSelect(item.provider) }
                }
            }
            .padding(.horizontal, RunicGazette.pageHorizontalInset)
            .padding(.vertical, 2)
        }
        .frame(width: self.width, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider tabs")
    }
}

private struct GazetteTabButton: View {
    let item: ProviderTabBarView.TabItem
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        let foreground = self.item.isSelected ? self.runicTheme.surface : self.runicTheme.primaryText
        let background = self.item.isSelected
            ? self.runicTheme.primaryText
            : (self.isHovered ? self.runicTheme.surfaceAlt : self.runicTheme.surface)

        Button(action: self.action) {
            HStack(spacing: 5) {
                if let provider = self.item.provider {
                    let needsInvertedIcon = self.item.isSelected ? !dark : dark
                    if let icon = ProviderBrandIcon.image(for: provider, size: 12, prefersDark: needsInvertedIcon) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 11, height: 11)
                            .accessibilityHidden(true)
                    }
                } else {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(foreground)
                        .accessibilityHidden(true)
                }

                Text(self.item.label.uppercased())
                    .font(RunicGazette.sans(10.5, self.item.isSelected ? .bold : .semibold))
                    .gazetteFace()
                    .tracking(0.6)
                    .foregroundStyle(foreground)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(shape.fill(background))
            .overlay {
                if !self.item.isSelected {
                    shape.strokeBorder(
                        self.isHovered
                            ? self.runicTheme.primaryText.opacity(0.6)
                            : self.runicTheme.cardStroke,
                        lineWidth: 1)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) {
                self.isHovered = hovering
            }
        }
        .accessibilityLabel(self.item.label)
        .accessibilityAddTraits(self.item.isSelected ? [.isSelected] : [])
    }
}

// MARK: - Editorial Chip, Action Row and Note

private struct GazetteChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        let selectedFill = self.runicTheme.primaryText.opacity(dark ? 0.14 : 0.08)
        let background = self.chip.isSelected
            ? selectedFill
            : (self.isHovered ? self.runicTheme.surfaceAlt : self.runicTheme.surface)
        let border = self.chip.isSelected
            ? self.runicTheme.primaryText
            : (self.isHovered ? self.runicTheme.primaryText.opacity(0.55) : self.runicTheme.cardStroke)
        let foreground = (self.chip.isSelected || self.isHovered)
            ? self.runicTheme.primaryText
            : self.runicTheme.secondaryText

        Button(action: self.chip.action) {
            HStack(spacing: 6) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                    .accessibilityHidden(true)
                Text(self.chip.title.uppercased())
                    .font(RunicGazette.sans(10, self.chip.isSelected ? .bold : .semibold))
                    .gazetteFace()
                    .tracking(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .frame(height: 25)
            .foregroundStyle(foreground)
            .background(shape.fill(background))
            .overlay(shape.strokeBorder(border, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) {
                self.isHovered = hovering
            }
        }
        .accessibilityAddTraits(self.chip.isSelected ? [.isSelected] : [])
    }
}

private struct GazetteActionRow: View {
    let row: RunicSkinActionRow
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.row.isCompact {
            GazetteCompactButton(
                title: self.row.title,
                systemImage: self.row.systemImage,
                action: self.row.action)
                .frame(maxWidth: .infinity)
        } else {
            Button(action: self.row.action) {
                HStack(spacing: 8) {
                    Group {
                        if let systemImage = self.row.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(
                                    self.isHovered ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: RunicSpacing.menuActionIconColumnWidth)
                    .accessibilityHidden(true)

                    Text(self.row.title)
                        .font(RunicGazette.body(12))
                        .gazetteFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    Text("\u{2192}")
                        .font(RunicGazette.sans(10.5, .medium))
                        .gazetteFace()
                        .foregroundStyle(
                            self.isHovered ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(self.isHovered ? self.runicTheme.surfaceAlt : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(self.runicTheme.motion.curve) {
                    self.isHovered = hovering
                }
            }
        }
    }
}

private struct GazetteCompactButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        let foreground = self.isHovered ? self.runicTheme.surface : self.runicTheme.primaryText
        let background = self.isHovered ? self.runicTheme.primaryText : self.runicTheme.surface
        Button(action: self.action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .medium))
                        .accessibilityHidden(true)
                }
                Text(self.title.uppercased())
                    .font(RunicGazette.sans(9.5, .bold))
                    .gazetteFace()
                    .tracking(0.8)
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(shape.fill(background))
            .overlay(shape.strokeBorder(self.runicTheme.primaryText.opacity(self.isHovered ? 1 : 0.4), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) {
                self.isHovered = hovering
            }
        }
    }
}

private struct GazetteNote: View {
    let text: String
    let isHeadline: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: RunicSpacing.menuActionIconColumnWidth, height: 1)
            Text(self.text)
                .font(self.isHeadline ? RunicGazette.headline(11.5) : RunicGazette.copy(9.5))
                .gazetteFace()
                .foregroundStyle(self.isHeadline ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }
}
