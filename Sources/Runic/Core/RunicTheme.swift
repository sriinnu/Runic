import AppKit
import SwiftUI

// MARK: - Runtime palette

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

    // Non-color identity. Defaults keep existing themes backward-compatible;
    // themes that want a distinct personality override at the call site.
    var fonts: RunicThemeFonts = .system
    var shape: RunicThemeShape = .standard
    var motion: RunicThemeMotion = .standard
    var density: RunicThemeDensity = .normal
    var style: RunicThemeStyle = .standard

    var swatchColors: [Color] {
        [self.primary, self.accent, self.highlight, self.tertiary]
    }

    var isTerminalHUD: Bool {
        self.id == "terminal"
    }

    var prefersRetroToggleChrome: Bool {
        self.id == "retro" || self.isTerminalHUD
    }

    var readableSecondaryText: Color {
        self.secondaryText(minimumAlpha: self.isTerminalHUD ? 0.92 : 0.86)
    }

    var subduedSecondaryText: Color {
        self.secondaryText(minimumAlpha: self.isTerminalHUD ? 0.84 : 0.78)
    }

    var chartScanlineOpacity: Double {
        self.style.effects.scanlineOpacity
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

    /// Card-surface fill that switches to frosted material on Glass theme.
    /// Lets every existing `fill(menuCardGradient)` callsite become themed by
    /// swapping `.menuCardGradient` → `.cardBackgroundStyle`. Other themes
    /// keep their gradient; Glass gets actual translucency.
    var cardBackgroundStyle: AnyShapeStyle {
        if self.id == "glass" {
            return AnyShapeStyle(.regularMaterial)
        }
        return AnyShapeStyle(self.menuCardGradient)
    }

    /// Outer-surface fill that switches to thin material on Glass theme.
    var surfaceBackgroundStyle: AnyShapeStyle {
        if self.id == "glass" {
            return AnyShapeStyle(.thinMaterial)
        }
        return AnyShapeStyle(self.menuSurfaceGradient)
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
        self.isTerminalHUD
            ? self.accent.opacity(0.12 + self.style.effects.scanlineOpacity * 0.12)
            : self.cardStroke.opacity(self.isCustom ? 0.42 : 0.26)
    }

    var menuSubtleFill: Color {
        self.isTerminalHUD ? self.cardFill.opacity(0.40) : self.cardFill.opacity(self.isCustom ? 0.62 : 0.34)
    }

    var chartGridColor: Color {
        self.isTerminalHUD ? self.accent.opacity(0.20) : self.cardStroke.opacity(self.isCustom ? 0.58 : 0.42)
    }

    var chartAxisLabelColor: Color {
        self.isTerminalHUD ? self.readableSecondaryText : self.secondaryText(minimumAlpha: self.isCustom ? 0.88 : 0.82)
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
        self.isTerminalHUD
            ? self.accent.opacity(0.24 + self.style.chrome.borderOpacity * 0.32)
            : self.cardStroke.opacity(self.isCustom ? self.style.chrome.borderOpacity : 0.48)
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

    /// Convert a SwiftUI `Color` to a deviceRGB `NSColor`, falling back to
    /// the supplied AppKit color when conversion fails (e.g., dynamic system
    /// colors that need a context to resolve). Public so AppKit-only code
    /// like `IconRenderer` can read the theme accent ramp.
    func nsColor(_ color: Color, fallback: NSColor = .controlAccentColor) -> NSColor {
        NSColor(color).usingColorSpace(.deviceRGB) ?? fallback
    }

    private func secondaryText(minimumAlpha: CGFloat) -> Color {
        let ns = self.nsColor(self.secondaryText, fallback: .secondaryLabelColor)
        guard ns.alphaComponent < minimumAlpha else { return self.secondaryText }
        return Color(nsColor: ns.withAlphaComponent(minimumAlpha))
    }
}

extension Theme {
    /// Runtime palette for the theme. Looks up the JSON-defined palette via
    /// `ThemeLoader` first so palettes can be edited as data without
    /// recompiling; falls back to the hardcoded definitions below when no
    /// matching JSON file exists (or fails to parse). The Swift versions
    /// also act as the source of truth for any theme that hasn't yet been
    /// migrated to JSON.
    var palette: RunicThemePalette {
        if let json = ThemeLoader.shared.palette(for: self.rawValue) {
            return json
        }
        return self.fallbackPalette
    }

    private var fallbackPalette: RunicThemePalette {
        switch self {
        case .retro:
            // Parchment + navy bevel. The signature Runic look — System 7
            // chrome with modern info architecture. Earth-toned accents
            // (System-7 blue, coral red, warm yellow). Pixel-display
            // headers paired with Geist body via the `fonts` token.
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Retro tools. Modern intelligence.",
                symbolName: "rectangle.connected.to.line.below",
                isCustom: true,
                prefersDarkAppearance: false,
                primary: Color(red: 0.118, green: 0.133, blue: 0.220),       // deep navy ink
                secondary: Color(red: 0.353, green: 0.302, blue: 0.243),     // sepia muted
                accent: Color(red: 0.231, green: 0.357, blue: 0.647),        // System-7 blue
                highlight: Color(red: 0.847, green: 0.349, blue: 0.349),     // coral red
                warm: Color(red: 0.780, green: 0.400, blue: 0.275),          // terracotta
                tertiary: Color(red: 0.902, green: 0.690, blue: 0.251),      // warm yellow
                surface: Color(red: 0.945, green: 0.910, blue: 0.823),       // parchment
                surfaceAlt: Color(red: 0.973, green: 0.949, blue: 0.898),    // highlight bevel
                cardFill: Color(red: 0.910, green: 0.867, blue: 0.760),      // inset card body
                cardStroke: Color(red: 0.478, green: 0.510, blue: 0.604),    // muted blue-gray bevel — NOT black
                primaryText: Color(red: 0.180, green: 0.180, blue: 0.220),    // soft dark, not aggressive
                secondaryText: Color(red: 0.420, green: 0.380, blue: 0.330),  // warm sepia
                fonts: RunicThemeFonts(body: .system, numeric: .mono),
                shape: .retroBevel,
                motion: .mechanical,
                density: .normal)
        case .system:
            // Auto-adapts to macOS appearance. Uses native colors and standard
            // shape/motion — this is the "Runic dressed in the OS's clothes"
            // theme, intended as the default boot state, not an opinionated look.
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
                secondaryText: Color(nsColor: .secondaryLabelColor),
                fonts: .system,
                shape: .standard,
                motion: .standard,
                density: .normal)
        case .light:
            // Clean aqua: native macOS light feel with curated accents.
            // Standard typography + standard motion — this is the "neutral"
            // light baseline, not a personality theme.
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
                secondaryText: Color.black.opacity(0.55),
                fonts: .system,
                shape: .standard,
                motion: .standard,
                density: .normal)
        case .dark:
            // Cinematic dark: deep near-black canvas, electric accents,
            // glow-style separators. High-contrast and confident. Not a
            // "dimmed light theme" — its own visual language.
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Cinematic dark",
                symbolName: "moon.stars.fill",
                isCustom: false,
                prefersDarkAppearance: true,
                primary: Color(red: 0.45, green: 0.62, blue: 1.00),         // electric blue
                secondary: Color(red: 0.55, green: 0.80, blue: 1.00),       // sky
                accent: Color(red: 0.55, green: 0.80, blue: 1.00),          // sky accent
                highlight: Color(red: 1.000, green: 0.620, blue: 0.180),    // punchy amber
                warm: Color(red: 1.000, green: 0.380, blue: 0.500),         // hot coral
                tertiary: Color(red: 0.380, green: 0.920, blue: 0.660),     // bright mint
                surface: Color(red: 0.025, green: 0.030, blue: 0.045),      // near-black w/ blue tint
                surfaceAlt: Color(red: 0.060, green: 0.080, blue: 0.115).opacity(0.95),
                cardFill: Color.white.opacity(0.045),
                cardStroke: Color(red: 0.55, green: 0.80, blue: 1.00).opacity(0.22),
                primaryText: Color.white.opacity(0.95),
                secondaryText: Color.white.opacity(0.62),
                fonts: .system,
                shape: RunicThemeShape(cornerMultiplier: 1.0, separator: .glow),
                motion: .standard,
                density: .normal)
        case .daybreak:
            // Warm sunrise: peach + lavender + dusty yellow. Soft rounded
            // body, gentle ease, generous spacing. The "Sunday morning notebook"
            // theme — designed to feel slow and cozy.
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Storybook daylight",
                symbolName: "sunrise.fill",
                isCustom: true,
                prefersDarkAppearance: false,
                primary: Color(red: 0.460, green: 0.250, blue: 0.520),     // soft plum
                secondary: Color(red: 0.940, green: 0.520, blue: 0.450),   // peach
                accent: Color(red: 0.965, green: 0.310, blue: 0.470),      // sunset pink
                highlight: Color(red: 1.000, green: 0.740, blue: 0.290),   // warm yellow
                warm: Color(red: 0.690, green: 0.420, blue: 0.860),        // lavender
                tertiary: Color(red: 0.270, green: 0.680, blue: 0.620),    // muted teal
                surface: Color(red: 0.995, green: 0.965, blue: 0.945),     // cream
                surfaceAlt: Color(red: 1.000, green: 0.930, blue: 0.910).opacity(0.85),
                cardFill: Color.white.opacity(0.78),
                cardStroke: Color(red: 0.420, green: 0.190, blue: 0.350).opacity(0.16),
                primaryText: Color(red: 0.135, green: 0.080, blue: 0.180).opacity(0.92),
                secondaryText: Color(red: 0.135, green: 0.080, blue: 0.180).opacity(0.58),
                fonts: RunicThemeFonts(body: .rounded, numeric: .rounded),
                shape: .soft,
                motion: .slow,
                density: .generous)
        case .glass:
            // Aurora-glass: deep indigo base, neon cyan/magenta/violet accents.
            // Translucent surfaces with hairline glow strokes, springy motion.
            // The "showroom" theme — bold and kinetic without being noisy.
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Aurora glass",
                symbolName: "sparkle.magnifyingglass",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.040, green: 0.060, blue: 0.170),
                secondary: Color(red: 0.240, green: 0.880, blue: 1.000),    // cyan
                accent: Color(red: 0.540, green: 0.380, blue: 1.000),       // violet
                highlight: Color(red: 1.000, green: 0.420, blue: 0.760),    // magenta
                warm: Color(red: 1.000, green: 0.560, blue: 0.230),         // amber
                tertiary: Color(red: 0.180, green: 0.980, blue: 0.620),     // mint
                surface: Color(red: 0.020, green: 0.028, blue: 0.060),
                surfaceAlt: Color(red: 0.080, green: 0.140, blue: 0.260).opacity(0.46),
                cardFill: Color.white.opacity(0.10),
                cardStroke: Color(red: 0.540, green: 0.380, blue: 1.000).opacity(0.40),
                primaryText: Color.white.opacity(0.94),
                secondaryText: Color.white.opacity(0.66),
                fonts: .system,
                shape: .glassy,
                motion: .snappy,
                density: .normal)
        case .terminal:
            // Tactical HUD: phosphor green on near-black with calmer scanlines,
            // fewer frames, and Commit Mono for dense operational data.
            return RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Tactical HUD",
                symbolName: "terminal.fill",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.051, green: 0.890, blue: 0.478),
                secondary: Color(red: 0.184, green: 0.784, blue: 0.910),
                accent: Color(red: 0.094, green: 0.949, blue: 0.545),
                highlight: Color(red: 0.973, green: 0.729, blue: 0.180),
                warm: Color(red: 0.941, green: 0.404, blue: 0.451),
                tertiary: Color(red: 0.333, green: 0.890, blue: 0.722),
                surface: Color(red: 0.008, green: 0.031, blue: 0.027),
                surfaceAlt: Color(red: 0.012, green: 0.102, blue: 0.075).opacity(0.85),
                cardFill: Color(red: 0.020, green: 0.129, blue: 0.090).opacity(0.60),
                cardStroke: Color(red: 0.063, green: 0.843, blue: 0.478).opacity(0.26),
                primaryText: Color(red: 0.843, green: 0.969, blue: 0.898),
                secondaryText: Color(red: 0.612, green: 0.784, blue: 0.698),
                fonts: RunicThemeFonts(body: .mono, numeric: .mono),
                shape: RunicThemeShape(cornerMultiplier: 0.62, separator: .hairline),
                motion: .instant,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: "CommitMono",
                        numericFamily: "CommitMono",
                        scale: 0.98,
                        tracking: 0.03,
                        lineSpacing: 0.35,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hud,
                        borderWeight: 0.75,
                        borderOpacity: 0.44,
                        cornerStyle: .compact,
                        panelDepth: .low),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0.32,
                        glowStrength: 0.16,
                        materialIntensity: 0),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .terminalSolid,
                        progressStyle: .segmentedHUD,
                        hoverStyle: .neutral)))
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

