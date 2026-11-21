import AppKit
import SwiftUI

extension Color {
    /// Returns high-contrast foreground text (surface vs dark ink/white) against this color.
    func runicContrastingLabel(preferredSurface: Color) -> Color {
        guard let target = NSColor(self).usingColorSpace(.sRGB) else { return preferredSurface }
        let targetLum = Self.relativeLuminance(target)
        if let surf = NSColor(preferredSurface).usingColorSpace(.sRGB) {
            let surfLum = Self.relativeLuminance(surf)
            let contrast = (max(targetLum, surfLum) + 0.05) / (min(targetLum, surfLum) + 0.05)
            if contrast >= 4.5 {
                return preferredSurface
            }
        }
        return targetLum > 0.38 ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white
    }

    private static func relativeLuminance(_ color: NSColor) -> Double {
        func linearize(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(color.redComponent)
            + 0.7152 * linearize(color.greenComponent)
            + 0.0722 * linearize(color.blueComponent)
    }
}

// MARK: - Segmented picker

/// Theme-owned segmented control. The native one ignores the theme entirely
/// (gray track, gray thumb, system font), which is why every Preferences
/// pane looked identical across themes. This one takes its track, thumb,
/// stroke, corner radius, font and motion from the active palette.
@MainActor
struct RunicSegmentedPicker<Value: Hashable>: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    init(selection: Binding<Value>, options: [(value: Value, label: String)]) {
        self._selection = selection
        self.options = options
    }

    var body: some View {
        let radius = self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm)
        HStack(spacing: 2) {
            ForEach(Array(self.options.enumerated()), id: \.offset) { _, option in
                let isSelected = option.value == self.selection
                Button {
                    withAnimation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion)) {
                        self.selection = option.value
                    }
                } label: {
                    Text(option.label)
                        .font(self.fonts.caption.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? self.selectedText : self.runicTheme.readableSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, RunicSpacing.xs)
                        .padding(.vertical, RunicSpacing.compact)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: max(2, radius - 2), style: .continuous)
                                    .fill(self.selectedFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: max(2, radius - 2), style: .continuous)
                                            .strokeBorder(self.runicTheme.accent.opacity(0.55), lineWidth: 0.8))
                                    .runicRaised(radius: max(2, radius - 2), lift: 0.6)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(self.runicTheme.isElevated ? self.runicTheme.surface : self.runicTheme.menuSubtleFill))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity * 0.8),
                    lineWidth: self.runicTheme.style.chrome.borderWeight))
        .retroBevel(baseRadius: RunicCornerRadius.sm, inset: true)
        .runicCutout(radius: radius, lift: 0.5, seed: 11)
        .runicRecessed(radius: radius)
    }

    private var selectedFill: Color {
        switch self.runicTheme.style.controls.selectedFillStyle {
        case .accentSolid, .terminalSolid:
            self.runicTheme.accent.opacity(self.runicTheme.isTerminalHUD ? 0.28 : 0.90)
        case .neutralSoft:
            self.runicTheme.cardFill
        case .accentSoft:
            self.runicTheme.accent.opacity(0.18)
        }
    }

    private var selectedText: Color {
        switch self.runicTheme.style.controls.selectedFillStyle {
        case .accentSolid:
            self.runicTheme.accent.runicContrastingLabel(preferredSurface: self.runicTheme.surface)
        case .terminalSolid, .neutralSoft, .accentSoft:
            self.runicTheme.iconColor(for: .navigation, selected: true)
        }
    }
}

extension RunicSegmentedPicker {
    /// Convenience for `CaseIterable` enums with a `label`.
    init(selection: Binding<Value>, cases: [Value], label: (Value) -> String) {
        self.init(selection: selection, options: cases.map { ($0, label($0)) })
    }
}

// MARK: - Buttons

