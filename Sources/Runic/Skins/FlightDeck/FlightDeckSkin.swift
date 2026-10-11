import AppKit
import RunicCore
import SwiftUI

/// A primary flight display. Pages: `FlightDeckProviderPage`,
/// `FlightDeckFrontPage`, `FlightDeckResetsPage`. Kit:
/// `RunicFlightDeckKit.swift`. Every section is a bordered display area
/// on a near-black stage inside a 5pt frame; tabs are outlined mono
/// rectangles with a Zulu clock at the end of the strip.
struct FlightDeckSkin: RunicSkin {
    static let skinID = "flightdeck"
    var id: String {
        Self.skinID
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(FlightDeckProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(FlightDeckFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(FlightDeckResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(FlightDeckPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(FlightDeckTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(FlightDeckChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(FlightDeckActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(FlightDeckLabel(text: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(FlightDeckNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(FlightDeckFooter(context: context))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        // The stroke straddles the clip, so 10pt draws as the 5pt inner
        // frame of the display bezel.
        RunicSkinPopoverChrome(cornerRadius: 8, strokeWidth: 10, strokeColor: palette.surfaceAlt)
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        0
    }

    var showsTabTray: Bool {
        false
    }
}

// MARK: - Panel

/// A display area: a hairline-bordered rectangle on the stage.
private struct FlightDeckPanel: View {
    let content: AnyView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        self.content
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Rectangle().fill(self.runicTheme.cardFill))
            .overlay(Rectangle().stroke(self.runicTheme.cardStroke, lineWidth: 1))
    }
}

// MARK: - Tabs

/// Outlined mono rectangles: "ND" for the navigation display, each
/// provider as its callsign, the chosen one in cyan on an 8% wash, and the
/// Zulu clock at the trailing edge.
private struct FlightDeckTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(self.items) { item in
                        FlightDeckTab(item: item) { self.onSelect(item.provider) }
                    }
                }
                .padding(.vertical, 2)
            }
            Spacer(minLength: 4)
            TimelineView(.everyMinute) { context in
                Text(RunicFlightDeck.zulu(context.date))
                    .font(RunicFlightDeck.mono(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .accessibilityLabel("Zulu time \(RunicFlightDeck.zulu(context.date))")
            }
        }
        .frame(width: self.width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider tabs")
    }
}

private struct FlightDeckTab: View {
    let item: ProviderTabBarView.TabItem
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let cyan = self.runicTheme.accent
        let lit = self.item.isSelected || self.isHovered
        Button(action: self.action) {
            Text(self.label)
                .font(RunicFlightDeck.mono(10.5, self.item.isSelected ? .bold : .regular))
                .skinFace()
                .tracking(1.1)
                .lineLimit(1)
                .foregroundStyle(lit ? cyan : self.runicTheme.secondaryText)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(Rectangle().fill(self.item.isSelected ? cyan.opacity(0.08) : Color.clear))
                .overlay(Rectangle().stroke(lit ? cyan : self.runicTheme.cardStroke, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityLabel(self.item.label)
        .accessibilityAddTraits(self.item.isSelected ? [.isSelected] : [])
    }

    private var label: String {
        self.item.provider == nil ? "ND" : RunicFlightDeck.callsign(self.item.label)
    }
}

// MARK: - Chip, rows, notes

private struct FlightDeckChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let cyan = self.runicTheme.accent
        let lit = self.chip.isSelected || self.isHovered
        Button(action: self.chip.action) {
            HStack(spacing: 6) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                Text(self.chip.title.uppercased())
                    .font(RunicFlightDeck.mono(9.5, self.chip.isSelected ? .bold : .regular))
                    .skinFace()
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .foregroundStyle(lit ? cyan : self.runicTheme.primaryText)
            .background(Rectangle().fill(self.chip.isSelected ? cyan.opacity(0.08) : Color.clear))
            .overlay(Rectangle().stroke(lit ? cyan : self.runicTheme.cardStroke, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

private struct FlightDeckActionRow: View {
    let row: RunicSkinActionRow
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.row.isCompact {
            FlightDeckButton(title: self.row.title, systemImage: self.row.systemImage, action: self.row.action)
                .frame(maxWidth: .infinity)
        } else {
            let primary = self.row.title.lowercased().hasPrefix("ping")
            let cyan = self.runicTheme.accent
            Button(action: self.row.action) {
                HStack(spacing: 8) {
                    if let systemImage = self.row.systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: RunicSpacing.menuActionIconColumnWidth)
                    }
                    Text(self.title)
                        .font(RunicFlightDeck.mono(10.5, primary ? .bold : .regular))
                        .skinFace()
                        .tracking(RunicFlightDeck.tagTracking)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                }
                .foregroundStyle(primary
                    ? self.runicTheme.surface
                    : (self.isHovered ? cyan : self.runicTheme.primaryText))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Rectangle().fill(primary ? (self.isHovered ? cyan.opacity(0.85) : cyan) : Color.clear))
                .overlay(Rectangle().stroke(
                    primary || self.isHovered ? cyan : self.runicTheme.cardStroke,
                    lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .onHover { hovering in
                withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
            }
        }
    }

    /// "Ping now" reads as the PING button on the deck.
    private var title: String {
        let lower = self.row.title.lowercased()
        if lower.hasPrefix("ping") { return "PING" }
        return self.row.title.uppercased()
    }
}

private struct FlightDeckNote: View {
    let text: String
    let isHeadline: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text)
            .font(self.isHeadline ? RunicFlightDeck.sans(11, .bold) : RunicFlightDeck.mono(9.5))
            .skinFace()
            .foregroundStyle(self.isHeadline ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
    }
}

// MARK: - Footer

/// "RUNIC 2.10.1 · BUILD 156" on the left, the pilot in command on the
/// right, and a "?" for About.
private struct FlightDeckFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 8) {
            FlightDeckRule(color: self.runicTheme.cardStroke)
            HStack(alignment: .center, spacing: 8) {
                FlightDeckLabel(text: Self.imprint, size: 9, tracking: 1.1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button {
                    NSWorkspace.shared.open(RunicSkinImprint.authorURL)
                } label: {
                    Text("PIC: \(RunicSkinImprint.author.uppercased())")
                        .font(RunicFlightDeck.mono(9))
                        .skinFace()
                        .tracking(1.1)
                        .foregroundStyle(self.isHovered ? self.runicTheme.primaryText : self.runicTheme.accent)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { self.isHovered = $0 }
                .accessibilityLabel("Pilot in command \(RunicSkinImprint.author), opens GitHub")
                FlightDeckButton(title: "?", minWidth: 30, action: self.context.openAbout)
                    .scaleEffect(0.85, anchor: .trailing)
                    .accessibilityLabel("About Runic")
            }
        }
        .skinFace()
        .frame(width: self.context.width)
        .padding(.top, RunicSpacing.xxs)
    }

    /// "RUNIC 2.10.1 · BUILD 156" — the imprint re-set as a data plate.
    private static let imprint: String = {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "Runic \(RunicVersion.marketing) \u{00B7} Build \(build)"
        }
        return "Runic \(RunicVersion.marketing)"
    }()
}
