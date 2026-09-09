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
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Retro tools. Modern intelligence.",
                symbolName: "rectangle.connected.to.line.below",
                isCustom: true,
                prefersDarkAppearance: false,
                primary: Color(red: 0.118, green: 0.133, blue: 0.220), // deep navy ink
                secondary: Color(red: 0.353, green: 0.302, blue: 0.243), // sepia muted
                accent: Color(red: 0.231, green: 0.357, blue: 0.647), // System-7 blue
                highlight: Color(red: 0.749, green: 0.251, blue: 0.251), // coral red, deepened for 3:1 on hover
                warm: Color(red: 0.710, green: 0.314, blue: 0.184), // terracotta, deepened for 3:1 on hover
                tertiary: Color(red: 0.561, green: 0.380, blue: 0.035), // ochre — the old yellow never cleared 3:1
                surface: Color(red: 0.945, green: 0.910, blue: 0.823), // parchment
                surfaceAlt: Color(red: 0.973, green: 0.949, blue: 0.898), // highlight bevel
                cardFill: Color(red: 0.910, green: 0.867, blue: 0.760), // inset card body
                cardStroke: Color(red: 0.478, green: 0.510, blue: 0.604), // muted blue-gray bevel — NOT black
                primaryText: Color(red: 0.180, green: 0.180, blue: 0.220), // soft dark, not aggressive
                secondaryText: Color(red: 0.420, green: 0.380, blue: 0.330), // warm sepia
                fonts: RunicThemeFonts(body: .system, numeric: .mono),
                shape: .retroBevel,
                motion: .mechanical,
                density: .normal)
        case .system:
            // Auto-adapts to macOS appearance. Uses native colors and standard
            // shape/motion — this is the "Runic dressed in the OS's clothes"
            // theme, intended as the default boot state, not an opinionated look.
            RunicThemePalette(
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
        case .dark:
            // Cinematic dark: deep near-black canvas, electric accents,
            // glow-style separators. High-contrast and confident. Not a
            // "dimmed light theme" — its own visual language.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Cinematic dark",
                symbolName: "moon.stars.fill",
                isCustom: false,
                prefersDarkAppearance: true,
                primary: Color(red: 0.45, green: 0.62, blue: 1.00), // electric blue
                secondary: Color(red: 0.55, green: 0.80, blue: 1.00), // sky
                accent: Color(red: 0.55, green: 0.80, blue: 1.00), // sky accent
                highlight: Color(red: 1.000, green: 0.620, blue: 0.180), // punchy amber
                warm: Color(red: 1.000, green: 0.380, blue: 0.500), // hot coral
                tertiary: Color(red: 0.380, green: 0.920, blue: 0.660), // bright mint
                surface: Color(red: 0.025, green: 0.030, blue: 0.045), // near-black w/ blue tint
                surfaceAlt: Color(red: 0.060, green: 0.080, blue: 0.115).opacity(0.95),
                cardFill: Color.white.opacity(0.045),
                cardStroke: Color(red: 0.55, green: 0.80, blue: 1.00).opacity(0.22),
                primaryText: Color.white.opacity(0.95),
                secondaryText: Color.white.opacity(0.62),
                fonts: .system,
                shape: RunicThemeShape(cornerMultiplier: 1.0, separator: .glow),
                motion: .standard,
                density: .normal)
        case .sumi:
            // Ink on washi. Warm paper with visible fibre, sumi-black text,
            // a single vermilion seal for the accent, indigo and matcha for
            // support. Typography stays unlocked — the user's font pick
            // applies — with tabular numerals and tapered brush-stroke rules.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Ink on washi",
                symbolName: "paintbrush.pointed.fill",
                isCustom: true,
                prefersDarkAppearance: false,
                primary: Color(red: 0.086, green: 0.075, blue: 0.059), // sumi ink
                secondary: Color(red: 0.173, green: 0.310, blue: 0.486), // ai indigo
                accent: Color(red: 0.788, green: 0.227, blue: 0.118), // shu vermilion
                highlight: Color(red: 0.498, green: 0.345, blue: 0.039), // gold leaf, dark enough for the hover wash
                warm: Color(red: 0.557, green: 0.180, blue: 0.235), // plum
                tertiary: Color(red: 0.243, green: 0.420, blue: 0.322), // moss
                surface: Color(red: 0.965, green: 0.949, blue: 0.914), // washi — bright, barely warm
                surfaceAlt: Color(red: 0.984, green: 0.976, blue: 0.953),
                cardFill: Color.white.opacity(0.60), // cards lift off the paper as near-white sheets
                cardStroke: Color(red: 0.122, green: 0.106, blue: 0.086).opacity(0.40),
                primaryText: Color(red: 0.086, green: 0.075, blue: 0.059).opacity(0.95),
                secondaryText: Color(red: 0.333, green: 0.314, blue: 0.290),
                fonts: RunicThemeFonts(body: .system, numeric: .tabular),
                shape: RunicThemeShape(cornerMultiplier: 0.75, separator: .brush),
                motion: .slow,
                density: .normal,
                style: RunicThemeStyle(
                    typography: .standard,
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .ink,
                        borderWeight: 0.9,
                        borderOpacity: 0.55,
                        cornerStyle: .compact,
                        panelDepth: .low),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0,
                        texture: .paper,
                        textureOpacity: 0.55),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .accentSolid,
                        progressStyle: .flatBar,
                        hoverStyle: .neutral,
                        chartSeries: .themed)))
        case .blueprint:
            // Drafting table. Cobalt paper ruled with a fine grid, crisp white
            // linework, cyan drafting ink for the accent, Geist Mono numerals
            // like dimension labels. Brand colors sit on cobalt the way
            // markers sit on a blueprint — they pop instead of fighting.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Drafting table",
                symbolName: "ruler",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.918, green: 0.949, blue: 1.000), // paper-white ink
                secondary: Color(red: 0.710, green: 0.831, blue: 1.000), // pale blue
                accent: Color(red: 0.498, green: 0.827, blue: 1.000), // cyan drafting ink
                highlight: Color(red: 1.000, green: 0.820, blue: 0.400), // marker yellow
                warm: Color(red: 1.000, green: 0.482, blue: 0.482), // marker red
                tertiary: Color(red: 0.620, green: 0.941, blue: 0.761), // marker green
                surface: Color(red: 0.059, green: 0.180, blue: 0.369), // cobalt paper
                surfaceAlt: Color(red: 0.071, green: 0.227, blue: 0.451).opacity(0.90),
                cardFill: Color.white.opacity(0.08),
                cardStroke: Color(red: 0.918, green: 0.949, blue: 1.000).opacity(0.60),
                primaryText: Color(red: 0.949, green: 0.969, blue: 1.000).opacity(0.96),
                secondaryText: Color.white.opacity(0.75),
                fonts: RunicThemeFonts(body: .system, numeric: .mono),
                shape: RunicThemeShape(cornerMultiplier: 0.35, separator: .hairline),
                motion: .standard,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: nil,
                        numericFamily: RunicFontChoice.geistMono.id,
                        scale: 1.0,
                        tracking: 0.01,
                        lineSpacing: nil,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 1.0,
                        borderOpacity: 0.70,
                        cornerStyle: .sharp,
                        panelDepth: .flat),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0.08,
                        materialIntensity: 0,
                        texture: .grid,
                        textureOpacity: 0.6),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .accentSolid,
                        progressStyle: .flatBar,
                        hoverStyle: .neutral,
                        chartSeries: .themed)))
        case .relief:
            // Real light. Warm gray desk, cards raised on a wide ambient
            // shadow plus a tight key from the top-left, a rim highlight on
            // the top edge; pickers and tracks pressed in as wells. Indigo
            // accent, springy lift on hover, generous spacing so the
            // shadows can breathe.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Raised, pressed, lit",
                symbolName: "square.3.layers.3d.top.filled",
                isCustom: true,
                prefersDarkAppearance: false,
                primary: Color(red: 0.149, green: 0.141, blue: 0.122),
                secondary: Color(red: 0.290, green: 0.435, blue: 0.647), // steel blue
                accent: Color(red: 0.290, green: 0.333, blue: 0.839), // indigo
                highlight: Color(red: 0.561, green: 0.388, blue: 0.000), // deep amber
                warm: Color(red: 0.761, green: 0.227, blue: 0.306), // raspberry
                tertiary: Color(red: 0.122, green: 0.478, blue: 0.322), // green
                surface: Color(red: 0.914, green: 0.906, blue: 0.886), // warm desk gray
                surfaceAlt: Color(red: 0.953, green: 0.949, blue: 0.933),
                cardFill: Color(red: 0.984, green: 0.980, blue: 0.973).opacity(0.96),
                cardStroke: Color(red: 0.165, green: 0.153, blue: 0.137).opacity(0.20),
                primaryText: Color(red: 0.149, green: 0.141, blue: 0.122).opacity(0.96),
                secondaryText: Color(red: 0.310, green: 0.294, blue: 0.267),
                fonts: RunicThemeFonts(body: .system, numeric: .tabular),
                shape: RunicThemeShape(cornerMultiplier: 1.25, separator: .hairline),
                motion: .snappy,
                density: .generous,
                style: RunicThemeStyle(
                    typography: .standard,
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 0.5,
                        borderOpacity: 0.35,
                        cornerStyle: .soft,
                        panelDepth: .high),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0,
                        texture: .none,
                        textureOpacity: 0,
                        elevation: 1.0),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .accentSolid,
                        progressStyle: .flatBar,
                        hoverStyle: .neutral,
                        chartSeries: .themed)))
        case .glass:
            // Aurora-glass: deep indigo base, neon cyan/magenta/violet accents.
            // Translucent surfaces with hairline glow strokes, springy motion.
            // The "showroom" theme — bold and kinetic without being noisy.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Aurora glass",
                symbolName: "sparkle.magnifyingglass",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.040, green: 0.060, blue: 0.170),
                secondary: Color(red: 0.240, green: 0.880, blue: 1.000), // cyan
                accent: Color(red: 0.540, green: 0.380, blue: 1.000), // violet
                highlight: Color(red: 1.000, green: 0.420, blue: 0.760), // magenta
                warm: Color(red: 1.000, green: 0.560, blue: 0.230), // amber
                tertiary: Color(red: 0.180, green: 0.980, blue: 0.620), // mint
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
            // Operator console, the Bloomberg kind, not the CRT kind. True
            // black, amber phosphor for everything the system says (brackets,
            // selection, labels, progress), bone-white Geist Mono for every
            // number, and color reserved for status: green headroom, orange
            // warning, red exhausted. Scanlines stay at a whisper.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Operator console",
                symbolName: "terminal.fill",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 1.000, green: 0.788, blue: 0.302), // light amber
                secondary: Color(red: 0.490, green: 0.827, blue: 0.988), // informational cyan
                accent: Color(red: 1.000, green: 0.690, blue: 0.000), // amber phosphor
                highlight: Color(red: 1.000, green: 0.549, blue: 0.259), // warning orange
                warm: Color(red: 1.000, green: 0.361, blue: 0.361), // exhausted red
                tertiary: Color(red: 0.298, green: 0.878, blue: 0.627), // headroom green
                surface: Color(red: 0.043, green: 0.043, blue: 0.051), // true black
                surfaceAlt: Color(red: 0.078, green: 0.078, blue: 0.086).opacity(0.90),
                cardFill: Color.white.opacity(0.05),
                cardStroke: Color(red: 1.000, green: 0.690, blue: 0.000).opacity(0.35),
                primaryText: Color(red: 0.949, green: 0.929, blue: 0.894), // bone
                secondaryText: Color(red: 0.722, green: 0.690, blue: 0.639),
                fonts: RunicThemeFonts(body: .mono, numeric: .mono),
                shape: RunicThemeShape(cornerMultiplier: 0.62, separator: .hairline),
                motion: .instant,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: RunicFontChoice.geistMono.id,
                        numericFamily: RunicFontChoice.geistMono.id,
                        scale: 1.0,
                        tracking: 0,
                        lineSpacing: 1.2,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hud,
                        borderWeight: 0.75,
                        borderOpacity: 0.44,
                        cornerStyle: .compact,
                        panelDepth: .low),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0.08,
                        glowStrength: 0.12,
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
