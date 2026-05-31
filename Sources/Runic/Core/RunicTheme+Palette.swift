import AppKit
import SwiftUI

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
