import AppKit
import RunicCore
import SwiftUI

/// A 1970s bench instrument in cream enamel. Pages: `InstrumentProviderPage`,
/// `InstrumentFrontPage`, `InstrumentResetsPage`. Kit: `RunicInstrumentKit.swift`.
/// Sections sit on the enamel and close with an engraved groove; the tab
/// strip is a row of keycaps with the PWR and LINK lamps; the popover has an
/// inner bevel and a screw in each corner.
struct InstrumentSkin: RunicSkin {
    static let skinID = "instrument"
    var id: String {
        Self.skinID
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(InstrumentProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(InstrumentFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(InstrumentResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(InstrumentPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(InstrumentTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(InstrumentChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(InstrumentActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(InstrumentEngraved(text: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(InstrumentNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(InstrumentFooter(context: context))
    }

    func popoverChrome(for _: RunicThemePalette) -> RunicSkinPopoverChrome? {
        RunicSkinPopoverChrome(cornerRadius: 10, strokeWidth: 1, strokeColor: RunicInstrument.Paint.bezel)
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        RunicSpacing.xxs
    }

    var showsTabTray: Bool {
        false
    }

    @MainActor func stageOverlay() -> AnyView? {
        AnyView(InstrumentStage())
    }
}

// MARK: - Stage

/// The enamel's inner bevel — a 3pt cream ring inside the bezel and a 1pt
/// darker line inside that — and a slotted screw in each corner.
private struct InstrumentStage: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(RunicInstrument.Paint.keyTop, lineWidth: 3)
                .padding(1)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(RunicInstrument.Paint.bevelInner, lineWidth: 1)
                .padding(4)
            VStack {
                HStack {
                    InstrumentScrew(slotAngle: 28)
                    Spacer()
                    InstrumentScrew(slotAngle: -16)
                }
                Spacer()
                HStack {
                    InstrumentScrew(slotAngle: 72)
                    Spacer()
                    InstrumentScrew(slotAngle: 8)
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Panel

/// A section sits straight on the enamel and closes with a groove.
private struct InstrumentPanel: View {
    let content: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.content
                .padding(.bottom, 10)
            InstrumentGroove()
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tabs

/// The provider strip as a row of keycaps — the chosen one pressed — with
/// the PWR and LINK lamps at the right.
private struct InstrumentTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void

    var body: some View {
        // The lamps keep a fixed slot at the right; the keys scroll in what
        // is left. A horizontal ScrollView settles at its content width
        // inside a stack, so its width is set outright.
        let lampSlot: CGFloat = 84
        HStack(alignment: .center, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 8) {
                    ForEach(self.items) { item in
                        InstrumentKey(
                            title: item.label,
                            systemImage: item.provider == nil ? "square.grid.2x2" : nil,
                            pressed: item.isSelected,
                            horizontalPadding: 11)
                        {
                            self.onSelect(item.provider)
                        }
                    }
                }
                .padding(.leading, 2)
                .padding(.trailing, 6)
                .padding(.vertical, 4)
            }
            .frame(width: max(0, self.width - lampSlot))
            HStack(spacing: 8) {
                InstrumentLampLabel(lamp: .red, text: "PWR", size: 7.5, ledSize: 8)
                InstrumentLampLabel(lamp: .green, text: "LINK", size: 7.5, ledSize: 8)
            }
            .frame(width: lampSlot, alignment: .trailing)
            .padding(.trailing, 2)
            .accessibilityHidden(true)
        }
        .frame(width: self.width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider tabs")
    }
}

// MARK: - Chip, rows, notes

/// A small keycap; the chosen one is pressed.
private struct InstrumentChip: View {
    let chip: RunicSkinChip

    var body: some View {
        InstrumentKeycap(pressed: self.chip.isSelected, height: 24, horizontalPadding: 9, action: self.chip.action) {
            HStack(spacing: 6) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                Text(self.chip.title.uppercased())
                    .font(RunicInstrument.key(9.5))
                    .skinFace()
                    .tracking(1.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Every action is a keycap; Ping — the one that talks to the provider —
/// is the orange primary.
private struct InstrumentActionRow: View {
    let row: RunicSkinActionRow

    var body: some View {
        let isPrimary = self.row.title.lowercased().hasPrefix("ping")
            || self.row.title.lowercased().hasPrefix("update ready")
        HStack(spacing: 0) {
            InstrumentKey(
                title: self.row.title,
                systemImage: isPrimary ? "arrow.clockwise" : self.row.systemImage,
                variant: isPrimary ? .orange : .cream,
                height: self.row.isCompact ? 26 : 30,
                size: self.row.isCompact ? 10 : 11,
                horizontalPadding: self.row.isCompact ? 10 : 14,
                action: self.row.action)
            if !self.row.isCompact {
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InstrumentNote: View {
    let text: String
    let isHeadline: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if self.isHeadline {
                InstrumentEngraved(text: self.text)
                    .minimumScaleFactor(0.8)
            } else {
                Text(self.text)
                    .font(RunicInstrument.copy(11.5))
                    .skinFace()
                    .foregroundStyle(RunicInstrument.Paint.engrave)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
    }
}

// MARK: - Footer

/// The nameplate: "RUNIC · TYPE 2.10.1", "SER. NO. 000156", "MADE BY
/// SRIINNU" (the author's link) and the "?" key for About.
private struct InstrumentFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        // Tracked caps truncate rather than scale, so each plate keeps its
        // ideal width and the spacers take what is left.
        HStack(alignment: .center, spacing: 8) {
            InstrumentEngraved(text: "Runic \u{00B7} Type \(RunicVersion.marketing)", size: 9, tracking: 1.8)
                .fixedSize()
            Spacer(minLength: 4)
            InstrumentEngraved(text: "Ser. No. \(RunicInstrument.serial ?? "------")", size: 9, tracking: 1.8)
                .fixedSize()
            Spacer(minLength: 4)
            Button {
                NSWorkspace.shared.open(RunicSkinImprint.authorURL)
            } label: {
                InstrumentEngraved(
                    text: "Made by \(RunicSkinImprint.author)",
                    size: 9,
                    color: self.isHovered ? self.runicTheme.accent : self.runicTheme.tertiary,
                    tracking: 1.8)
                    .fixedSize()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { self.isHovered = $0 }
            .accessibilityLabel("Made by \(RunicSkinImprint.author), opens GitHub")
            InstrumentKey(title: "?", height: 24, size: 10, horizontalPadding: 9, action: self.context.openAbout)
                .accessibilityLabel("About Runic")
        }
        .skinFace()
        .frame(width: self.context.width)
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }
}
