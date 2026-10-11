import AppKit
import RunicCore
import SwiftUI

/// An engineering drawing sheet. Pages: `DraftingProviderPage`,
/// `DraftingFrontPage`, `DraftingResetsPage`. Kit: `RunicDraftingKit.swift`.
/// Panels are 1pt ruled, square and unfilled on the blueprint; tabs are
/// sheet index tabs; the footer is the title block.
struct DraftingSkin: RunicSkin {
    static let skinID = "drafting"
    var id: String {
        Self.skinID
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(DraftingProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(DraftingFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(DraftingResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(DraftingPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(DraftingTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(DraftingChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(DraftingActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(DraftingSectionHeader(text: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(DraftingNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(DraftingFooter(context: context))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        RunicSkinPopoverChrome(cornerRadius: 0, strokeWidth: 1, strokeColor: palette.primary)
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        RunicSpacing.xs
    }

    var showsTabTray: Bool {
        false
    }
}

// MARK: - Panel

/// A section is a ruled rectangle on the sheet: 1pt line, square corners,
/// no fill.
private struct DraftingPanel: View {
    let content: AnyView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        self.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(self.runicTheme.primary, lineWidth: 1))
    }
}

// MARK: - Tabs

/// Sheet index tabs along a rule: the open sheet is filled paper with navy
/// text, the rest are outlined.
private struct DraftingTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: -1) {
                    ForEach(Array(self.items.enumerated()), id: \.element.id) { index, item in
                        DraftingTab(item: item, index: index) { self.onSelect(item.provider) }
                    }
                }
                .padding(.horizontal, 1)
            }
            Rectangle()
                .fill(self.runicTheme.primary)
                .frame(height: 1)
        }
        .frame(minWidth: self.width, maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sheet tabs")
    }
}

private struct DraftingTab: View {
    let item: ProviderTabBarView.TabItem
    let index: Int
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primary
        let paper = self.runicTheme.surface
        let selected = self.item.isSelected
        Button(action: self.action) {
            Text(RunicDrafting.sheetTitle(
                index: self.index,
                label: self.item.label,
                isOverview: self.item.provider == nil)
                .uppercased())
                .font(RunicDrafting.mono(10, selected ? .bold : .medium))
                .skinFace()
                .tracking(1.4)
                .lineLimit(1)
                .foregroundStyle(selected || self.isHovered ? paper : ink)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Rectangle().fill(selected ? ink : (self.isHovered ? ink.opacity(0.85) : Color.clear)))
                .draftingEdges([.top, .leading, .trailing], color: ink)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityLabel(self.item.provider == nil ? "General arrangement" : self.item.label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - Chip, rows, notes

private struct DraftingChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primary
        let paper = self.runicTheme.surface
        let on = self.chip.isSelected
        Button(action: self.chip.action) {
            HStack(spacing: 6) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                Text(self.chip.title.uppercased())
                    .font(RunicDrafting.mono(10, on ? .bold : .medium))
                    .skinFace()
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .foregroundStyle(on || self.isHovered ? paper : ink)
            .background(Rectangle().fill(on ? ink : (self.isHovered ? ink.opacity(0.85) : Color.clear)))
            .overlay(Rectangle().stroke(on ? ink : ink.opacity(0.6), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

/// A full-width outlined button in mono caps; the refresh row is the
/// accent-filled primary. Compact rows (CSV) are the small outlined button.
private struct DraftingActionRow: View {
    let row: RunicSkinActionRow

    var body: some View {
        if self.row.isCompact {
            DraftingButton(
                title: self.row.title,
                systemImage: self.row.systemImage,
                compact: true,
                action: self.row.action)
                .frame(maxWidth: .infinity)
        } else {
            DraftingButton(
                title: self.row.title,
                filled: self.row.systemImage == "arrow.clockwise",
                systemImage: self.row.systemImage,
                fullWidth: true,
                action: self.row.action)
        }
    }
}

private struct DraftingSectionHeader: View {
    let text: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 8) {
            DraftingCap(text: self.text)
            Rectangle()
                .fill(self.runicTheme.primary.opacity(0.35))
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }
}

private struct DraftingNote: View {
    let text: String
    let isHeadline: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(self.isHeadline ? "NOTE" : "\u{2014}")
                .font(RunicDrafting.mono(9, .medium))
                .skinFace()
                .tracking(1)
                .foregroundStyle(self.runicTheme.secondary)
                .frame(width: 30, alignment: .leading)
                .padding(.top, 1.5)
            Text(self.text)
                .font(self.isHeadline ? RunicDrafting.strong(11.5) : RunicDrafting.copy(11))
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

/// The title block: PROJECT (the imprint), DRAWN (the author, linked to
/// GitHub), DATE, and an About cell — one ruled grid.
private struct DraftingFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @State private var aboutHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primary
        HStack(spacing: 0) {
            DraftingCell(
                label: "Project",
                value: RunicSkinImprint.line.uppercased(),
                valueFont: RunicDrafting.sans(11, .bold),
                edges: [],
                edgeOpacity: 1)
            Button {
                NSWorkspace.shared.open(RunicSkinImprint.authorURL)
            } label: {
                DraftingCell(
                    label: "Drawn",
                    value: RunicSkinImprint.author.uppercased(),
                    valueFont: RunicDrafting.mono(11, .medium),
                    valueColor: self.isHovered ? self.runicTheme.highlight : self.runicTheme.accent,
                    edges: [.leading],
                    edgeOpacity: 1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { self.isHovered = $0 }
            .frame(width: 84)
            .accessibilityLabel("Drawn by \(RunicSkinImprint.author), opens GitHub")
            DraftingCell(
                label: "Date",
                value: RunicDrafting.dateStamp(withYear: true),
                valueFont: RunicDrafting.mono(11, .medium),
                edges: [.leading],
                edgeOpacity: 1)
                .frame(width: 84)
            Button(action: self.context.openAbout) {
                Text("?")
                    .font(RunicDrafting.mono(13, .bold))
                    .skinFace()
                    .foregroundStyle(self.aboutHovered ? self.runicTheme.surface : ink)
                    .frame(width: 34)
                    .frame(maxHeight: .infinity)
                    .background(Rectangle().fill(self.aboutHovered ? ink : Color.clear))
                    .draftingEdges(.leading, color: ink)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(self.runicTheme.motion.curve) { self.aboutHovered = hovering }
            }
            .accessibilityLabel("About Runic")
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(Rectangle().stroke(ink, lineWidth: 1))
        .skinFace()
        .frame(width: self.context.width)
        .padding(.top, RunicSpacing.xxs)
    }
}
