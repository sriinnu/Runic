import AppKit
import RunicCore
import SwiftUI

/// A Solari departures board. Pages: `DeparturesProviderPage`,
/// `DeparturesFrontPage`, `DeparturesResetsPage`. Kit:
/// `RunicDeparturesKit.swift`. The stage is near-black inside a charcoal
/// frame; tabs are flat rectangles with the chosen one in board yellow and
/// a clock at the right; every number sits on a flap.
struct DeparturesSkin: RunicSkin {
    static let skinID = "departures"
    var id: String {
        Self.skinID
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(DeparturesProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(DeparturesFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(DeparturesResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(DeparturesPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(DeparturesTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(DeparturesChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(DeparturesActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(DeparturesHeader(text: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(DeparturesNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(DeparturesFooter(context: context))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        // The stroke is centred on the popover's edge, so a 12pt stroke in
        // the frame tone leaves the 6pt inner frame the board sits in; the
        // outer half is clipped by the window.
        RunicSkinPopoverChrome(cornerRadius: 8, strokeWidth: 12, strokeColor: palette.surfaceAlt)
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        RunicSpacing.xxs
    }

    var showsTabTray: Bool {
        false
    }
}

// MARK: - Panel

/// A section sits straight on the stage under a hairline.
private struct DeparturesPanel: View {
    let content: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeparturesHairline(opacity: 0.1)
            self.content
                .padding(.top, 8)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tabs

/// The boards: flat rectangles in tracked caps, the chosen one in yellow
/// with black text, the clock pinned at the right.
private struct DeparturesTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(self.items) { item in
                        DeparturesTab(item: item) { self.onSelect(item.provider) }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Provider tabs")
            DeparturesClock()
                .padding(.trailing, 4)
        }
        .frame(minWidth: self.width, maxWidth: .infinity)
    }
}

private struct DeparturesTab: View {
    let item: ProviderTabBarView.TabItem
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = Color(red: 0.067, green: 0.067, blue: 0.071)
        let label = self.item.provider == nil ? "All gates" : self.item.label
        Button(action: self.action) {
            Text(label.uppercased())
                .font(RunicDepartures.caps(13))
                .skinFace()
                .tracking(1.8)
                .lineLimit(1)
                .foregroundStyle(self.item.isSelected
                    ? ink
                    : (self.isHovered ? self.runicTheme.primaryText : self.runicTheme.primaryText.opacity(0.82)))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(self.item.isSelected
                            ? self.runicTheme.accent
                            : (self.isHovered ? self.runicTheme.cardStroke.opacity(0.6) : self.runicTheme.cardFill)))
                .overlay(alignment: .top) {
                    if !self.item.isSelected {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.horizontal, 1)
                            .padding(.top, 1)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(self.item.isSelected ? [.isSelected] : [])
    }
}

// MARK: - Chip, rows, notes

private struct DeparturesChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = Color(red: 0.067, green: 0.067, blue: 0.071)
        Button(action: self.chip.action) {
            HStack(spacing: 7) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 9.5, weight: .semibold))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                Text(self.chip.title.uppercased())
                    .font(RunicDepartures.caps(11.5))
                    .skinFace()
                    .tracking(1.4)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .foregroundStyle(self.chip.isSelected ? ink : self.runicTheme.primaryText)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(self.chip.isSelected
                        ? self.runicTheme.accent
                        : (self.isHovered ? self.runicTheme.cardStroke.opacity(0.6) : self.runicTheme.cardFill)))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(self.chip.isSelected ? self.runicTheme.accent : self.runicTheme.cardStroke, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

/// "Ping now" becomes the yellow REFRESH BOARD button; the other actions
/// are list rows in caps that light up yellow on hover.
private struct DeparturesActionRow: View {
    let row: RunicSkinActionRow
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    private var isRefresh: Bool {
        let title = self.row.title.lowercased()
        return title.contains("ping") || title.contains("refresh")
    }

    var body: some View {
        if self.row.isCompact {
            DeparturesButton(title: self.row.title, systemImage: self.row.systemImage, action: self.row.action)
                .frame(maxWidth: .infinity)
        } else if self.isRefresh {
            DeparturesButton(
                title: "Refresh board",
                filled: true,
                systemImage: "arrow.clockwise",
                expands: true,
                action: self.row.action)
                .padding(.vertical, 2)
                .accessibilityLabel(self.row.title)
        } else {
            Button(action: self.row.action) {
                HStack(spacing: 10) {
                    Group {
                        if let systemImage = self.row.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .frame(width: RunicSpacing.menuActionIconColumnWidth)
                    Text(self.row.title.uppercased())
                        .font(RunicDepartures.caps(12))
                        .skinFace()
                        .tracking(1.6)
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

private struct DeparturesNote: View {
    let text: String
    let isHeadline: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: RunicSpacing.menuActionIconColumnWidth, height: 1)
            Group {
                if self.isHeadline {
                    Text(self.text.uppercased())
                        .font(RunicDepartures.caps(11.5))
                        .skinFace()
                        .tracking(1.4)
                        .foregroundStyle(self.runicTheme.primaryText)
                } else {
                    Text(self.text)
                        .font(RunicDepartures.copy(11.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
            }
            .lineLimit(2)
            .truncationMode(.tail)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Footer

/// The board's plate: edition on the left, the operator's link and an
/// About control on the right.
private struct DeparturesFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    private var imprint: String {
        RunicSkinImprint.line.replacingOccurrences(of: "No. ", with: "Board ")
    }

    var body: some View {
        VStack(spacing: 10) {
            DeparturesHairline(opacity: 0.14)
            HStack(alignment: .center, spacing: 10) {
                DeparturesHeader(text: self.imprint, size: 9.5, tracking: 1.8)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button {
                    NSWorkspace.shared.open(RunicSkinImprint.authorURL)
                } label: {
                    DeparturesHeader(
                        text: "Operated by \(RunicSkinImprint.author)",
                        size: 9.5,
                        color: self.isHovered ? self.runicTheme.primaryText : self.runicTheme.accent,
                        tracking: 1.8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { self.isHovered = $0 }
                .accessibilityLabel("Operated by \(RunicSkinImprint.author), opens GitHub")
                DeparturesAboutButton(action: self.context.openAbout)
            }
        }
        .skinFace()
        .frame(width: self.context.width)
        .padding(.top, RunicSpacing.xxs)
    }
}

/// A small square "?" in the board button style.
private struct DeparturesAboutButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            Text("?")
                .font(RunicDepartures.caps(12))
                .skinFace()
                .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(self.isHovered ? self.runicTheme.cardStroke.opacity(0.6) : self.runicTheme.cardFill))
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(self.runicTheme.cardStroke, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityLabel("About Runic")
    }
}
