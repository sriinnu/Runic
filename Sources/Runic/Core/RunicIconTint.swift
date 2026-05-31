import AppKit
import SwiftUI

/// Semantic intent for app chrome icons. Call sites choose the intent so visual
/// meaning stays deliberate instead of inferred from SF Symbol names.
enum RunicIconIntent: CaseIterable, Equatable {
    case action
    case data
    case destructive
    case info
    case navigation
    case statusGood
    case statusWarning
}

/// SF Symbol wrapper that applies Runic's semantic icon palette while preserving
/// the symbol, font, and layout control at the call site.
@MainActor
struct RunicThemedSystemIcon: View {
    @Environment(\.runicTheme) private var environmentPalette
    let systemName: String
    var intent: RunicIconIntent = .action
    var selected = false
    var hovered = false
    var font: Font?
    var width: CGFloat?
    var palette: RunicThemePalette?

    var body: some View {
        Image(systemName: self.systemName)
            .font(self.font)
            .frame(width: self.width)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(self.activePalette.iconColor(
                for: self.intent,
                selected: self.selected,
                hovered: self.hovered))
    }

    private var activePalette: RunicThemePalette {
        self.palette ?? self.environmentPalette
    }
}

extension RunicThemePalette {
    /// Resolve a semantic icon color for the current theme and interaction
    /// state. Neutral navigation/action icons stay quiet; semantic statuses keep
    /// at least non-text contrast against common Runic surfaces.
    func iconColor(
        for intent: RunicIconIntent,
        selected: Bool = false,
        hovered: Bool = false)
        -> Color
    {
        if self.isTerminalHUD {
            return self.terminalIconColor(for: intent, selected: selected, hovered: hovered)
        }

        switch intent {
        case .action:
            return selected || hovered
                ? self.stateIconColor(selected: selected, hovered: hovered)
                : self.neutralIconColor
        case .data:
            return selected || hovered
                ? self.stateIconColor(selected: selected, hovered: hovered)
                : self.semanticIconColor(self.secondary)
        case .destructive:
            return self.semanticIconColor(self.warm)
        case .info:
            return selected || hovered
                ? self.stateIconColor(selected: selected, hovered: hovered)
                : self.semanticIconColor(self.secondary)
        case .navigation:
            return selected || hovered
                ? self.stateIconColor(selected: selected, hovered: hovered)
                : self.neutralIconColor
        case .statusGood:
            return self.semanticIconColor(self.tertiary)
        case .statusWarning:
            return self.semanticIconColor(self.highlight)
        }
    }

    private func stateIconColor(selected: Bool, hovered: Bool) -> Color {
        let background = selected ? self.selectedIconBackground : (hovered ? self.menuHoverFill : self.surface)
        return self.accessibleIconColor(
            self.accent,
            against: background,
            minimumContrast: 3.2,
            preferOpaque: true)
    }

    private var neutralIconColor: Color {
        self.accessibleIconColor(
            self.subduedSecondaryText,
            against: self.surface,
            minimumContrast: 2.7,
            preferOpaque: false)
    }

    private func semanticIconColor(_ color: Color, minimumContrast: Double = 3.05) -> Color {
        self.accessibleIconColor(color, against: self.surface, minimumContrast: minimumContrast, preferOpaque: true)
    }

    private func accessibleIconColor(
        _ color: Color,
        against backgroundColor: Color,
        minimumContrast: Double,
        preferOpaque: Bool)
        -> Color
    {
        let surface = Self.opaqueRGB(self.nsColor(self.surface, fallback: .windowBackgroundColor))
        let background = Self.composite(
            Self.rgba(self.nsColor(backgroundColor, fallback: .windowBackgroundColor)),
            over: surface)
        let original = self.nsColor(color, fallback: .controlAccentColor)
        let candidate = Self.composite(Self.rgba(original), over: background)
        let adjusted = Self.adjustedRGB(candidate, against: background, minimumContrast: minimumContrast)
        let alpha = preferOpaque ? 1 : max(original.alphaComponent, 0.78)
        return Color(nsColor: NSColor(
            deviceRed: adjusted.r,
            green: adjusted.g,
            blue: adjusted.b,
            alpha: alpha))
    }

    private var selectedIconBackground: Color {
        switch self.style.controls.selectedFillStyle {
        case .accentSolid, .terminalSolid:
            self.accent.opacity(self.isTerminalHUD ? 0.28 : 0.22)
        case .neutralSoft:
            self.menuSubtleFill
        case .accentSoft:
            self.accent.opacity(0.18)
        }
    }

    private func terminalIconColor(
        for intent: RunicIconIntent,
        selected: Bool,
        hovered: Bool)
        -> Color
    {
        switch intent {
        case .destructive:
            self.warm
        case .statusWarning:
            self.highlight
        case .statusGood:
            self.accent
        case .data, .info:
            selected || hovered ? self.accent : self.secondary
        case .action, .navigation:
            selected || hovered ? self.accent : self.readableSecondaryText
        }
    }

    private static func adjustedRGB(
        _ foreground: RGB,
        against background: RGB,
        minimumContrast: Double)
        -> RGB
    {
        if self.contrast(foreground, background) >= minimumContrast {
            return foreground
        }

        let target = Self.luminance(background) > 0.5
            ? RGB(r: 0, g: 0, b: 0)
            : RGB(r: 1, g: 1, b: 1)

        var best = foreground
        for step in 1...24 {
            let amount = Double(step) / 24
            let mixed = Self.mix(foreground, target, amount: amount)
            best = mixed
            if Self.contrast(mixed, background) >= minimumContrast {
                break
            }
        }
        return best
    }

    private static func contrast(_ lhs: RGB, _ rhs: RGB) -> Double {
        let l1 = Self.luminance(lhs)
        let l2 = Self.luminance(rhs)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private static func luminance(_ color: RGB) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b)
    }

    private static func mix(_ lhs: RGB, _ rhs: RGB, amount: Double) -> RGB {
        RGB(
            r: lhs.r + (rhs.r - lhs.r) * amount,
            g: lhs.g + (rhs.g - lhs.g) * amount,
            b: lhs.b + (rhs.b - lhs.b) * amount)
    }

    private static func composite(_ foreground: RGBA, over background: RGB) -> RGB {
        RGB(
            r: foreground.r * foreground.a + background.r * (1 - foreground.a),
            g: foreground.g * foreground.a + background.g * (1 - foreground.a),
            b: foreground.b * foreground.a + background.b * (1 - foreground.a))
    }

    private static func opaqueRGB(_ color: NSColor) -> RGB {
        let rgba = Self.rgba(color)
        return RGB(r: rgba.r, g: rgba.g, b: rgba.b)
    }

    private static func rgba(_ color: NSColor) -> RGBA {
        let resolved = color.usingColorSpace(.deviceRGB) ?? color
        return RGBA(
            r: Double(resolved.redComponent),
            g: Double(resolved.greenComponent),
            b: Double(resolved.blueComponent),
            a: Double(resolved.alphaComponent))
    }

    private struct RGB {
        let r: Double
        let g: Double
        let b: Double
    }

    private struct RGBA {
        let r: Double
        let g: Double
        let b: Double
        let a: Double
    }
}
