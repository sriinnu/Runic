import AppKit
import SwiftUI

struct RunicThemePalette {
    let id: String
    let displayName: String
    let tagline: String
    let symbolName: String
    let isCustom: Bool
    let prefersDarkAppearance: Bool?
    let primary: Color
    let secondary: Color
    let accent: Color
    let highlight: Color
    let warm: Color
    let tertiary: Color
    let surface: Color
    let surfaceAlt: Color
    let cardFill: Color
    let cardStroke: Color
    let primaryText: Color
    let secondaryText: Color

    var swatchColors: [Color] {
        [self.primary, self.accent, self.highlight, self.tertiary]
    }

    var isTerminalHUD: Bool {
        self.id == "terminal"
    }

    var meshColors: [Color] {
        if self.isTerminalHUD {
            [self.surface, self.accent, self.highlight, self.secondary, self.tertiary]
        } else {
            [self.primary, self.secondary, self.accent, self.warm, self.tertiary]
        }
    }

    func chartColor(at index: Int) -> Color {
        let palette = self.isTerminalHUD
            ? [self.accent, self.highlight, self.secondary, self.warm, self.tertiary, self.primary]
            : [self.accent, self.highlight, self.tertiary, self.warm, self.secondary, self.primary]
        return palette[index % palette.count]
    }

