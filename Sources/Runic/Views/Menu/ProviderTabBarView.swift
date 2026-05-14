import AppKit
import RunicCore
import SwiftUI

/// Horizontal provider tab bar at the top of the menu dropdown — inspired by CodexBar.
/// Uses actual provider brand icons (SVG) with brand colors from the descriptor registry.
@MainActor
struct ProviderTabBarView: View {
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
            HStack(spacing: RunicSpacing.compact) {
                ForEach(self.tabs) { tab in
                    let selectedColor = self.runicTheme.isTerminalHUD ? self.runicTheme.accent : tab.brandColor
                    Button {
                        self.onSelect(tab.provider)
                    } label: {
                        HStack(spacing: RunicSpacing.xxs) {
                            if let nsImage = tab.icon {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                            } else if tab.provider == nil {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            Text(tab.label)
                                .font(RunicFont.caption)
                                .fontWeight(tab.isSelected ? .semibold : .regular)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, RunicSpacing.xs + 2)
                        .padding(.vertical, RunicSpacing.xxs + 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(tab.isSelected
                                    ? selectedColor.opacity(self.runicTheme.isTerminalHUD ? 0.20 : RunicColors.Opacity.medium)
                                    : self.runicTheme.menuSubtleFill))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    tab.isSelected
                                        ? selectedColor.opacity(self.runicTheme.isTerminalHUD ? 0.72 : RunicColors.Opacity.strong)
                                        : self.runicTheme.cardStroke.opacity(RunicColors.Opacity.medium),
                                    lineWidth: self.runicTheme.isTerminalHUD ? 0.9 : 0.5))
                        .foregroundStyle(tab.isSelected ? selectedColor : self.runicTheme.secondaryText)
                        .shadow(
                            color: tab.isSelected ? selectedColor.opacity(self.runicTheme.isTerminalHUD ? 0.28 : 0.15) : .clear,
                            radius: self.runicTheme.isTerminalHUD ? 6 : 4, y: 1)
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
                    RunicTerminalScanlineOverlay(opacity: 0.80)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider tabs")
    }
}

/// Button style with subtle hover scale feedback.
private struct TabButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : (self.isHovered ? 1.03 : 1.0))
            .animation(RunicAnimation.hoverFeedback, value: configuration.isPressed)
            .animation(RunicAnimation.hoverFeedback, value: self.isHovered)
            .onHover { self.isHovered = $0 }
    }
}
