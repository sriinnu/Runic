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
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 13, weight: .medium))
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
                        .foregroundStyle(tab.isSelected ? selectedColor : self.runicTheme.secondaryText)
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
