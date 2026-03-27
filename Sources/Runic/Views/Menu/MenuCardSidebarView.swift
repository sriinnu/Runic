import AppKit
import RunicCore
import SwiftUI

enum MenuCardSidebarMetrics {
    struct Style {
        let iconSize: CGFloat
        let buttonSize: CGFloat
        let spacing: CGFloat
        let padding: CGFloat
        let cornerRadius: CGFloat
        let barHeight: CGFloat
        let barInset: CGFloat

        var width: CGFloat {
            self.buttonSize + self.padding * 2
        }
    }

    private static func smallStyle() -> Style {
        Style(
            iconSize: 18,
            buttonSize: 26,
            spacing: RunicSpacing.compact,
            padding: RunicSpacing.xs,
            cornerRadius: 7,
            barHeight: 3,
            barInset: RunicSpacing.xxs)
    }

    private static func mediumStyle() -> Style {
        Style(
            iconSize: 22,
            buttonSize: 30,
            spacing: RunicSpacing.xs,
            padding: 10,
            cornerRadius: RunicCornerRadius.md,
            barHeight: 3,
            barInset: RunicSpacing.xxs)
    }

    static func style(for providerCount: Int, iconSize: ProviderSwitcherIconSize) -> Style {
        let needsCompact = providerCount >= 6
        if needsCompact || iconSize == .small {
            return self.smallStyle()
        }
        return self.mediumStyle()
    }

    static func sidebarWidth(for providerCount: Int, iconSize: ProviderSwitcherIconSize) -> CGFloat {
        self.style(for: providerCount, iconSize: iconSize).width
    }
}

struct ProviderSidebarMenuCardView<Content: View>: View {
    let providers: [UsageProvider]
    let selected: UsageProvider?
    let totalWidth: CGFloat
    let showIcons: Bool
    let iconSize: ProviderSwitcherIconSize
    let iconProvider: (UsageProvider, CGFloat) -> NSImage
    let weeklyRemainingProvider: (UsageProvider) -> Double?
    let onSelect: (UsageProvider) -> Void
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        let style = MenuCardSidebarMetrics.style(for: self.providers.count, iconSize: self.iconSize)
        let sidebarWidth = style.width
        let contentWidth = max(0, self.totalWidth - sidebarWidth)

        // Content is the primary view that determines the height.
        // The rail is placed as a background so its Rectangle fills
        // stretch to match the content height instead of expanding
        // to infinity during sizeThatFits measurement.
        self.content(contentWidth)
            .frame(width: contentWidth, alignment: .leading)
            .padding(.leading, sidebarWidth)
            .frame(width: self.totalWidth, alignment: .leading)
            .background(alignment: .topLeading) {
                ProviderSidebarRailView(
                    providers: self.providers,
                    selected: self.selected,
                    showIcons: self.showIcons,
                    style: style,
                    iconProvider: self.iconProvider,
                    weeklyRemainingProvider: self.weeklyRemainingProvider,
                    onSelect: self.onSelect)
                    .frame(width: sidebarWidth, alignment: .topLeading)
            }
    }
}

private struct ProviderSidebarRailView: View {
    let providers: [UsageProvider]
    let selected: UsageProvider?
    let showIcons: Bool
    let style: MenuCardSidebarMetrics.Style
    let iconProvider: (UsageProvider, CGFloat) -> NSImage
    let weeklyRemainingProvider: (UsageProvider) -> Double?
    let onSelect: (UsageProvider) -> Void

    @Environment(\.menuItemHighlighted) private var isHighlighted