/// Theme-aware separator. Renders ASCII when a theme asks for it, a glowing
/// accent line for glow themes, and a hairline for everyone else. Use this
/// instead of SwiftUI's `Divider()` inside menu / preferences surfaces so
/// inner section breaks carry the theme's personality.
@MainActor
struct RunicDivider: View {
    @Environment(\.runicTheme) private var runicTheme
    var opacity: Double = 1.0

    var body: some View {
        Group {
            switch self.runicTheme.shape.separator {
            case .ascii:
                Text(String(repeating: "─", count: 96))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(self.runicTheme.menuSeparatorColor.opacity(0.55 * self.opacity))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
            case .glow:
                Rectangle()
                    .fill(LinearGradient(
                        colors: [
                            .clear,
                            self.runicTheme.accent.opacity(0.48 * self.opacity),
                            self.runicTheme.highlight.opacity(0.36 * self.opacity),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing))
                    .frame(height: 1)
                    .shadow(color: self.runicTheme.accent.opacity(0.28 * self.opacity), radius: 3.5)
            case .hairline:
                Rectangle()
                    .fill(self.runicTheme.menuSeparatorColor.opacity(0.65 * self.opacity))
                    .frame(height: 1)
            }
        }
        .accessibilityHidden(true)
    }
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
                        RunicTerminalScanlineOverlay(opacity: self.runicTheme.style.effects.scanlineOpacity)
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
