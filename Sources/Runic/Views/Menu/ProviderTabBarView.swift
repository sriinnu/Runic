import AppKit
import RunicCore
import SwiftUI

/// Horizontal provider tab bar at the top of the menu dropdown — inspired by CodexBar.
/// Uses actual provider brand icons (SVG) with brand colors from the descriptor registry.
@MainActor
struct ProviderTabBarView: View {
    @Environment(\.runicFonts) private var fonts
    struct TabItem: Identifiable {
        let id: String
        let label: String
        let icon: NSImage?
        let provider: UsageProvider?
        let isSelected: Bool
        let brandColor: Color
    }

    let tabs: [TabItem]
    let width: CGFloat
    let onSelect: (UsageProvider?) -> Void
    @Environment(\.runicTheme) private var runicTheme
    @State private var contentFrame: CGRect = .zero
    @State private var containerWidth: CGFloat = 0

    private static let edgeFadeWidth: CGFloat = 20

    /// Content extends past the leading edge (user has scrolled right).
    private var hasLeadingOverflow: Bool {
        self.contentFrame.minX < -1
    }

    /// Content extends past the trailing edge (more tabs offscreen).
    private var hasTrailingOverflow: Bool {
        self.containerWidth > 0 && self.contentFrame.maxX > self.containerWidth + 1
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RunicSpacing.xxs) {
                ForEach(self.tabs) { tab in
                    let selectedColor = self.runicTheme.isTerminalHUD ? self.runicTheme.accent : tab.brandColor
                    Button {
                        self.onSelect(tab.provider)
                    } label: {
                        HStack(spacing: self.runicTheme.isTerminalHUD ? RunicSpacing.xxs : 5) {
                            if self.runicTheme.isTerminalHUD {
                                Text("▶")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(self.runicTheme.accent)
                                    .opacity(tab.isSelected ? 1 : 0)
                                    .frame(width: 9)
                            }
                            if let nsImage = tab.icon {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                            } else if tab.provider == nil {
                                RunicThemedSystemIcon(
                                    systemName: "square.grid.2x2",
                                    intent: .navigation,
                                    selected: tab.isSelected,
                                    font: .system(size: 13, weight: .medium),
                                    width: 18)
                            }
                            Text(tab.label)
                                .font(self.fonts.caption2)
                                .fontWeight(tab.isSelected ? .semibold : .regular)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, RunicSpacing.compact)
                        .padding(.vertical, RunicSpacing.xxs + 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(self.tabBackgroundFill(selectedColor: selectedColor, isSelected: tab.isSelected)))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    self.tabStrokeColor(selectedColor: selectedColor, isSelected: tab.isSelected),
                                    lineWidth: self.tabStrokeWidth(isSelected: tab.isSelected)))
                        .foregroundStyle(self.runicTheme.isTerminalHUD
                            ? self.terminalForegroundStyle(for: tab)
                            : self.standardForegroundStyle(for: tab))
                        .shadow(
                            color: self.tabGlowColor(selectedColor: selectedColor, isSelected: tab.isSelected),
                            radius: self.tabGlowRadius(isSelected: tab.isSelected),
                            y: 1)
                    }
                    .buttonStyle(TabButtonStyle())
                }
            }
            .padding(.horizontal, MenuCardMetrics.horizontalPadding)
            .padding(.vertical, RunicSpacing.xs)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TabBarContentFramePreferenceKey.self,
                        value: proxy.frame(in: .named("runicProviderTabBarScroll")))
                })
        }
        .coordinateSpace(name: "runicProviderTabBarScroll")
        .onPreferenceChange(TabBarContentFramePreferenceKey.self) { frame in
            self.contentFrame = frame
        }
        .mask(self.overflowFadeMask)
        .overlay(alignment: .trailing) {
            if self.hasTrailingOverflow {
                self.overflowChevron(systemName: "chevron.compact.right")
            }
        }
        .overlay(alignment: .leading) {
            if self.hasLeadingOverflow {
                self.overflowChevron(systemName: "chevron.compact.left")
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TabBarContainerWidthPreferenceKey.self,
                    value: proxy.size.width)
            })
        .onPreferenceChange(TabBarContainerWidthPreferenceKey.self) { width in
            self.containerWidth = width
        }
        .frame(minWidth: self.width, maxWidth: .infinity)
        .background {
            ZStack {
                self.runicTheme.menuSurfaceGradient
                if self.runicTheme.isTerminalHUD {
                    RunicTerminalScanlineOverlay(opacity: self.runicTheme.style.effects.scanlineOpacity)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider tabs")
    }

    /// Fades the clipped edge(s) so offscreen tabs are discoverable.
    private var overflowFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [self.hasLeadingOverflow ? .clear : .black, .black],
                startPoint: .leading,
                endPoint: .trailing)
                .frame(width: Self.edgeFadeWidth)
            Rectangle().fill(.black)
            LinearGradient(
                colors: [.black, self.hasTrailingOverflow ? .clear : .black],
                startPoint: .leading,
                endPoint: .trailing)
                .frame(width: Self.edgeFadeWidth)
        }
    }

    private func overflowChevron(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(self.runicTheme.secondaryText)
            .padding(.horizontal, RunicSpacing.xxxs)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Glass-flavoured glow halos for tab capsules. Terminal stays solid,
    /// glow themes (Glass / Dark) get heavy neon, others stay subtle.
    private func tabBackgroundFill(selectedColor: Color, isSelected: Bool) -> Color {
        if isSelected {
            if self.runicTheme.isTerminalHUD {
                return selectedColor.opacity(0.22)
            }
            if self.runicTheme.shape.separator == .glow {
                return selectedColor.opacity(0.30)
            }
            return selectedColor.opacity(RunicColors.Opacity.medium)
        }
        return self.runicTheme.menuSubtleFill
    }

    private func tabStrokeWidth(isSelected: Bool) -> CGFloat {
        if self.runicTheme.isTerminalHUD { return self.runicTheme.style.chrome.borderWeight }
        if self.runicTheme.shape.separator == .glow { return isSelected ? 1.0 : 0.5 }
        return self.runicTheme.style.chrome.borderWeight
    }

    private func tabStrokeColor(selectedColor: Color, isSelected: Bool) -> Color {
        guard isSelected else {
            return self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity * 0.65)
        }
        if self.runicTheme.isTerminalHUD { return selectedColor.opacity(0.60) }
        if self.runicTheme.shape.separator == .glow { return selectedColor.opacity(0.82) }
        return selectedColor.opacity(RunicColors.Opacity.strong)
    }

    private func tabGlowColor(selectedColor: Color, isSelected: Bool) -> Color {
        guard isSelected else { return .clear }
        if self.runicTheme.isTerminalHUD { return selectedColor.opacity(0.14) }
        if self.runicTheme.shape.separator == .glow {
            return selectedColor.opacity(self.runicTheme.style.effects.glowStrength)
        }
        return selectedColor.opacity(0.15)
    }

    private func tabGlowRadius(isSelected: Bool) -> CGFloat {
        guard isSelected else { return 0 }
        if self.runicTheme.isTerminalHUD { return 3 }
        if self.runicTheme.shape.separator == .glow { return 8 }
        return 4
    }

    private func terminalForegroundStyle(for tab: TabItem) -> Color {
        tab.isSelected ? self.runicTheme.accent : self.runicTheme.primaryText.opacity(0.68)
    }

    private func standardForegroundStyle(for tab: TabItem) -> Color {
        tab.isSelected ? self.runicTheme.primaryText : self.runicTheme.primaryText.opacity(0.66)
    }
}

private struct TabBarContentFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct TabBarContainerWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Button style with subtle hover scale feedback.
private struct TabButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(self.reduceMotion ? 1 : (configuration.isPressed ? 0.95 : (self.isHovered ? 1.03 : 1.0)))
            .animation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion), value: configuration.isPressed)
            .animation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion), value: self.isHovered)
            .onHover { self.isHovered = $0 }
    }
}
