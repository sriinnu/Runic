import AppKit
import RunicCore
import SwiftUI

/// Ink on washi. Pages: `SumiProviderPage`, `SumiFrontPage`,
/// `SumiResetsPage`. Kit: `RunicSumiKit.swift`. Nothing on the page is
/// boxed — sections open under a dry-brush rule — and the chosen tab is a
/// vermilion hanko.
struct SumiSkin: RunicSkin {
    static let skinID = "sumi"
    var id: String {
        Self.skinID
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(SumiProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(SumiFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(SumiResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(SumiPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(SumiTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(SumiChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(SumiActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(SumiLabel(text: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(SumiNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(SumiFooter(context: context))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        RunicSkinPopoverChrome(cornerRadius: 6, strokeWidth: 1, strokeColor: palette.primaryText.opacity(0.35))
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        RunicSpacing.xxs
    }

    var showsTabTray: Bool {
        false
    }
}

// MARK: - Panel

/// A section sits straight on the paper under a brush rule.
private struct SumiPanel: View {
    let content: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SumiRule(opacity: 0.75)
            self.content
                .padding(.top, 8)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tabs

/// The provider strip as a row of seals: the chosen one is stamped in
/// vermilion, the rest are outlined in ink.
private struct SumiTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(self.items) { item in
                    SumiTab(item: item) { self.onSelect(item.provider) }
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

private struct SumiTab: View {
    let item: ProviderTabBarView.TabItem
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        let paper = self.runicTheme.surface
        let seal = self.runicTheme.accent
        Button(action: self.action) {
            HStack(spacing: 7) {
                if self.item.provider == nil {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(self.item.label)
                    .font(RunicSumi.gothic(12, self.item.isSelected ? .bold : .medium))
                    .skinFace()
                    .lineLimit(1)
            }
            .foregroundStyle(self.item.isSelected ? paper : (self.isHovered ? seal : ink))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(self.item.isSelected ? seal : Color.clear))
            .overlay {
                if self.item.isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(paper.opacity(0.5), lineWidth: 1.5)
                        .padding(2.5)
                } else {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(self.isHovered ? seal : ink.opacity(0.55), lineWidth: 1)
                }
            }
            .rotationEffect(.degrees(self.item.isSelected ? -1.5 : 0))
            .contentShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityAddTraits(self.item.isSelected ? [.isSelected] : [])
    }
}

// MARK: - Chip, rows, notes

private struct SumiChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        let paper = self.runicTheme.surface
        Button(action: self.chip.action) {
            HStack(spacing: 7) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 9.5, weight: .semibold))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                Text(self.chip.title)
                    .font(RunicSumi.gothic(11.5, self.chip.isSelected ? .bold : .medium))
                    .skinFace()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .foregroundStyle(self.chip.isSelected ? paper : (self.isHovered ? self.runicTheme.accent : ink))
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(self.chip.isSelected ? ink : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(
                        self.chip.isSelected ? Color
                            .clear : (self.isHovered ? self.runicTheme.accent : ink.opacity(0.45)),
                        lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

private struct SumiActionRow: View {
    let row: RunicSkinActionRow
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.row.isCompact {
            SumiButton(title: self.row.title, systemImage: self.row.systemImage, action: self.row.action)
                .frame(maxWidth: .infinity)
        } else {
            Button(action: self.row.action) {
                HStack(spacing: 10) {
                    ZStack {
                        if let systemImage = self.row.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 11, weight: .medium))
                                .opacity(self.isHovered ? 0 : 1)
                        }
                        Circle()
                            .fill(self.runicTheme.accent)
                            .frame(width: 6, height: 6)
                            .opacity(self.isHovered ? 1 : 0)
                    }
                    .frame(width: RunicSpacing.menuActionIconColumnWidth)
                    Text(self.row.title)
                        .font(RunicSumi.gothic(12.5, .medium))
                        .skinFace()
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                }
                .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
            }
        }
    }
}

private struct SumiNote: View {
    let text: String
    let isHeadline: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: RunicSpacing.menuActionIconColumnWidth, height: 1)
            Text(self.text)
                .font(self.isHeadline ? RunicSumi.strong(12) : RunicSumi.copy(11.5))
                .skinFace()
                .foregroundStyle(self.isHeadline ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Footer

/// The colophon: edition on the left, the author's seal on the right.
private struct SumiFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(self.runicTheme.primaryText.opacity(0.25))
                .frame(height: 1)
            HStack(alignment: .center, spacing: 8) {
                SumiLabel(text: RunicSkinImprint.line, size: 9.5, tracking: 2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button {
                    NSWorkspace.shared.open(RunicSkinImprint.authorURL)
                } label: {
                    HStack(spacing: 8) {
                        Text("by \(RunicSkinImprint.author)")
                            .font(RunicSumi.mincho(12, .semibold))
                            .skinFace()
                            .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText)
                        SumiSeal(text: "\u{5370}", size: 18, rotation: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { self.isHovered = $0 }
                .accessibilityLabel("by \(RunicSkinImprint.author), opens GitHub")
                SumiButton(title: "About", action: self.context.openAbout)
                    .scaleEffect(0.85, anchor: .trailing)
            }
        }
        .skinFace()
        .frame(width: self.context.width)
        .padding(.top, RunicSpacing.xxs)
    }
}
