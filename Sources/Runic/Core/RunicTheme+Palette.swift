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
                secondary: Color.appearanceColor(
                    light: Color(red: 0.184, green: 0.435, blue: 0.859),
                    dark: Color(red: 0.369, green: 0.608, blue: 1.000)),
                accent: Color(nsColor: .controlAccentColor),
                // Darker on a light window so each stays above 3:1.
                highlight: Color.appearanceColor(
                    light: Color(red: 0.72, green: 0.35, blue: 0.0),
                    dark: Color(red: 0.94, green: 0.53, blue: 0.18)),
                warm: Color.appearanceColor(
                    light: Color(red: 0.769, green: 0.169, blue: 0.227),
                    dark: Color(red: 1.000, green: 0.478, blue: 0.522)),
                tertiary: Color.appearanceColor(
                    light: Color(red: 0.059, green: 0.498, blue: 0.361),
                    dark: Color(red: 0.239, green: 0.839, blue: 0.549)),
                surface: Color(nsColor: .windowBackgroundColor),
                surfaceAlt: Color(nsColor: .controlBackgroundColor),
                cardFill: Color(nsColor: .controlBackgroundColor).opacity(0.55),
                cardStroke: Color(nsColor: .separatorColor),
                primaryText: Color(nsColor: .controlTextColor),
                secondaryText: Color(nsColor: .secondaryLabelColor),
                fonts: .system,
                shape: .standard,
                motion: .standard,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: "__sf_pro__",
                        numericFamily: "__sf_mono__",
                        scale: 1.0,
                        tracking: 0.0,
                        lineSpacing: nil,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .native,
                        borderWeight: 0.5,
                        borderOpacity: 0.6,
                        cornerStyle: .standard,
                        panelDepth: .low),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0.34),
                    controls: .standard))
        case .dark:
            // Calm macOS Pro Obsidian Graphite: zero neon glow, subtle hairlines,
            // clean obsidian elevation layers.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Obsidian graphite",
                symbolName: "moon.stars.fill",
                isCustom: false,
                prefersDarkAppearance: true,
                primary: Color(red: 0.345, green: 0.651, blue: 1.000),
                secondary: Color(red: 0.608, green: 0.549, blue: 1.000),
                accent: Color(red: 0.345, green: 0.651, blue: 1.000),
                highlight: Color(red: 0.949, green: 0.663, blue: 0.231),
                warm: Color(red: 1.000, green: 0.420, blue: 0.478),
                tertiary: Color(red: 0.239, green: 0.839, blue: 0.549),
                surface: Color(red: 0.067, green: 0.071, blue: 0.078),
                surfaceAlt: Color(red: 0.090, green: 0.098, blue: 0.114),
                cardFill: Color(red: 0.110, green: 0.122, blue: 0.141),
                cardStroke: Color.white.opacity(0.10),
                primaryText: Color(red: 0.953, green: 0.961, blue: 0.973),
                secondaryText: Color(red: 0.651, green: 0.682, blue: 0.725),
                fonts: .system,
                shape: RunicThemeShape(cornerMultiplier: 1.0, separator: .hairline),
                motion: .standard,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: nil,
                        numericFamily: nil,
                        scale: 1.0,
                        tracking: 0.0,
                        lineSpacing: nil,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 0.5,
                        borderOpacity: 0.5,
                        cornerStyle: .standard,
                        panelDepth: .low),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0,
                        texture: .none,
                        textureOpacity: 0),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .accentSoft,
                        progressStyle: .softBar,
                        hoverStyle: .neutral,
                        chartSeries: .themed)))
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
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: "Zen Kaku Gothic New",
                        numericFamily: nil,
                        scale: 1,
                        tracking: 0,
                        lineSpacing: nil,
                        contrast: .strong),
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
                        chartSeries: .themed),
                    skin: SumiSkin.skinID))
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
                        bodyFamily: RunicFontChoice.geist.id,
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
                        chartSeries: .themed),
                    skin: DraftingSkin.skinID))
        case .relief:
            // Raised, pressed, lit. Matte ceramic plinths on alabaster
            // drawn by ReliefSkin.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Raised, pressed, lit",
                symbolName: "square.3.layers.3d.top.filled",
                isCustom: true,
                prefersDarkAppearance: false,
                primary: Color(red: 0.149, green: 0.141, blue: 0.122),
                secondary: Color(red: 0.247, green: 0.392, blue: 0.588),
                accent: Color(red: 0.722, green: 0.235, blue: 0.043),
                highlight: Color(red: 0.541, green: 0.353, blue: 0.000),
                warm: Color(red: 0.722, green: 0.196, blue: 0.247),
                tertiary: Color(red: 0.114, green: 0.451, blue: 0.286),
                surface: Color(red: 0.925, green: 0.918, blue: 0.894),
                surfaceAlt: Color(red: 0.957, green: 0.953, blue: 0.937),
                cardFill: Color(red: 0.980, green: 0.976, blue: 0.965),
                cardStroke: Color(red: 0.165, green: 0.153, blue: 0.137).opacity(0.20),
                primaryText: Color(red: 0.141, green: 0.133, blue: 0.118),
                secondaryText: Color(red: 0.298, green: 0.282, blue: 0.259),
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
                        chartSeries: .themed),
                    skin: ReliefSkin.skinID))
        case .glass:
            // Adaptive Liquid Glass MK II: Clear Daylight & Smoked Obsidian Night.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Optical liquid glass",
                symbolName: "sparkle.magnifyingglass",
                isCustom: true,
                prefersDarkAppearance: nil,
                primary: Color.appearanceColor(
                    light: Color(red: 0.043, green: 0.067, blue: 0.102),
                    dark: Color(red: 0.969, green: 0.976, blue: 0.988)),
                secondary: Color.appearanceColor(
                    light: Color(red: 0.294, green: 0.235, blue: 0.839),
                    dark: Color(red: 0.604, green: 0.549, blue: 1.000)),
                accent: Color.appearanceColor(
                    light: Color(red: 0.000, green: 0.322, blue: 0.800),
                    dark: Color(red: 0.322, green: 0.659, blue: 1.000)),
                highlight: Color.appearanceColor(
                    light: Color(red: 0.604, green: 0.302, blue: 0.000),
                    dark: Color(red: 1.000, green: 0.702, blue: 0.251)),
                warm: Color.appearanceColor(
                    light: Color(red: 0.769, green: 0.137, blue: 0.094),
                    dark: Color(red: 1.000, green: 0.380, blue: 0.349)),
                tertiary: Color.appearanceColor(
                    light: Color(red: 0.035, green: 0.459, blue: 0.306),
                    dark: Color(red: 0.204, green: 0.827, blue: 0.600)),
                surface: Color.appearanceColor(
                    light: Color(red: 0.933, green: 0.949, blue: 0.969),
                    dark: Color(red: 0.047, green: 0.063, blue: 0.090)),
                surfaceAlt: Color.appearanceColor(
                    light: Color(red: 0.890, green: 0.914, blue: 0.945),
                    dark: Color(red: 0.078, green: 0.106, blue: 0.141)),
                cardFill: Color.appearanceColor(
                    light: Color.white.opacity(0.769),
                    dark: Color(red: 0.102, green: 0.133, blue: 0.180).opacity(0.800)),
                cardStroke: Color.appearanceColor(
                    light: Color(red: 0.043, green: 0.067, blue: 0.102).opacity(0.141),
                    dark: Color.white.opacity(0.169)),
                primaryText: Color.appearanceColor(
                    light: Color(red: 0.043, green: 0.067, blue: 0.102),
                    dark: Color(red: 0.969, green: 0.976, blue: 0.988)),
                secondaryText: Color.appearanceColor(
                    light: Color(red: 0.204, green: 0.251, blue: 0.322),
                    dark: Color(red: 0.663, green: 0.710, blue: 0.780)),
                fonts: .system,
                shape: RunicThemeShape(cornerMultiplier: 1.0, separator: .hairline),
                motion: .snappy,
                density: .normal,
                style: RunicThemeStyle(
                    typography: .standard,
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 0.5,
                        borderOpacity: 0.6,
                        cornerStyle: .soft,
                        panelDepth: .low),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0),
                    controls: .standard,
                    skin: LiquidGlassSkin.skinID))
        case .terminal:
            // A clean, modern dark terminal — cool slate stage, a mint-green
            // prompt, amber highlights, and a cobalt / red spread for the data
            // series. No CRT scanlines or glow; the identity is the slate, the
            // mono face, and the mint. JetBrains Mono throughout.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Cool slate, mint prompt",
                symbolName: "terminal.fill",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.345, green: 0.890, blue: 0.604), // mint prompt
                secondary: Color(red: 0.498, green: 0.549, blue: 0.600), // slate grey
                accent: Color(red: 0.184, green: 0.827, blue: 0.478), // solid green — bars and selection
                highlight: Color(red: 0.949, green: 0.639, blue: 0.227), // amber — links, "on" state
                warm: Color(red: 1.000, green: 0.373, blue: 0.341), // terminal red — the alert tone
                tertiary: Color(red: 0.306, green: 0.631, blue: 1.000), // cobalt, for series spread
                surface: Color(red: 0.043, green: 0.059, blue: 0.078), // cool slate black
                surfaceAlt: Color(red: 0.071, green: 0.094, blue: 0.125),
                cardFill: Color(red: 0.071, green: 0.094, blue: 0.125).opacity(0.90),
                cardStroke: Color(red: 0.149, green: 0.200, blue: 0.251).opacity(0.90),
                primaryText: Color(red: 0.839, green: 0.867, blue: 0.902), // cool slate text
                secondaryText: Color(red: 0.722, green: 0.761, blue: 0.800), // lifted so it reads on the hover wash
                fonts: RunicThemeFonts(body: .mono, numeric: .mono),
                shape: RunicThemeShape(cornerMultiplier: 0.85, separator: .hairline),
                motion: .instant,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: RunicFontChoice.jetBrainsMono.id,
                        numericFamily: RunicFontChoice.jetBrainsMono.id,
                        scale: 1.0,
                        tracking: 0,
                        lineSpacing: 1.2,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 1.0,
                        borderOpacity: 0.55,
                        cornerStyle: .compact,
                        panelDepth: .low),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .terminalSolid,
                        progressStyle: .flatBar,
                        hoverStyle: .neutral)))
        case .atelier:
            // Swiss-Nordic architectural drafting studio — warm dot-grid paper & crisp white sheets
            // in daylight; deep charcoal #121212 studio night in dark appearance; electric blueprint
            // cobalt highlights throughout.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Architectural studio",
                symbolName: "square.dashed",
                isCustom: true,
                prefersDarkAppearance: nil,
                primary: Color.appearanceColor(
                    light: Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255),
                    dark: Color(red: 248 / 255, green: 248 / 255, blue: 245 / 255)),
                secondary: Color.appearanceColor(
                    light: Color(red: 89 / 255, green: 89 / 255, blue: 82 / 255),
                    dark: Color(red: 163 / 255, green: 163 / 255, blue: 155 / 255)),
                accent: Color.appearanceColor(
                    light: Color(red: 56 / 255, green: 72 / 255, blue: 240 / 255),
                    dark: Color(red: 124 / 255, green: 138 / 255, blue: 255 / 255)),
                highlight: Color.appearanceColor(
                    light: Color(red: 138 / 255, green: 90 / 255, blue: 0 / 255),
                    dark: Color(red: 229 / 255, green: 180 / 255, blue: 84 / 255)),
                warm: Color.appearanceColor(
                    light: Color(red: 200 / 255, green: 14 / 255, blue: 31 / 255),
                    dark: Color(red: 255 / 255, green: 107 / 255, blue: 115 / 255)),
                tertiary: Color.appearanceColor(
                    light: Color(red: 21 / 255, green: 106 / 255, blue: 72 / 255),
                    dark: Color(red: 71 / 255, green: 201 / 255, blue: 146 / 255)),
                surface: Color.appearanceColor(
                    light: Color(red: 245 / 255, green: 245 / 255, blue: 241 / 255),
                    dark: Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255)),
                surfaceAlt: Color.appearanceColor(
                    light: Color(red: 235 / 255, green: 235 / 255, blue: 229 / 255),
                    dark: Color(red: 31 / 255, green: 31 / 255, blue: 29 / 255)),
                cardFill: Color.appearanceColor(
                    light: Color(red: 1, green: 1, blue: 1),
                    dark: Color(red: 26 / 255, green: 26 / 255, blue: 25 / 255)),
                cardStroke: Color.appearanceColor(
                    light: Color(red: 220 / 255, green: 220 / 255, blue: 213 / 255),
                    dark: Color(red: 45 / 255, green: 45 / 255, blue: 42 / 255)),
                primaryText: Color.appearanceColor(
                    light: Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255),
                    dark: Color(red: 248 / 255, green: 248 / 255, blue: 245 / 255)),
                secondaryText: Color.appearanceColor(
                    light: Color(red: 89 / 255, green: 89 / 255, blue: 82 / 255),
                    dark: Color(red: 163 / 255, green: 163 / 255, blue: 155 / 255)),
                fonts: RunicThemeFonts(body: .system, numeric: .tabular),
                shape: RunicThemeShape(cornerMultiplier: 0.45, separator: .hairline),
                motion: .snappy,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: RunicFontChoice.geist.id,
                        numericFamily: RunicFontChoice.geistMono.id,
                        scale: 1.0,
                        tracking: 0.0,
                        lineSpacing: nil,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 1.0,
                        borderOpacity: 1.0,
                        cornerStyle: .sharp,
                        panelDepth: .flat),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0,
                        texture: .none,
                        textureOpacity: 0),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .accentSolid,
                        progressStyle: .flatBar,
                        hoverStyle: .neutral,
                        chartSeries: .themed),
                    skin: AtelierSkin.skinID))
        case .meridian:
            // Fine Horology chronometer — Porcelain Enamel (light) / Grand Feu Midnight (dark).
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Chronometer dial",
                symbolName: "gauge.with.dots.needle.67percent",
                isCustom: true,
                prefersDarkAppearance: nil,
                primary: Color.appearanceColor(
                    light: Color(red: 22 / 255, green: 27 / 255, blue: 36 / 255),
                    dark: Color(red: 244 / 255, green: 241 / 255, blue: 232 / 255)),
                secondary: Color.appearanceColor(
                    light: Color(red: 122 / 255, green: 86 / 255, blue: 24 / 255),
                    dark: Color(red: 123 / 255, green: 180 / 255, blue: 255 / 255)),
                accent: Color.appearanceColor(
                    light: Color(red: 26 / 255, green: 78 / 255, blue: 142 / 255),
                    dark: Color(red: 226 / 255, green: 188 / 255, blue: 118 / 255)),
                highlight: Color.appearanceColor(
                    light: Color(red: 142 / 255, green: 82 / 255, blue: 0 / 255),
                    dark: Color(red: 245 / 255, green: 176 / 255, blue: 65 / 255)),
                warm: Color.appearanceColor(
                    light: Color(red: 168 / 255, green: 36 / 255, blue: 44 / 255),
                    dark: Color(red: 255 / 255, green: 107 / 255, blue: 107 / 255)),
                tertiary: Color.appearanceColor(
                    light: Color(red: 21 / 255, green: 110 / 255, blue: 75 / 255),
                    dark: Color(red: 76 / 255, green: 214 / 255, blue: 155 / 255)),
                surface: Color.appearanceColor(
                    light: Color(red: 244 / 255, green: 241 / 255, blue: 234 / 255),
                    dark: Color(red: 11 / 255, green: 16 / 255, blue: 25 / 255)),
                surfaceAlt: Color.appearanceColor(
                    light: Color(red: 234 / 255, green: 229 / 255, blue: 218 / 255),
                    dark: Color(red: 18 / 255, green: 26 / 255, blue: 40 / 255)),
                cardFill: Color.appearanceColor(
                    light: Color(red: 250 / 255, green: 248 / 255, blue: 243 / 255),
                    dark: Color(red: 22 / 255, green: 32 / 255, blue: 48 / 255)),
                cardStroke: Color.appearanceColor(
                    light: Color(red: 30 / 255, green: 36 / 255, blue: 48 / 255).opacity(48 / 255),
                    dark: Color(red: 226 / 255, green: 188 / 255, blue: 118 / 255).opacity(56 / 255)),
                primaryText: Color.appearanceColor(
                    light: Color(red: 22 / 255, green: 27 / 255, blue: 36 / 255),
                    dark: Color(red: 244 / 255, green: 241 / 255, blue: 232 / 255)),
                secondaryText: Color.appearanceColor(
                    light: Color(red: 70 / 255, green: 78 / 255, blue: 92 / 255),
                    dark: Color(red: 168 / 255, green: 178 / 255, blue: 196 / 255)),
                fonts: RunicThemeFonts(body: .system, numeric: .tabular),
                shape: RunicThemeShape(cornerMultiplier: 0.9, separator: .hairline),
                motion: .snappy,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: RunicFontChoice.manrope.id,
                        numericFamily: RunicFontChoice.geistMono.id,
                        scale: 1.0,
                        tracking: 0.0,
                        lineSpacing: nil,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 0.75,
                        borderOpacity: 0.7,
                        cornerStyle: .soft,
                        panelDepth: .low),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0,
                        texture: .none,
                        textureOpacity: 0),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .accentSoft,
                        progressStyle: .flatBar,
                        hoverStyle: .neutral,
                        chartSeries: .themed),
                    skin: MeridianSkin.skinID))
        case .gazette:
            // A warm editorial broadsheet. Cream newsprint, black ink, ruled
            // separators; a deep-teal accent for links and "reply wanted",
            // gold-leaf emphasis, crimson for alerts, editorial blue in the
            // series. Manrope sets the body, Fraunces the serif headings.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "The daily edition",
                symbolName: "newspaper.fill",
                isCustom: true,
                prefersDarkAppearance: false,
                primary: Color(red: 0.078, green: 0.078, blue: 0.078), // ink
                secondary: Color(red: 0.333, green: 0.333, blue: 0.333), // grey rule
                accent: Color(red: 0.043, green: 0.431, blue: 0.471), // deep teal
                highlight: Color(red: 0.561, green: 0.337, blue: 0.000), // deep ochre — reads on the hover wash
                warm: Color(red: 0.784, green: 0.196, blue: 0.369), // crimson — alert
                tertiary: Color(red: 0.114, green: 0.373, blue: 0.800), // editorial blue
                surface: Color(red: 0.965, green: 0.945, blue: 0.906), // newsprint cream
                surfaceAlt: Color(red: 0.937, green: 0.910, blue: 0.855),
                cardFill: Color(red: 0.984, green: 0.973, blue: 0.945).opacity(0.97),
                cardStroke: Color(red: 0.078, green: 0.078, blue: 0.078).opacity(0.30),
                primaryText: Color(red: 0.078, green: 0.078, blue: 0.078),
                secondaryText: Color(red: 0.333, green: 0.333, blue: 0.333),
                fonts: RunicThemeFonts(body: .system, numeric: .tabular),
                shape: RunicThemeShape(cornerMultiplier: 0.18, separator: .rule),
                motion: .snappy,
                density: .generous,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: RunicFontChoice.manrope.id,
                        numericFamily: RunicFontChoice.manrope.id,
                        displayFamily: nil,
                        scale: 1.0,
                        tracking: 0,
                        lineSpacing: nil,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 1.0,
                        borderOpacity: 0.9,
                        cornerStyle: .soft,
                        panelDepth: .low),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0,
                        texture: .none,
                        textureOpacity: 0,
                        elevation: 0.0),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .accentSolid,
                        progressStyle: .flatBar,
                        hoverStyle: .neutral,
                        chartSeries: .themed)))
        case .flightdeck:
            // An avionics primary flight display. Near-black stage, a 5pt
            // inner frame, cyan-green symbology for the live readings, amber
            // for caution, magenta for exhausted, sky blue and green for the
            // attitude ball and the trend vector. B612 — the Airbus cockpit
            // face — for the text, B612 Mono for every readout.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Primary flight display",
                symbolName: "airplane",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.910, green: 0.925, blue: 0.941),
                secondary: Color(red: 0.165, green: 0.392, blue: 0.706),
                accent: Color(red: 0.247, green: 0.847, blue: 0.949),
                highlight: Color(red: 1.000, green: 0.706, blue: 0.239),
                warm: Color(red: 1.000, green: 0.361, blue: 0.820),
                tertiary: Color(red: 0.243, green: 0.863, blue: 0.549),
                surface: Color(red: 0.027, green: 0.039, blue: 0.055),
                surfaceAlt: Color(red: 0.063, green: 0.078, blue: 0.102),
                cardFill: Color(red: 0.047, green: 0.063, blue: 0.082),
                cardStroke: Color(red: 0.173, green: 0.204, blue: 0.239),
                primaryText: Color(red: 0.910, green: 0.925, blue: 0.941),
                secondaryText: Color(red: 0.604, green: 0.643, blue: 0.686),
                fonts: RunicThemeFonts(body: .system, numeric: .mono),
                shape: RunicThemeShape(cornerMultiplier: 0.25, separator: .hairline),
                motion: .instant,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: "B612",
                        numericFamily: "B612 Mono",
                        scale: 1.0,
                        tracking: 0.02,
                        lineSpacing: 1.1,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 1.0,
                        borderOpacity: 0.9,
                        cornerStyle: .sharp,
                        panelDepth: .flat),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0,
                        texture: .none,
                        textureOpacity: 0),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .accentSolid,
                        progressStyle: .flatBar,
                        hoverStyle: .neutral,
                        chartSeries: .themed),
                    skin: FlightDeckSkin.skinID))
        case .departures:
            // A Solari split-flap departures board. Near-black stage with a
            // charcoal inner frame, dark flap tiles, board yellow for the
            // accent, OPEN green and OUT red for status, a sky blue thread
            // for the series. Barlow Condensed sets every cap and numeral,
            // Barlow the running copy. Drawn by the Departures skin.
            RunicThemePalette(
                id: self.rawValue,
                displayName: self.label,
                tagline: "Every reset is a departure",
                symbolName: "airplane.departure",
                isCustom: true,
                prefersDarkAppearance: true,
                primary: Color(red: 0.949, green: 0.949, blue: 0.949), // board white
                secondary: Color(red: 0.557, green: 0.557, blue: 0.576), // dim grey — column headers
                accent: Color(red: 0.949, green: 0.788, blue: 0.298), // board yellow
                highlight: Color(red: 0.482, green: 0.847, blue: 0.561), // OPEN green
                warm: Color(red: 1.000, green: 0.420, blue: 0.341), // OUT red
                tertiary: Color(red: 0.541, green: 0.706, blue: 0.973), // sky blue, for series spread
                surface: Color(red: 0.043, green: 0.043, blue: 0.047), // the stage
                surfaceAlt: Color(red: 0.078, green: 0.078, blue: 0.086), // the frame
                cardFill: Color(red: 0.110, green: 0.110, blue: 0.118), // a flap tile
                cardStroke: Color(red: 0.227, green: 0.227, blue: 0.235),
                primaryText: Color(red: 0.949, green: 0.949, blue: 0.949),
                secondaryText: Color(red: 0.631, green: 0.631, blue: 0.651),
                fonts: RunicThemeFonts(body: .system, numeric: .tabular),
                shape: RunicThemeShape(cornerMultiplier: 0.3, separator: .hairline),
                motion: .snappy,
                density: .normal,
                style: RunicThemeStyle(
                    typography: RunicThemeTypographyStyle(
                        bodyFamily: "Barlow",
                        numericFamily: "Barlow Condensed",
                        scale: 1.0,
                        tracking: 0,
                        lineSpacing: nil,
                        contrast: .strong),
                    chrome: RunicThemeChromeStyle(
                        borderStyle: .hairline,
                        borderWeight: 1.0,
                        borderOpacity: 0.6,
                        cornerStyle: .sharp,
                        panelDepth: .flat),
                    effects: RunicThemeEffectsStyle(
                        scanlineOpacity: 0,
                        glowStrength: 0,
                        materialIntensity: 0,
                        texture: .none,
                        textureOpacity: 0),
                    controls: RunicThemeControlStyle(
                        selectedFillStyle: .accentSolid,
                        progressStyle: .flatBar,
                        hoverStyle: .neutral,
                        chartSeries: .themed),
                    skin: DeparturesSkin.skinID))
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