    var menuSurfaceGradient: LinearGradient {
        if self.isTerminalHUD {
            LinearGradient(
                colors: [
                    self.surface,
                    self.surfaceAlt.opacity(0.72),
                    self.surface,
                ],
                startPoint: .top,
                endPoint: .bottom)
        } else {
            LinearGradient(
                colors: [
                    self.surface.opacity(self.isCustom ? 0.98 : 0.88),
                    self.surfaceAlt.opacity(self.isCustom ? 0.92 : 0.62),
                    self.cardFill.opacity(self.isCustom ? 0.72 : 0.44),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        }
    }

    var menuCardGradient: LinearGradient {
        if self.isTerminalHUD {
            LinearGradient(
                colors: [
                    self.cardFill.opacity(0.88),
                    self.surface.opacity(0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        } else {
            LinearGradient(
                colors: [
                    self.cardFill.opacity(self.isCustom ? 0.92 : 0.52),
                    self.surfaceAlt.opacity(self.isCustom ? 0.72 : 0.38),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        }
    }

    var menuTrackColor: Color {
        self.isTerminalHUD ? Color.white.opacity(0.10) : self.cardStroke.opacity(self.isCustom ? 0.42 : 0.26)
    }

    var menuSubtleFill: Color {
        self.isTerminalHUD ? self.cardFill.opacity(0.46) : self.cardFill.opacity(self.isCustom ? 0.62 : 0.34)
    }

    var chartGridColor: Color {
        self.isTerminalHUD ? self.accent.opacity(0.18) : self.cardStroke.opacity(self.isCustom ? 0.58 : 0.42)
    }

    var chartAxisLabelColor: Color {
        self.isTerminalHUD ? Color.white.opacity(0.54) : self.secondaryText.opacity(self.isCustom ? 0.78 : 0.70)
    }

    var chartSelectionBandColor: Color {
        self.isTerminalHUD ? self.accent.opacity(0.10) : self.primaryText.opacity(self.isCustom ? 0.12 : 0.08)
    }

    var chartPeakColor: Color {
        self.isTerminalHUD ? self.highlight : self.highlight
    }

    var menuHoverFill: Color {
        self.isTerminalHUD ? self.accent.opacity(0.16) : self.accent.opacity(self.isCustom ? 0.20 : 0.14)
    }

    var menuSeparatorColor: Color {
        self.isTerminalHUD ? self.accent.opacity(0.42) : self.cardStroke.opacity(self.isCustom ? 0.70 : 0.48)
    }

    var nsPrimaryTextColor: NSColor {
        self.nsColor(self.primaryText, fallback: .labelColor)
    }

    var nsSecondaryTextColor: NSColor {
        self.nsColor(self.secondaryText, fallback: .secondaryLabelColor)
    }

    var nsAccentColor: NSColor {
        self.nsColor(self.accent, fallback: .controlAccentColor)
    }

    var nsWarmColor: NSColor {
        self.nsColor(self.warm, fallback: .systemRed)
    }

    var colorScheme: ColorScheme? {
        switch self.prefersDarkAppearance {
        case nil: nil
        case .some(true): .dark
        case .some(false): .light
        }
    }

    var nsAppearance: NSAppearance? {
        guard let prefersDarkAppearance else { return nil }
        return NSAppearance(named: prefersDarkAppearance ? .darkAqua : .aqua)
    }

    var nsCardStrokeColor: NSColor {
        self.nsColor(self.cardStroke, fallback: .separatorColor)
    }

    var nsMenuSubtleFillColor: NSColor {
        self.nsColor(self.menuSubtleFill, fallback: .controlBackgroundColor)
    }

    private func nsColor(_ color: Color, fallback: NSColor) -> NSColor {
        NSColor(color).usingColorSpace(.deviceRGB) ?? fallback
    }
}

extension Theme {
    var palette: RunicThemePalette {
        switch self {
        case .system:
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Follow macOS",
                symbolName: "circle.lefthalf.filled",
                isCustom: false,
                prefersDarkAppearance: nil,
                primary: Color(nsColor: .controlAccentColor),
                secondary: Color(red: 0.26, green: 0.55, blue: 0.96),
                accent: Color(nsColor: .controlAccentColor),
                highlight: Color(red: 0.94, green: 0.53, blue: 0.18),
                warm: Color(red: 0.80, green: 0.45, blue: 0.92),
                tertiary: Color(red: 0.26, green: 0.78, blue: 0.86),
                surface: Color(nsColor: .windowBackgroundColor),
                surfaceAlt: Color(nsColor: .controlBackgroundColor),
                cardFill: Color(nsColor: .controlBackgroundColor).opacity(0.34),
                cardStroke: Color(nsColor: .separatorColor).opacity(0.35),
                primaryText: Color(nsColor: .controlTextColor),
                secondaryText: Color(nsColor: .secondaryLabelColor))
        case .light:
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Clean aqua",
                symbolName: "sun.max.fill",
                isCustom: false,
                prefersDarkAppearance: false,
                primary: Color(red: 0.20, green: 0.42, blue: 0.90),
                secondary: Color(red: 0.10, green: 0.62, blue: 0.72),
                accent: Color(red: 0.15, green: 0.44, blue: 0.92),
                highlight: Color(red: 0.90, green: 0.47, blue: 0.12),
                warm: Color(red: 0.86, green: 0.28, blue: 0.38),
                tertiary: Color(red: 0.13, green: 0.58, blue: 0.34),
                surface: Color(red: 0.96, green: 0.97, blue: 0.98),
                surfaceAlt: Color.white.opacity(0.72),
                cardFill: Color.white.opacity(0.66),
                cardStroke: Color.black.opacity(0.12),
                primaryText: Color.black.opacity(0.86),
                secondaryText: Color.black.opacity(0.55))
        case .dark:
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Native dark",
                symbolName: "moon.stars.fill",
                isCustom: false,
                prefersDarkAppearance: true,
                primary: Color(red: 0.34, green: 0.48, blue: 0.94),
                secondary: Color(red: 0.38, green: 0.65, blue: 0.98),
                accent: Color(red: 0.38, green: 0.65, blue: 0.98),
                highlight: Color(red: 0.96, green: 0.62, blue: 0.20),
                warm: Color(red: 0.88, green: 0.48, blue: 0.37),
                tertiary: Color(red: 0.53, green: 0.66, blue: 0.47),
                surface: Color(red: 0.06, green: 0.07, blue: 0.09),
                surfaceAlt: Color.white.opacity(0.06),
                cardFill: Color.white.opacity(0.06),
                cardStroke: Color.white.opacity(0.13),
                primaryText: Color.white.opacity(0.92),
                secondaryText: Color.white.opacity(0.58))
        case .pine:
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "TokMeter pine",
                symbolName: "leaf.fill",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.039, green: 0.200, blue: 0.137),
                secondary: Color(red: 0.514, green: 0.600, blue: 0.345),
                accent: Color(red: 0.063, green: 0.337, blue: 0.400),
                highlight: Color(red: 0.953, green: 0.957, blue: 0.835),
                warm: Color(red: 0.827, green: 0.588, blue: 0.549),
                tertiary: Color(red: 0.514, green: 0.600, blue: 0.345),
                surface: Color(red: 0.012, green: 0.075, blue: 0.047),
                surfaceAlt: Color(red: 0.039, green: 0.200, blue: 0.137).opacity(0.74),
                cardFill: Color(red: 0.039, green: 0.200, blue: 0.137).opacity(0.58),
                cardStroke: Color(red: 0.953, green: 0.957, blue: 0.835).opacity(0.16),
                primaryText: Color(red: 0.953, green: 0.957, blue: 0.835),
                secondaryText: Color(red: 0.953, green: 0.957, blue: 0.835).opacity(0.64))
        case .nocturne:
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Calm operator",
                symbolName: "moon.haze.fill",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.102, green: 0.122, blue: 0.212),
                secondary: Color(red: 0.498, green: 0.525, blue: 0.678),
                accent: Color(red: 0.376, green: 0.647, blue: 0.980),
                highlight: Color(red: 0.957, green: 0.894, blue: 0.757),
                warm: Color(red: 0.878, green: 0.478, blue: 0.371),
                tertiary: Color(red: 0.529, green: 0.659, blue: 0.471),
                surface: Color(red: 0.040, green: 0.050, blue: 0.100),
                surfaceAlt: Color(red: 0.102, green: 0.122, blue: 0.212).opacity(0.78),
                cardFill: Color(red: 0.102, green: 0.122, blue: 0.212).opacity(0.62),
                cardStroke: Color(red: 0.376, green: 0.647, blue: 0.980).opacity(0.18),
                primaryText: Color.white.opacity(0.92),
                secondaryText: Color.white.opacity(0.58))
        case .prism:
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Signal colors",
                symbolName: "sparkles",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.361, green: 0.161, blue: 0.835),
                secondary: Color(red: 0.024, green: 0.714, blue: 0.831),
                accent: Color(red: 0.176, green: 0.831, blue: 0.749),
                highlight: Color(red: 0.961, green: 0.620, blue: 0.043),
                warm: Color(red: 0.984, green: 0.443, blue: 0.522),
                tertiary: Color(red: 0.063, green: 0.725, blue: 0.506),
                surface: Color(red: 0.055, green: 0.040, blue: 0.115),
                surfaceAlt: Color(red: 0.361, green: 0.161, blue: 0.835).opacity(0.25),
                cardFill: Color(red: 0.361, green: 0.161, blue: 0.835).opacity(0.22),
                cardStroke: Color(red: 0.176, green: 0.831, blue: 0.749).opacity(0.22),
                primaryText: Color.white.opacity(0.93),
                secondaryText: Color.white.opacity(0.60))
        case .glass:
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Aurora glass",
                symbolName: "sparkle.magnifyingglass",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.050, green: 0.090, blue: 0.160),
                secondary: Color(red: 0.220, green: 0.760, blue: 1.000),
                accent: Color(red: 0.320, green: 0.890, blue: 0.980),
                highlight: Color(red: 1.000, green: 0.780, blue: 0.280),
                warm: Color(red: 1.000, green: 0.390, blue: 0.560),
                tertiary: Color(red: 0.620, green: 0.420, blue: 1.000),
                surface: Color(red: 0.018, green: 0.026, blue: 0.052),
                surfaceAlt: Color(red: 0.130, green: 0.220, blue: 0.320).opacity(0.42),
                cardFill: Color.white.opacity(0.115),
                cardStroke: Color.white.opacity(0.24),
                primaryText: Color.white.opacity(0.94),
                secondaryText: Color.white.opacity(0.66))
        case .terminal:
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Retro terminal",
                symbolName: "terminal.fill",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.000, green: 0.957, blue: 0.451),
                secondary: Color(red: 0.160, green: 0.835, blue: 1.000),
                accent: Color(red: 0.000, green: 1.000, blue: 0.533),
                highlight: Color(red: 1.000, green: 0.706, blue: 0.000),
                warm: Color(red: 1.000, green: 0.361, blue: 0.420),
                tertiary: Color(red: 0.267, green: 0.929, blue: 0.720),
                surface: Color(red: 0.000, green: 0.015, blue: 0.012),
                surfaceAlt: Color(red: 0.000, green: 0.080, blue: 0.055).opacity(0.92),
                cardFill: Color(red: 0.000, green: 0.120, blue: 0.078).opacity(0.64),
                cardStroke: Color(red: 0.000, green: 1.000, blue: 0.533).opacity(0.34),
                primaryText: Color(red: 0.880, green: 0.965, blue: 0.905),
                secondaryText: Color(red: 0.640, green: 0.760, blue: 0.690))
        }
    }

    var appearanceName: NSAppearance.Name? {
        switch self.palette.prefersDarkAppearance {
        case nil: nil
        case .some(true): .darkAqua
        case .some(false): .aqua
        }
    }
}

