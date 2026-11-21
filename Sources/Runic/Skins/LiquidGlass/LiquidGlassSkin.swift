import AppKit
import RunicCore
import SwiftUI

/// Liquid Glass MK II — Clear Daylight and Smoked Obsidian Night. Pages:
/// `LiquidGlassProviderPage`, `LiquidGlassFrontPage`, `LiquidGlassResetsPage`.
/// Kit: `RunicLiquidGlassKit.swift`. The popover is live behind-window glass
/// under an optical veil; sections float as 14pt glass cards with a 3-pass
/// Fresnel rim, and every number sits in a matte recessed well.
struct LiquidGlassSkin: RunicSkin {
    static let skinID = "liquidglass"
    var id: String {
        Self.skinID
    }

    // MARK: Pages

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(LiquidGlassProviderPage(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(LiquidGlassFrontPage(view: view))
    }

    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView? {
        AnyView(LiquidGlassResetsPage(resets: resets))
    }

    // MARK: Chrome

    @MainActor func panel(_ content: AnyView) -> AnyView? {
        AnyView(LiquidGlassPanel(content: content))
    }

    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        AnyView(LiquidGlassTabStrip(items: items, width: width, onSelect: onSelect))
    }

    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView? {
        AnyView(LiquidGlassChip(chip: chip))
    }

    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView? {
        AnyView(LiquidGlassActionRow(row: row))
    }

    @MainActor func sectionHeader(_ text: String) -> AnyView? {
        AnyView(LiquidGlassSectionTitle(title: text))
    }

    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView? {
        AnyView(LiquidGlassNote(text: text, isHeadline: style == .headline))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(LiquidGlassFooter(context: context))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        RunicSkinPopoverChrome(
            cornerRadius: RunicLiquidGlass.popoverRadius,
            strokeWidth: 0.5,
            strokeColor: palette.cardStroke)
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        RunicLiquidGlass.panelInset
    }

    var showsTabTray: Bool {
        false
    }

    @MainActor func stageOverlay() -> AnyView? {
        AnyView(LiquidGlassStageRim())
    }
}

// MARK: - Stage

/// The popover's backdrop. Live: a behind-window material (`.popover` by
/// day, `.hudWindow` at night) under an optical tint veil (white 46 → 34 %
/// by day, #0D1118 54 → 46 % at night) over a light anchor of the surface,
/// so text stays crisp on any wallpaper. Reduce Transparency and offscreen
/// screenshot renders paint an opaque `surface → surfaceAlt` gradient
/// instead (with the veil's optical depth on top for screenshots).
///
/// `MenuPopoverBackground` mounts this for `LiquidGlassSkin.skinID` in place
/// of the opaque `menuSurfaceGradient`.
struct LiquidGlassStageBackground: View {
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let dark = self.colorScheme == .dark
        ZStack {
            if self.reduceTransparency {
                LinearGradient(
                    colors: [self.runicTheme.surface, self.runicTheme.surfaceAlt],
                    startPoint: .top,
                    endPoint: .bottom)
            } else if RunicLiquidGlass.isOffscreenRender {
                LinearGradient(
                    colors: [self.runicTheme.surface, self.runicTheme.surfaceAlt],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
                self.veil(dark: dark)
                self.depth(dark: dark)
            } else {
                LiquidGlassVisualEffect(material: dark ? .hudWindow : .popover)
                self.runicTheme.surface.opacity(0.24)
                self.veil(dark: dark)
                self.depth(dark: dark)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// L1 — the optical tint veil.
    private func veil(dark: Bool) -> some View {
        let tone = dark ? Color(red: 13 / 255, green: 17 / 255, blue: 24 / 255) : Color.white
        return LinearGradient(
            colors: [tone.opacity(dark ? 0.54 : 0.46), tone.opacity(dark ? 0.46 : 0.34)],
            startPoint: .top,
            endPoint: .bottom)
    }

    /// A faint sapphire caustic pooled at the top-left, where the light enters.
    private func depth(dark: Bool) -> some View {
        RadialGradient(
            colors: [self.runicTheme.accent.opacity(dark ? 0.10 : 0.06), .clear],
            center: .topLeading,
            startRadius: 4,
            endRadius: 360)
    }
}

/// `NSVisualEffectView` blending behind the window, always active.
struct LiquidGlassVisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = self.material
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.material = self.material
        nsView.blendingMode = .behindWindow
        nsView.state = .active
    }
}

/// The popover's own Fresnel rim, laid over the stage under the frame stroke.
private struct LiquidGlassStageRim: View {
    var body: some View {
        LiquidGlassFresnelRim(
            shape: RoundedRectangle(cornerRadius: RunicLiquidGlass.popoverRadius, style: .continuous),
            intensity: 0.85)
            .ignoresSafeArea()
    }
}

// MARK: - Panel

/// A section floats as a 14pt glass card with the Fresnel rim.
private struct LiquidGlassPanel: View {
    let content: AnyView

