import AppKit
import RunicCore
import SwiftUI

// MARK: - Atelier Skin

/// Swiss-Nordic architectural studio skin — warm `18px` dot-grid drafting
/// paper (`#F5F5F1`) and white spec sheets in daylight; deep charcoal (`#121212`)
/// studio night elevation in dark appearance; electric blueprint cobalt (`#3848F0`
/// / `#7C8AFF`) highlights, crop-marks, and Quota Skyline towers.
/// Pages: `AtelierFrontPage`, `AtelierProviderPage`, `AtelierResetsPage`.
/// Kit: `RunicAtelierKit.swift`.
struct AtelierSkin: RunicSkin {
    static let skinID = "atelier"
    var id: String {
        Self.skinID
    }

    var showsTabTray: Bool {
        false
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(AtelierProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(AtelierFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(AtelierResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(AtelierPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(AtelierTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(AtelierChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(AtelierActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(AtelierKicker(text: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(AtelierNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(AtelierFooter(context: context))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        RunicSkinPopoverChrome(
            cornerRadius: RunicAtelier.popoverRadius,
            strokeWidth: 1.0,
            strokeColor: palette.cardStroke)
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        RunicAtelier.panelInset
    }
}

// MARK: - Panel Container

private struct AtelierPanel: View {
    let content: AnyView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        self.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(self.runicTheme.cardFill)
            .overlay(Rectangle().strokeBorder(self.runicTheme.cardStroke, lineWidth: 1))
    }
}

// MARK: - Pill Tab Strip (9999px Filter Pills + 1px Rule)

private struct AtelierTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(self.items) { item in
                        AtelierTabPill(item: item) { self.onSelect(item.provider) }
                    }
                }
                .padding(.vertical, 2)
            }
            AtelierHairline()
        }
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider tabs")
    }
}

private struct AtelierTabPill: View {
    let item: ProviderTabBarView.TabItem
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        let shape = Capsule(style: .continuous)
        Button(action: self.action) {
            HStack(spacing: 5) {
                if let icon = self.item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                }
                Text(self.item.label)
                    .font(RunicAtelier.sans(11.5, self.item.isSelected ? .medium : .regular))
                    .skinFace()
                    .lineLimit(1)
            }
            .foregroundStyle(self.foreground(dark: dark))
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(shape.fill(self.background(dark: dark)))
            .overlay {
                if !self.item.isSelected {
                    shape.strokeBorder(
                        self.isHovered ? self.runicTheme.accent.opacity(0.65) : self.runicTheme.cardStroke,
                        lineWidth: 1)
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

    private func foreground(dark: Bool) -> Color {
        if self.item.isSelected {
            return dark ? Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255) : Color.white
        }
        return self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText
    }

    private func background(dark: Bool) -> Color {
        if self.item.isSelected {
            return self.runicTheme.primary
        }
        return self.isHovered ? self.runicTheme.surfaceAlt : self.runicTheme.cardFill
    }
}

// MARK: - Chip, Action Rows & Notes

private struct AtelierChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        let selectedFill = self.runicTheme.accent.opacity(dark ? 0.16 : 0.08)
        let borderColor: Color = if self.chip.isSelected {
            self.runicTheme.accent
        } else if self.isHovered {
            self.runicTheme.accent.opacity(0.65)
        } else {
            self.runicTheme.cardStroke
        }
        Button(action: self.chip.action) {
            HStack(spacing: 6) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                    .accessibilityHidden(true)
                Text(self.chip.title)
                    .font(RunicAtelier.sans(11.5, self.chip.isSelected ? .medium : .regular))
                    .skinFace()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(self.foreground)
            .background {
                Rectangle().fill(
                    self.chip.isSelected
                        ? selectedFill
                        : (self.isHovered ? self.runicTheme.surfaceAlt : self.runicTheme.cardFill))
            }
            .overlay {
                Rectangle().strokeBorder(borderColor, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityAddTraits(self.chip.isSelected ? [.isSelected] : [])
    }

    private var foreground: Color {
        if self.chip.isSelected || self.isHovered {
            return self.runicTheme.accent
        }
        return self.runicTheme.secondaryText
    }
}

private struct AtelierActionRow: View {
    let row: RunicSkinActionRow
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.row.isCompact {
            AtelierButton(title: self.row.title, arrow: nil, systemImage: self.row.systemImage, action: self.row.action)
                .frame(maxWidth: .infinity)
        } else {
            Button(action: self.row.action) {
                HStack(spacing: 10) {
                    Group {
                        if let systemImage = self.row.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme
                                    .secondaryText)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: RunicSpacing.menuActionIconColumnWidth)
                    .accessibilityHidden(true)
                    Text(self.row.title)
                        .font(RunicAtelier.sans(12, .regular))
                        .skinFace()
                        .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    Text("\u{2192}")
                        .font(RunicAtelier.mono(10.5))
                        .skinFace()
                        .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.secondaryText)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(self.isHovered ? self.runicTheme.surfaceAlt : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
            }
        }
    }
}

private struct AtelierNote: View {
    let text: String
    let isHeadline: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: RunicSpacing.menuActionIconColumnWidth, height: 1)
            Text(self.text)
                .font(self.isHeadline ? RunicAtelier.sans(11.5, .medium) : RunicAtelier.sans(11))
                .skinFace()
                .foregroundStyle(self.isHeadline ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
    }
}

// MARK: - Studio Colophon Footer

private struct AtelierFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 8) {
            AtelierHairline()
            HStack(alignment: .center, spacing: 8) {
                Text(RunicSkinImprint.line)
                    .font(RunicAtelier.mono(9.5, .medium))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button {
                    NSWorkspace.shared.open(RunicSkinImprint.authorURL)
                } label: {
                    Text("ATELIER \u{00B7} \(RunicSkinImprint.author.uppercased())")
                        .font(RunicAtelier.kicker(8.5))
                        .skinFace()
                        .tracking(0.8)
                        .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.secondaryText)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { self.isHovered = $0 }
                .accessibilityLabel("by \(RunicSkinImprint.author), opens GitHub")
                AtelierButton(title: "About", arrow: "\u{2197}", action: self.context.openAbout)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: self.context.width)
    }
}