    private var railBackground: LinearGradient {
        let base = Color(nsColor: .controlTextColor)
            .opacity(self.isHighlighted ? RunicColors.Opacity.subtle : RunicColors.Opacity.nano)
        return LinearGradient(
            colors: [base, base.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom)
    }

    private var railGloss: LinearGradient {
        let opacity = self.isHighlighted ? RunicColors.Opacity.light : RunicColors.Opacity.subtle
        return LinearGradient(
            colors: [Color.white.opacity(opacity), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(self.railBackground)
            Rectangle()
                .fill(self.railGloss)

            if self.showIcons {
                VStack(spacing: self.style.spacing) {
                    ForEach(self.providers, id: \.self) { provider in
                        ProviderSidebarIconButton(
                            provider: provider,
                            isSelected: provider == (self.selected ?? self.providers.first),
                            icon: self.iconProvider(provider, self.style.iconSize),
                            style: self.style,
                            remainingPercent: self.weeklyRemainingProvider(provider),
                            onSelect: { self.onSelect(provider) })
                    }
                }
                .padding(.top, MenuCardMetrics.headerTopPadding + 4)
                .padding(.bottom, MenuCardMetrics.tailPadding)
                .padding(.horizontal, self.style.padding)
            }

            Rectangle()
                .fill(Color(nsColor: .separatorColor)
                    .opacity(self.isHighlighted ? RunicColors.Opacity.emphasis : RunicColors.Opacity.strong))
                .frame(width: 1)
                .padding(.top, MenuCardMetrics.headerTopPadding + 4)
                .padding(.bottom, MenuCardMetrics.tailPadding)
        }
    }
}

private struct ProviderSidebarIconButton: View {
    let provider: UsageProvider
    let isSelected: Bool
    let icon: NSImage
    let style: MenuCardSidebarMetrics.Style
    let remainingPercent: Double?
    let onSelect: () -> Void

    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        Button(action: self.onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: self.style.cornerRadius, style: .continuous)
                    .fill(self.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: self.style.cornerRadius, style: .continuous)
                            .stroke(self.borderColor, lineWidth: self.isSelected ? 1 : 0))
                    .overlay(
                        RoundedRectangle(cornerRadius: self.style.cornerRadius, style: .continuous)
                            .fill(self.glossOverlay)
                            .opacity(self.isSelected ? 1 : 0.5))

                Image(nsImage: self.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: self.style.iconSize, height: self.style.iconSize)
                    .shadow(color: self.iconShadow, radius: self.isSelected ? 4 : 0, x: 0, y: 1)

                if let remainingPercent, !self.isSelected {
                    VStack {
                        Spacer(minLength: 0)
                        self.remainingBar(remainingPercent)
                    }
                    .padding(.bottom, self.style.barInset)
                }
            }
            .frame(width: self.style.buttonSize, height: self.style.buttonSize)
            .animation(RunicAnimation.highlight, value: self.isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ProviderDescriptorRegistry.descriptor(for: self.provider).metadata.displayName)
        .help(self.helpText)
    }

    private var backgroundColor: Color {
        guard self.isSelected else { return Color.clear }
        return self.brandColor.opacity(self.isHighlighted ? 0.32 : 0.22)
    }

    private var borderColor: Color {
        guard self.isSelected else { return Color.clear }
        return self.brandColor.opacity(self.isHighlighted ? 0.7 : 0.5)
    }

    private var iconShadow: Color {
        guard self.isSelected else { return Color.clear }
        return self.brandColor.opacity(self.isHighlighted ? 0.5 : 0.3)
    }

    private var brandColor: Color {
        let color = ProviderDescriptorRegistry.descriptor(for: self.provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private var glossOverlay: LinearGradient {
        let opacity = self.isSelected ? 0.28 : 0.12
        return LinearGradient(
            colors: [Color.white.opacity(opacity), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }

    private var helpText: String {
        let name = ProviderDescriptorRegistry.descriptor(for: self.provider).metadata.displayName
        guard let remainingPercent else { return name }
        let clamped = max(0, min(100, remainingPercent))
        let percentText = String(format: "%.0f%%", clamped)
        return "\(name) • Usage \(percentText)"
    }

    private func remainingBar(_ remainingPercent: Double) -> some View {
        let ratio = CGFloat(max(0, min(1, remainingPercent / 100)))
        let trackWidth = self.style.buttonSize - self.style.barInset * 2
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(nsColor: .tertiaryLabelColor).opacity(RunicColors.Opacity.strong))
            Capsule()
                .fill(self.brandColor)
                .frame(width: trackWidth * ratio)
        }
        .frame(width: trackWidth, height: self.style.barHeight)
    }
}