    var body: some View {
        self.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: RunicLiquidGlass.cardRadius, style: .continuous))
            .background(LiquidGlassCardBackground())
    }
}

// MARK: - Tabs

/// The provider strip as capsules: the chosen one is a floating glass pill
/// washed in sapphire; the rest sit quietly on the veil.
private struct LiquidGlassTabStrip: View {
    let items: [ProviderTabBarView.TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(self.items) { item in
                    LiquidGlassTab(item: item) { self.onSelect(item.provider) }
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

private struct LiquidGlassTab: View {
    let item: ProviderTabBarView.TabItem
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shape = Capsule(style: .continuous)
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
                    .font(RunicLiquidGlass.body(12, self.item.isSelected ? .semibold : .medium))
                    .skinFace()
                    .lineLimit(1)
            }
            .foregroundStyle(self.foreground)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background {
                if self.item.isSelected {
                    ZStack {
                        shape.fill(self.runicTheme.cardFill)
                        shape.fill(self.runicTheme.accent.opacity(0.14))
                        LiquidGlassFresnelRim(shape: shape)
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

// MARK: - Chip, rows, notes

private struct LiquidGlassChip: View {
    let chip: RunicSkinChip
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shape = Capsule(style: .continuous)
        Button(action: self.chip.action) {
            HStack(spacing: 6) {
                Image(systemName: self.chip.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: RunicSpacing.menuIconColumnWidth)
                    .accessibilityHidden(true)
                Text(self.chip.title)
                    .font(RunicLiquidGlass.body(11.5, self.chip.isSelected ? .semibold : .medium))
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
                    ZStack {
                        shape.fill(self.runicTheme.accent.opacity(0.14))
                        LiquidGlassFresnelRim(shape: shape)
                    }
                } else {
                    shape.fill(self.runicTheme.primaryText.opacity(self.isHovered ? 0.07 : 0.035))
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

private struct LiquidGlassActionRow: View {
    let row: RunicSkinActionRow
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.row.isCompact {
            LiquidGlassButton(title: self.row.title, systemImage: self.row.systemImage, action: self.row.action)
                .frame(maxWidth: .infinity)
        } else {
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
                        .font(RunicLiquidGlass.body(12.5, .medium))
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
                        Capsule(style: .continuous)
                            .fill(self.runicTheme.menuHoverFill)
                    }
                }
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
            }
        }
    }
}

private struct LiquidGlassNote: View {
    let text: String
    let isHeadline: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: RunicSpacing.menuActionIconColumnWidth, height: 1)
            Text(self.text)
                .font(self.isHeadline ? RunicLiquidGlass.body(12, .semibold) : RunicLiquidGlass.body(11.5))
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

// MARK: - Footer

/// The imprint on the veil: edition on the left, author and About on the right.
private struct LiquidGlassFooter: View {
    let context: RunicSkinFooterContext
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(RunicSkinImprint.line)
                .font(RunicLiquidGlass.numeric(10, .medium))
                .skinFace()
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Button {
                NSWorkspace.shared.open(RunicSkinImprint.authorURL)
            } label: {
                Text("by \(RunicSkinImprint.author)")
                    .font(RunicLiquidGlass.body(11, .semibold))
                    .skinFace()
                    .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { self.isHovered = $0 }
            .accessibilityLabel("by \(RunicSkinImprint.author), opens GitHub")
            LiquidGlassButton(title: "About", action: self.context.openAbout)
        }
        .padding(.horizontal, 6)
        .padding(.top, RunicSpacing.xxs)
        .frame(width: self.context.width)
    }
}
