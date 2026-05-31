import AppKit
import RunicCore
import SwiftUI

struct ThemeChoiceButton: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let palette = self.theme.palette
        Button(action: self.action) {
            HStack(spacing: RunicSpacing.xs) {
                ThemeSwatch(palette: palette, isSelected: self.isSelected)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(palette.displayName)
                        .font(self.fonts.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(palette.tagline)
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xs)
            .frame(minHeight: 50, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                    .fill(self.isSelected ? palette.accent.opacity(0.14) : Color.primary.opacity(0.035)))
            .overlay(
                RoundedRectangle(cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                    .stroke(
                        self.isSelected ? palette.accent.opacity(0.72) : Color.primary.opacity(0.08),
                        lineWidth: self.isSelected ? 1.3 : 0.7))
        }
        .buttonStyle(.plain)
        .help(palette.displayName)
    }
}

private struct ThemeSwatch: View {
    @Environment(\.runicFonts) private var fonts
    let palette: RunicThemePalette
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .fill(palette.surfaceBackgroundStyle)
            HStack(spacing: 3) {
                ForEach(Array(palette.swatchColors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 5)
            Image(systemName: palette.symbolName)
                .font(self.fonts.caption.weight(.bold))
                .foregroundStyle(palette.primaryText)
                .shadow(color: .black.opacity(0.22), radius: 1, x: 0, y: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .stroke(self.isSelected ? palette.highlight : palette.menuSeparatorColor, lineWidth: 1))
    }
}

struct AppearancePreviewCard: View {
    @Environment(\.runicFonts) private var fonts
    let theme: Theme
    let fontFamily: String
    let providers: [UsageProvider]

