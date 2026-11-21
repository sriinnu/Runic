import AppKit
import RunicCore
import SwiftUI

/// Matte ceramic hardware in the Braun manner. Pages: `ReliefProviderPage`,
/// `ReliefFrontPage`, `ReliefResetsPage`. Kit: `RunicReliefKit.swift`.
/// Every section is a raised plinth on a warm alabaster chassis, lit from
/// the top left; gauges are machined troughs; tabs and chips are keycaps
/// with LED pips; the chosen key is pressed into the chassis.
struct ReliefSkin: RunicSkin {
    static let skinID = "relief"
    var id: String {
        Self.skinID
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(ReliefProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(ReliefFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(ReliefResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(ReliefPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(ReliefTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(ReliefChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(ReliefActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(ReliefLabel(text: text).padding(.leading, 2))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(ReliefNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(ReliefFooter(context: context))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        RunicSkinPopoverChrome(cornerRadius: 16, strokeWidth: 0.5, strokeColor: palette.cardStroke.opacity(0.9))
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        12
    }

    var showsTabTray: Bool {
        false
    }

    @MainActor func stageOverlay() -> AnyView? {
        AnyView(ReliefChassisBevel())
    }
}

// MARK: - Panel

/// A section as a raised ceramic plinth.
private struct ReliefPanel: View {
    let content: AnyView

    var body: some View {
        self.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .reliefPlinth()
    }
}

// MARK: - Stage

/// The chassis edge: a lit top-left rim and a shaded bottom-right rim
/// inside the popover frame, so the whole panel reads as one machined
/// housing.
private struct ReliefChassisBevel: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: RunicRelief.specular.opacity(0.9), location: 0),
                        .init(color: RunicRelief.specular.opacity(0), location: 0.35),
                        .init(color: self.runicTheme.primaryText.opacity(0), location: 0.7),
                        .init(color: self.runicTheme.primaryText.opacity(0.10), location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                lineWidth: 1.5)
            .padding(0.5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Tabs

/// The provider strip as a row of keycaps on the chassis. The chosen key
/// is pressed in and its LED lit; the others rest raised with a dark pip.
private struct ReliefTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(self.items) { item in
                    ReliefTab(item: item) { self.onSelect(item.provider) }
                }
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 6)
        }
        .frame(minWidth: self.width, maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider tabs")
    }
}

private struct ReliefTab: View {
    let item: ProviderTabBarView.TabItem
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 6) {
                ReliefLED(color: RunicRelief.signal, isLit: self.item.isSelected, size: 6)
                if self.item.provider == nil {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(self.item.label)
                    .font(RunicRelief.face(11.5, self.item.isSelected ? .semibold : .medium))
                    .skinFace()
                    .lineLimit(1)
            }
            .foregroundStyle(self.item.isSelected ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(ReliefKeycapBackground(isPressed: self.item.isSelected, isHovered: self.isHovered))
            .contentShape(RoundedRectangle(cornerRadius: RunicRelief.keyRadius, style: .continuous))
        }
        .buttonStyle(ReliefPressStyle())
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityLabel(self.item.label)
        .accessibilityAddTraits(self.item.isSelected ? [.isSelected] : [])
    }
}

// MARK: - Chip, rows, notes

/// An Explore chip as a keycap: icon, title, and an LED that lights when
/// the panel is open.
private struct ReliefChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.chip.action) {
            HStack(spacing: 6) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 14)
                Text(self.chip.title)
                    .font(RunicRelief.face(11, self.chip.isSelected ? .semibold : .medium))
                    .skinFace()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                ReliefLED(color: RunicRelief.signal, isLit: self.chip.isSelected, size: 5)
            }
            .foregroundStyle(self.chip.isSelected ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReliefKeycapBackground(isPressed: self.chip.isSelected, isHovered: self.isHovered))
            .contentShape(RoundedRectangle(cornerRadius: RunicRelief.keyRadius, style: .continuous))
        }
        .buttonStyle(ReliefPressStyle())
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityAddTraits(self.chip.isSelected ? [.isSelected] : [])
    }
}

/// An action row: a small keycap holding the icon, the title beside it,
/// and a raised wash under the whole row on hover. Compact rows (CSV) are
/// plain keycap buttons.
private struct ReliefActionRow: View {
    let row: RunicSkinActionRow
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.row.isCompact {
            ReliefButton(title: self.row.title, systemImage: self.row.systemImage, action: self.row.action)
                .frame(maxWidth: .infinity)
        } else {
            Button(action: self.row.action) {
                HStack(spacing: 10) {
                    ZStack {
                        ReliefKeycapBackground(isPressed: false, isHovered: self.isHovered, radius: 5)
                        if let systemImage = self.row.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText)
                        }
                    }
                    .frame(width: 22, height: 22)
                    Text(self.row.title)
                        .font(RunicRelief.face(12.5, .medium))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(self.runicTheme.primaryText.opacity(self.isHovered ? 0.05 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ReliefPressStyle())
            .onHover { hovering in
                withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
            }
        }
    }
}

private struct ReliefNote: View {
    let text: String
    let isHeadline: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 22, height: 1)
            Text(self.text)
                .font(RunicRelief.face(self.isHeadline ? 12 : 11, self.isHeadline ? .semibold : .regular))
                .skinFace()
                .foregroundStyle(self.isHeadline ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}

// MARK: - Footer

/// The data plate: the edition engraved on the left, the maker's mark and
/// an About key on the right, under an engraved groove.
private struct ReliefFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 10) {
            ReliefGroove()
            HStack(alignment: .center, spacing: 8) {
                ReliefLED(color: RunicRelief.ledGreen, size: 6)
                ReliefLabel(text: RunicSkinImprint.line, size: 9, tracking: 1.1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button {
                    NSWorkspace.shared.open(RunicSkinImprint.authorURL)
                } label: {
                    Text("by \(RunicSkinImprint.author)")
                        .font(RunicRelief.face(11, .semibold))
                        .skinFace()
                        .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.secondaryText)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { self.isHovered = $0 }
                .accessibilityLabel("by \(RunicSkinImprint.author), opens GitHub")
                ReliefButton(title: "About", action: self.context.openAbout)
                    .scaleEffect(0.9, anchor: .trailing)
            }
        }
        .skinFace()
        .frame(width: self.context.width)
        .padding(.top, RunicSpacing.xxs)
    }
}
