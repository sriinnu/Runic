import AppKit
import RunicCore
import SwiftUI

/// A thermal receipt out of a dark printer. Pages: `ReceiptProviderPage`,
/// `ReceiptFrontPage`, `ReceiptResetsPage` — each prints as paper. Kit:
/// `RunicReceiptKit.swift`. Everything else sits on the printer body in
/// outlined mono panels with paper text; the chosen tab is paper-filled.
struct ReceiptSkin: RunicSkin {
    static let skinID = "receipt"
    var id: String {
        Self.skinID
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(ReceiptProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(ReceiptFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(ReceiptResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(ReceiptPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(ReceiptTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(ReceiptChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(ReceiptActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(ReceiptLabel(text: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(ReceiptNote(text: text, style: style))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(ReceiptFooter(context: context))
    }

    func popoverChrome(for _: RunicThemePalette) -> RunicSkinPopoverChrome? {
        RunicSkinPopoverChrome(cornerRadius: 8, strokeWidth: 1, strokeColor: RunicReceipt.paper.opacity(0.18))
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        RunicSpacing.xs
    }

    var showsTabTray: Bool {
        false
    }
}

// MARK: - Panel

/// A page that prints as paper asks its panel to stay bare: no outline, no
/// fill, so the receipt hangs straight out of the printer slot.
struct ReceiptBarePanelKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// A section on the printer body: an outlined mono panel. The pages opt
/// out through `ReceiptBarePanelKey` and print as paper instead.
private struct ReceiptPanel: View {
    let content: AnyView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        self.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .backgroundPreferenceValue(ReceiptBarePanelKey.self) { bare in
                if !bare {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(self.runicTheme.surfaceAlt.opacity(0.55))
                }
            }
            .overlayPreferenceValue(ReceiptBarePanelKey.self) { bare in
                if !bare {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(RunicReceipt.paper.opacity(0.3), lineWidth: 1)
                }
            }
    }
}

// MARK: - Tabs

/// The provider strip: outlined mono rectangles, the chosen one filled with
/// paper, and the build as a ticket number at the right.
private struct ReceiptTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(self.items) { item in
                        ReceiptTab(item: item) { self.onSelect(item.provider) }
                    }
                }
                .padding(.horizontal, 1)
                .padding(.vertical, 3)
            }
            Spacer(minLength: 6)
            Text(RunicReceipt.ticket)
                .font(RunicReceipt.mono(11))
                .skinFace()
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(1)
                .accessibilityLabel("Build \(RunicReceipt.ticket)")
        }
        .frame(width: self.width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider tabs")
    }
}

private struct ReceiptTab: View {
    let item: ProviderTabBarView.TabItem
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let paper = RunicReceipt.paper
        let ink = RunicReceipt.ink
        Button(action: self.action) {
            Text(self.item.provider == nil ? "ALL" : self.item.label.uppercased())
                .font(RunicReceipt.mono(12, bold: true))
                .skinFace()
                .lineLimit(1)
                .foregroundStyle(self.item.isSelected ? ink : paper)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(self.item.isSelected ? paper : (self.isHovered ? paper.opacity(0.14) : .clear)))
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(paper, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityLabel(self.item.label)
        .accessibilityAddTraits(self.item.isSelected ? [.isSelected] : [])
    }
}

// MARK: - Chip, rows, notes, labels

private struct ReceiptChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let paper = RunicReceipt.paper
        let ink = RunicReceipt.ink
        Button(action: self.chip.action) {
            HStack(spacing: 7) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 9.5, weight: .bold))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                Text(self.chip.title.uppercased())
                    .font(RunicReceipt.mono(11, bold: true))
                    .skinFace()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .foregroundStyle(self.chip.isSelected ? ink : paper)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(self.chip.isSelected ? paper : (self.isHovered ? paper.opacity(0.14) : .clear)))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(paper.opacity(self.chip.isSelected || self.isHovered ? 1 : 0.55), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

/// "> PING NOW" in paper on the body; hover prints it as a paper block.
/// Compact rows (CSV) are outlined buttons.
private struct ReceiptActionRow: View {
    let row: RunicSkinActionRow
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.row.isCompact {
            ReceiptButton(title: self.row.title, systemImage: self.row.systemImage, height: 26, action: self.row.action)
                .frame(maxWidth: .infinity)
        } else {
            Button(action: self.row.action) {
                HStack(spacing: 8) {
                    Text(">")
                        .font(RunicReceipt.mono(12, bold: true))
                        .skinFace()
                        .frame(width: RunicSpacing.menuActionIconColumnWidth, alignment: .center)
                    Text(self.row.title.uppercased())
                        .font(RunicReceipt.mono(12, bold: true))
                        .skinFace()
                        .tracking(0.5)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    if let systemImage = self.row.systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 10, weight: .bold))
                            .opacity(0.8)
                    }
                }
                .foregroundStyle(self.isHovered ? RunicReceipt.ink : RunicReceipt.paper)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(self.isHovered ? RunicReceipt.paper : .clear))
                .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
            }
        }
    }
}

private struct ReceiptNote: View {
    let text: String
    let style: MenuDescriptor.TextStyle
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: RunicSpacing.menuActionIconColumnWidth, height: 1)
            Text(self.text)
                .font(RunicReceipt.mono(11, bold: self.style == .headline))
                .skinFace()
                .foregroundStyle(self.style == .secondary ? self.runicTheme.secondaryText : RunicReceipt.paper)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

/// A section title on the body: tracked bold caps in paper.
struct ReceiptLabel: View {
    let text: String
    var size: CGFloat = 11
    var color: Color = RunicReceipt.paper

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicReceipt.mono(self.size, bold: true))
            .skinFace()
            .tracking(2)
            .foregroundStyle(self.color)
            .lineLimit(1)
    }
}

// MARK: - Footer

/// The last line on the body: the edition, the author, and "?" for About.
private struct ReceiptFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(RunicSkinImprint.line.uppercased())
                .font(RunicReceipt.mono(10.5))
                .skinFace()
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Button {
                NSWorkspace.shared.open(RunicSkinImprint.authorURL)
            } label: {
                Text("BY \(RunicSkinImprint.author.uppercased())")
                    .font(RunicReceipt.mono(10.5, bold: true))
                    .skinFace()
                    .tracking(1)
                    .underline(self.isHovered)
                    .foregroundStyle(self.isHovered ? self.runicTheme.accent : RunicReceipt.paper)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { self.isHovered = $0 }
            .accessibilityLabel("by \(RunicSkinImprint.author), opens GitHub")
            ReceiptButton(title: "?", height: 26, action: self.context.openAbout)
                .accessibilityLabel("About Runic")
        }
        .skinFace()
        .frame(width: self.context.width)
        .padding(.top, RunicSpacing.xxs)
    }
}