    var body: some View {
        let palette = self.theme.palette
        let selectedProvider = self.previewProviders.first ?? .codex
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(spacing: RunicSpacing.xxs) {
                self.providerChip(
                    title: "Overview",
                    systemImage: "square.grid.2x2",
                    tint: palette.secondary,
                    isSelected: false)
                self.providerChip(
                    title: self.providerLabel(selectedProvider),
                    provider: selectedProvider,
                    tint: self.providerColor(selectedProvider),
                    isSelected: true)
                Spacer(minLength: 0)
            }

            self.themedSeparator(palette: palette)

            HStack(spacing: RunicSpacing.sm) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.md),
                        style: .continuous)
                        .fill(palette.menuSubtleFill)
                    if let icon = ProviderBrandIcon.image(for: selectedProvider, size: 24) {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.md),
                        style: .continuous)
                        .stroke(palette.menuSeparatorColor, lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.providerLabel(selectedProvider))
                        .font(self.previewValueFont(size: 13, weight: .bold, palette: palette))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)
                    Text("\(palette.displayName) · \(self.fontLabel)")
                        .font(self.previewValueFont(size: 11, weight: .regular, palette: palette))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                    Text("Top model · 42M tokens · 118 req")
                        .font(self.previewValueFont(size: 10, weight: .regular, palette: palette))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer()

                Text("Pro")
                    .font(self.previewValueFont(size: 11, weight: .semibold, palette: palette))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, RunicSpacing.xs)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(palette.accent.opacity(0.22)))
            }
            .padding(palette.density.padding(RunicSpacing.xs))
            .background(
                RoundedRectangle(
                    cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.md),
                    style: .continuous)
                    .fill(palette.cardBackgroundStyle))
            .overlay(
                RoundedRectangle(
                    cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.md),
                    style: .continuous)
                    .stroke(palette.menuSeparatorColor, lineWidth: 1))

            HStack(spacing: RunicSpacing.xs) {
                self.metricPreview(title: "Session", value: "42%", color: palette.accent, fill: 0.42)
                self.metricPreview(title: "Weekly", value: "71%", color: palette.highlight, fill: 0.71)
            }

            VStack(spacing: 0) {
                self.actionPreviewRow(title: "Usage timeline", systemImage: "chart.xyaxis.line")
                self.actionPreviewRow(title: "Models", systemImage: "square.stack.3d.up")
            }
            .padding(.top, 1)
        }
        .padding(palette.density.padding(RunicSpacing.sm))
        .background(
            RoundedRectangle(
                cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.md),
                style: .continuous)
                .fill(palette.surfaceBackgroundStyle))
        .overlay(
            RoundedRectangle(
                cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.md),
                style: .continuous)
                .stroke(palette.menuSeparatorColor, lineWidth: 1))
        .runicColorScheme(palette)
    }

    private var previewProviders: [UsageProvider] {
        self.providers.isEmpty ? [.codex, .claude, .gemini, .vercelai] : self.providers
    }

    private var fontLabel: String {
        RunicFontChoice.displayName(for: self.previewFamily)
    }

    private var previewFamily: String {
        RunicFontChoice.resolvedThemeFamily(self.theme.palette.style.typography.bodyFamily) ?? self.fontFamily
    }

    /// Theme-faithful divider for the preview tile — same branching as
    /// `RunicDivider`, but reads the *previewed* palette rather than the
    /// current-app palette via @Environment.
    @ViewBuilder
    private func themedSeparator(palette: RunicThemePalette) -> some View {
        switch palette.shape.separator {
        case .ascii:
            Text(String(repeating: "─", count: 96))
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(palette.menuSeparatorColor.opacity(0.55))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
        case .glow:
            Rectangle()
                .fill(LinearGradient(
                    colors: [
                        .clear,
                        palette.accent.opacity(0.48),
                        palette.highlight.opacity(0.36),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing))
                .frame(height: 1)
                .shadow(color: palette.accent.opacity(0.28), radius: 3.5)
        case .hairline:
            Rectangle()
                .fill(palette.menuSeparatorColor.opacity(0.65))
                .frame(height: 1)
        }
    }

    /// Font for value text in the preview, picking up the theme's font design
    /// (Commit Mono for Terminal, rounded for Daybreak, selected family elsewhere).
    private func previewValueFont(size: CGFloat, weight: Font.Weight, palette: RunicThemePalette) -> Font {
        let family = RunicFontChoice.resolvedThemeFamily(palette.style.typography.bodyFamily) ?? self.fontFamily
        if self.usesVirtualSystemFamily(family), let design = palette.fonts.swiftUIDesignOverride {
            return .system(size: size * palette.style.typography.scale, weight: weight, design: design)
        }
        return RunicFont.previewFont(for: family, size: size * palette.style.typography.scale).weight(weight)
    }

    private func usesVirtualSystemFamily(_ family: String) -> Bool {
        [
            RunicFontChoice.sfPro.id,
            RunicFontChoice.sfMono.id,
            RunicFontChoice.sfRounded.id,
            RunicFontChoice.newYork.id,
        ].contains(family)
    }

    private func metricPreview(title: String, value: String, color: Color, fill: CGFloat) -> some View {
        let palette = self.theme.palette
        return VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
            HStack {
                Text(title)
                    .font(self.previewValueFont(size: 11, weight: .regular, palette: palette))
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Text(value)
                    .font(self.previewValueFont(size: 11, weight: .semibold, palette: palette))
                    .foregroundStyle(palette.primaryText)
            }

            if palette.isTerminalHUD {
                let segmentCount = 18
                let filled = max(1, min(segmentCount, Int(ceil(fill * CGFloat(segmentCount)))))
                HStack(spacing: 2) {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(index < filled ? color : palette.menuTrackColor.opacity(0.78))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 6)
            } else {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(palette.menuTrackColor)
                        Capsule(style: .continuous)
                            .fill(color)
                            .frame(width: max(8, proxy.size.width * min(max(fill, 0), 1)))
                            .shadow(
                                color: palette.shape.separator == .glow ? color.opacity(0.55) : .clear,
                                radius: 4)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(palette.density.padding(RunicSpacing.xs))
        .background(
            RoundedRectangle(
                cornerRadius: self.theme.palette.shape.cornerRadius(RunicCornerRadius.sm),
                style: .continuous)
                .fill(self.theme.palette.menuSubtleFill))
        .overlay(
            RoundedRectangle(
                cornerRadius: self.theme.palette.shape.cornerRadius(RunicCornerRadius.sm),
                style: .continuous)
                .stroke(self.theme.palette.menuSeparatorColor.opacity(0.72), lineWidth: 0.7))
    }

    private func providerChip(
        title: String,
        systemImage: String? = nil,
        provider: UsageProvider? = nil,
        tint: Color,
        isSelected: Bool)
        -> some View
    {
        HStack(spacing: 5) {
            if let provider, let icon = ProviderBrandIcon.image(for: provider, size: 14) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            } else if let systemImage {
                RunicThemedSystemIcon(
                    systemName: systemImage,
                    intent: .navigation,
                    selected: isSelected,
                    font: self.previewValueFont(size: 11, weight: .semibold, palette: self.theme.palette),
                    palette: self.theme.palette)
            }
            Text(title)
                .font(self.previewValueFont(size: 11, weight: .semibold, palette: self.theme.palette))
                .foregroundStyle(isSelected ? self.theme.palette.primaryText : self.theme.palette.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(isSelected ? tint.opacity(0.24) : self.theme.palette.menuSubtleFill))
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    isSelected ? tint.opacity(0.55) : self.theme.palette.menuSeparatorColor.opacity(0.45),
                    lineWidth: 0.7))
    }

    private func actionPreviewRow(title: String, systemImage: String) -> some View {
        HStack(spacing: RunicSpacing.xs) {
            RunicThemedSystemIcon(
                systemName: systemImage,
                intent: .navigation,
                font: self.previewValueFont(size: 11, weight: .semibold, palette: self.theme.palette),
                width: 16,
                palette: self.theme.palette)
            Text(title)
                .font(self.previewValueFont(size: 11, weight: .semibold, palette: self.theme.palette))
                .foregroundStyle(self.theme.palette.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(self.previewValueFont(size: 10, weight: .semibold, palette: self.theme.palette))
                .foregroundStyle(self.theme.palette.secondaryText)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(self.theme.palette.menuSeparatorColor.opacity(0.55))
                .frame(height: 0.7)
        }
    }

    private func providerColor(_ provider: UsageProvider) -> Color {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private func providerLabel(_ provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
    }
}

struct TypographyRulesPreview: View {
    @Environment(\.runicFonts) private var fonts
    let fontFamily: String
    let theme: Theme
    @Environment(\.runicTheme) private var runicTheme

    private var rules: RunicFontRules {
        RunicFontRules.rules(for: self.previewFamily)
            .applying(self.theme.palette.style.typography)
    }

    private var previewFamily: String {
        RunicFontChoice.resolvedThemeFamily(self.theme.palette.style.typography.bodyFamily) ?? self.fontFamily
    }

    private var tone: RunicBackgroundTone {
        self.theme.palette.prefersDarkAppearance == false ? .light : .dark
    }

    var body: some View {
        let palette = self.theme.palette
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(RunicFontChoice.displayName(for: self.previewFamily))
                        .font(RunicFont.previewFont(for: self.previewFamily, size: 16).weight(.semibold))
                        .tracking(self.rules.letterSpacing)
                        .foregroundStyle(self.rules.contrast.color(role: .primary, on: self.tone))
                    Text("Aa 123 · tokens · context window · project spend")
                        .font(RunicFont.previewFont(for: self.previewFamily, size: 12))
                        .tracking(self.rules.compactLetterSpacing)
                        .lineSpacing(self.rules.lineSpacing)
                        .foregroundStyle(self.rules.contrast.color(role: .secondary, on: self.tone))
                        .lineLimit(2)
                }
                Spacer()
                Text(self.rules.prefersMonospacedDigits ? "tabular" : "proportional")
                    .font(self.fonts.caption2.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, RunicSpacing.xs)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(palette.accent.opacity(0.18)))
            }

            HStack(spacing: RunicSpacing.xs) {
                self.rulePill(title: "Letter", value: self.format(self.rules.letterSpacing))
                self.rulePill(title: "Word", value: self.format(self.rules.wordSpacing))
                self.rulePill(title: "Line", value: self.format(self.rules.lineSpacing))
                self.rulePill(
                    title: self.tone == .light ? "Light bg" : "Dark bg",
                    value: self.contrastSummary)
            }
        }
        .padding(RunicSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.md), style: .continuous)
                .fill(palette.surfaceBackgroundStyle))
        .overlay(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.md), style: .continuous)
                .stroke(palette.menuSeparatorColor.opacity(0.70), lineWidth: 0.8))
        .runicColorScheme(palette)
    }

    private var contrastSummary: String {
        switch self.tone {
        case .light:
            self.contrastPair(
                primary: self.rules.contrast.lightPrimaryOpacity,
                secondary: self.rules.contrast.lightSecondaryOpacity)
        case .dark:
            self.contrastPair(
                primary: self.rules.contrast.darkPrimaryOpacity,
                secondary: self.rules.contrast.darkSecondaryOpacity)
        }
    }

    private func contrastPair(primary: Double, secondary: Double) -> String {
        "\(Int((primary * 100).rounded()))/\(Int((secondary * 100).rounded()))"
    }

    private func rulePill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(self.fonts.caption2)
                .foregroundStyle(self.theme.palette.secondaryText)
            Text(value)
                .font(self.fonts.caption.weight(.semibold))
                .foregroundStyle(self.theme.palette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RunicSpacing.compact)
        .padding(.vertical, RunicSpacing.xxxs)
        .background(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .fill(self.theme.palette.menuSubtleFill))
        .overlay(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .stroke(self.theme.palette.menuSeparatorColor.opacity(0.52), lineWidth: 0.6))
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }
}