extension EnvironmentValues {
    @Entry var runicTheme: RunicThemePalette = Theme.system.palette
}

@MainActor
struct RunicTerminalScanlineOverlay: View {
    let opacity: Double
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            let lineColor = self.runicTheme.accent.opacity(0.060 * self.opacity)
            let faintColor = self.runicTheme.accent.opacity(0.030 * self.opacity)
            var y: CGFloat = 1.5
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(lineColor), lineWidth: 0.5)
                y += 4
            }

            var gridY: CGFloat = 16
            while gridY < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: gridY))
                line.addLine(to: CGPoint(x: size.width, y: gridY))
                context.stroke(line, with: .color(faintColor), lineWidth: 0.7)
                gridY += 16
            }

            let glowHeight = min(72, size.height * 0.28)
            context.fill(
                Path(CGRect(x: 0, y: 0, width: size.width, height: glowHeight)),
                with: .linearGradient(
                    Gradient(colors: [
                        self.runicTheme.accent.opacity(0.050 * self.opacity),
                        .clear,
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: glowHeight)))
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
struct RunicTerminalCornerOverlay: View {
    let inset: CGFloat
    let length: CGFloat
    let lineWidth: CGFloat
    let opacity: Double
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Canvas { context, size in
            guard size.width > self.inset * 2, size.height > self.inset * 2 else { return }

            let left = self.inset
            let right = size.width - self.inset
            let top = self.inset
            let bottom = size.height - self.inset
            let length = min(self.length, min(size.width, size.height) / 3)
            let style = StrokeStyle(lineWidth: self.lineWidth, lineCap: .square, lineJoin: .miter)
            let color = self.runicTheme.accent.opacity(self.opacity)

            var path = Path()
            path.move(to: CGPoint(x: left, y: top + length))
            path.addLine(to: CGPoint(x: left, y: top))
            path.addLine(to: CGPoint(x: left + length, y: top))

            path.move(to: CGPoint(x: right - length, y: top))
            path.addLine(to: CGPoint(x: right, y: top))
            path.addLine(to: CGPoint(x: right, y: top + length))

            path.move(to: CGPoint(x: right, y: bottom - length))
            path.addLine(to: CGPoint(x: right, y: bottom))
            path.addLine(to: CGPoint(x: right - length, y: bottom))

            path.move(to: CGPoint(x: left + length, y: bottom))
            path.addLine(to: CGPoint(x: left, y: bottom))
            path.addLine(to: CGPoint(x: left, y: bottom - length))

            context.stroke(path, with: .color(color), style: style)
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
private struct RunicMenuPanelChrome: ViewModifier {
    @Environment(\.runicTheme) private var runicTheme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(self.runicTheme.primaryText)
            .tint(self.runicTheme.accent)
            .background {
                ZStack {
                    self.runicTheme.menuSurfaceGradient
                    if self.runicTheme.isTerminalHUD {
                        RunicTerminalScanlineOverlay(opacity: 0.95)
                    }
                }
            }
    }
}

extension View {
    @ViewBuilder
    func runicColorScheme(_ palette: RunicThemePalette) -> some View {
        if let colorScheme = palette.colorScheme {
            self.environment(\.colorScheme, colorScheme)
        } else {
            self
        }
    }

    func runicMenuPanelChrome() -> some View {
        self.modifier(RunicMenuPanelChrome())
    }
}