/// Themed replacement for `.bordered`: card fill, theme stroke, theme
/// corner radius, accent wash on hover, retro bevel where the theme has one.
@MainActor
struct RunicBorderedButtonStyle: ButtonStyle {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        let radius = self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm)
        configuration.label
            .font(self.buttonFont)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(self.runicTheme.primaryText.opacity(self.isEnabled ? 1 : 0.45))
            .padding(.horizontal, self.horizontalPadding)
            .padding(.vertical, self.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(configuration.isPressed
                        ? self.runicTheme.accent.opacity(0.22)
                        : self.runicTheme.cardFill.opacity(0.9)))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity),
                        lineWidth: self.runicTheme.style.chrome.borderWeight))
            .retroBevel(baseRadius: RunicCornerRadius.sm, inset: configuration.isPressed)
            .runicCutout(radius: radius, lift: configuration.isPressed ? 0.2 : 0.55, seed: 13)
            .runicRaised(radius: radius, lift: configuration.isPressed ? 0.25 : 0.8)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(self.runicTheme.motion.curve, value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var buttonFont: Font {
        switch self.controlSize {
        case .mini: self.fonts.caption2.weight(.medium)
        case .small: self.fonts.caption.weight(.medium)
        case .large, .extraLarge: self.fonts.callout.weight(.medium)
        default: self.fonts.footnote.weight(.medium)
        }
    }

    private var horizontalPadding: CGFloat {
        switch self.controlSize {
        case .mini: 7
        case .small: 9
        case .large, .extraLarge: 14
        default: RunicSpacing.sm
        }
    }

    private var verticalPadding: CGFloat {
        switch self.controlSize {
        case .mini: 3
        case .small: 4
        case .large, .extraLarge: 8
        default: RunicSpacing.compact
        }
    }
}

/// Themed replacement for `.borderedProminent`: solid accent, WCAG-readable foreground
/// (Terminal keeps its low-opacity phosphor wash instead).
@MainActor
struct RunicProminentButtonStyle: ButtonStyle {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        let radius = self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm)
        let solid = !self.runicTheme.isTerminalHUD
        configuration.label
            .font(self.buttonFont)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(solid
                ? self.runicTheme.accent.runicContrastingLabel(preferredSurface: self.runicTheme.surface)
                : self.runicTheme.accent)
            .padding(.horizontal, self.horizontalPadding)
            .padding(.vertical, self.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(self.runicTheme.accent.opacity(
                        (solid ? 0.94 : 0.22) * (configuration.isPressed ? 0.82 : 1) * (self.isEnabled ? 1 : 0.5))))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(self.runicTheme.accent.opacity(solid ? 0.35 : 0.85), lineWidth: 0.8))
            .retroBevel(baseRadius: RunicCornerRadius.sm, inset: configuration.isPressed)
            .runicCutout(radius: radius, lift: configuration.isPressed ? 0.2 : 0.55, seed: 17)
            .runicRaised(radius: radius, lift: configuration.isPressed ? 0.25 : 0.8)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(self.runicTheme.motion.curve, value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var buttonFont: Font {
        switch self.controlSize {
        case .mini: self.fonts.caption2.weight(.semibold)
        case .small: self.fonts.caption.weight(.semibold)
        case .large, .extraLarge: self.fonts.callout.weight(.semibold)
        default: self.fonts.footnote.weight(.semibold)
        }
    }

    private var horizontalPadding: CGFloat {
        switch self.controlSize {
        case .mini: 8
        case .small: 10
        case .large, .extraLarge: 16
        default: RunicSpacing.sm
        }
    }

    private var verticalPadding: CGFloat {
        switch self.controlSize {
        case .mini: 3
        case .small: 4
        case .large, .extraLarge: 8
        default: RunicSpacing.compact
        }
    }
}

extension ButtonStyle where Self == RunicBorderedButtonStyle {
    static var runicBordered: RunicBorderedButtonStyle {
        RunicBorderedButtonStyle()
    }
}

extension ButtonStyle where Self == RunicProminentButtonStyle {
    static var runicProminent: RunicProminentButtonStyle {
        RunicProminentButtonStyle()
    }
}
