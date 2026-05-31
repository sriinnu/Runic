import SwiftUI

// MARK: - Theme identity tokens

// A theme is more than a palette. These value types describe its non-color
// identity so components can change structure, not just tint.

/// Typographic personality of a theme. `nil` lets the user's font preference
/// (or the SwiftUI default) take over; non-nil values force the theme's pick.
struct RunicThemeFonts {
    enum Body { case system, rounded, mono, serif }
    enum Numeric { case system, rounded, mono, tabular }

    let body: Body
    let numeric: Numeric

    static let system = RunicThemeFonts(body: .system, numeric: .system)

    /// SwiftUI Font.Design that maps to `body`. `nil` for `.system`, which
    /// leaves the design unchanged.
    var swiftUIDesignOverride: Font.Design? {
        switch self.body {
        case .system: nil
        case .rounded: .rounded
        case .mono: .monospaced
        case .serif: .serif
        }
    }

    func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self.body {
        case .system: .system(size: size, weight: weight)
        case .rounded: .system(size: size, weight: weight, design: .rounded)
        case .mono: .system(size: size, weight: weight, design: .monospaced)
        case .serif: .system(size: size, weight: weight, design: .serif)
        }
    }

    func numericFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self.numeric {
        case .system: .system(size: size, weight: weight)
        case .rounded: .system(size: size, weight: weight, design: .rounded)
        case .mono: .system(size: size, weight: weight, design: .monospaced)
        case .tabular: .system(size: size, weight: weight).monospacedDigit()
        }
    }
}

/// How rounded surfaces feel. A multiplier applied to the RunicCornerRadius tokens.
struct RunicThemeShape {
    enum Separator { case hairline, glow, ascii }

    /// Multiplier for the global RunicCornerRadius scale. 1.0 = unchanged.
    let cornerMultiplier: CGFloat
    let separator: Separator

    static let standard = RunicThemeShape(cornerMultiplier: 1.0, separator: .hairline)
    static let soft = RunicThemeShape(cornerMultiplier: 1.35, separator: .hairline)
    static let sharp = RunicThemeShape(cornerMultiplier: 0.35, separator: .ascii)
    static let glassy = RunicThemeShape(cornerMultiplier: 1.0, separator: .glow)
    /// Retro: small radii, hairline rules — bevels do the heavy visual work
    /// via the `RetroBevelOverlay` modifier rather than corner curvature.
    static let retroBevel = RunicThemeShape(cornerMultiplier: 0.55, separator: .hairline)

    /// Apply the theme's corner multiplier to a base radius from `RunicCornerRadius`.
    func cornerRadius(_ base: CGFloat) -> CGFloat {
        max(2, base * self.cornerMultiplier)
    }
}

/// Motion personality. Components read this to pick their default animations.
struct RunicThemeMotion {
    /// Primary duration in seconds. Sub-second; tuned for menu interactions.
    let duration: Double
    let curve: Animation

    static let standard = RunicThemeMotion(duration: 0.22, curve: .easeOut(duration: 0.22))
    static let slow = RunicThemeMotion(duration: 0.34, curve: .easeInOut(duration: 0.34))
    static let snappy = RunicThemeMotion(duration: 0.18, curve: .spring(response: 0.32, dampingFraction: 0.7))
    static let instant = RunicThemeMotion(duration: 0.10, curve: .easeIn(duration: 0.10))
    /// Mechanical / click-stop motion — Retro buttons feel like physical
    /// keys. Short linear ramp.
    static let mechanical = RunicThemeMotion(duration: 0.12, curve: .linear(duration: 0.12))
    static let reduced = RunicThemeMotion(duration: 0.01, curve: .linear(duration: 0.01))

    func curve(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self.curve
    }

    func delayedCurve(reduceMotion: Bool, delay: Double) -> Animation? {
        reduceMotion ? nil : self.curve.delay(delay)
    }
}

/// Padding/spacing multiplier. 1.0 = unchanged.
struct RunicThemeDensity {
    let paddingMultiplier: CGFloat

    static let compact = RunicThemeDensity(paddingMultiplier: 0.70)
    static let normal = RunicThemeDensity(paddingMultiplier: 1.00)
    static let generous = RunicThemeDensity(paddingMultiplier: 1.20)

    /// Scale a base spacing value from `RunicSpacing`.
    func padding(_ base: CGFloat) -> CGFloat {
        base * self.paddingMultiplier
    }
}

/// Fine-grained taste tokens loaded from theme JSON. These sit beside the
/// older identity tokens so existing theme files keep working while richer
/// skins can tune typography, chrome, effects, and controls as data.
struct RunicThemeStyle {
    var typography: RunicThemeTypographyStyle = .standard
    var chrome: RunicThemeChromeStyle = .standard
    var effects: RunicThemeEffectsStyle = .standard
    var controls: RunicThemeControlStyle = .standard

    static let standard = RunicThemeStyle()
}

/// JSON-backed type tuning for copy, numbers, tracking, scale, line rhythm, and contrast.
struct RunicThemeTypographyStyle: Hashable {
    enum ContrastStrength: String, Hashable { case soft, standard, strong }

    let bodyFamily: String?
    let numericFamily: String?
    let scale: CGFloat
    let tracking: CGFloat
    let lineSpacing: CGFloat?
    let contrast: ContrastStrength

    static let standard = RunicThemeTypographyStyle(
        bodyFamily: nil, numericFamily: nil, scale: 1, tracking: 0, lineSpacing: nil, contrast: .standard)
}

/// JSON-backed chrome tuning for borders, corners, and panel depth.
struct RunicThemeChromeStyle: Hashable {
    enum BorderStyle: String, Hashable { case native, hairline, bevelSoft, hud, glass }
    enum CornerStyle: String, Hashable { case standard, soft, compact, sharp }
    enum PanelDepth: String, Hashable { case flat, low, medium, high }

    let borderStyle: BorderStyle
    let borderWeight: CGFloat
    let borderOpacity: Double
    let cornerStyle: CornerStyle
    let panelDepth: PanelDepth

    static let standard = RunicThemeChromeStyle(
        borderStyle: .hairline, borderWeight: 0.7, borderOpacity: 0.55, cornerStyle: .standard, panelDepth: .medium)
}

/// JSON-backed intensity controls for scanlines, glow, and material overlays.
struct RunicThemeEffectsStyle: Hashable {
    let scanlineOpacity: Double
    let glowStrength: Double
    let materialIntensity: Double

    static let standard = RunicThemeEffectsStyle(scanlineOpacity: 0, glowStrength: 0.25, materialIntensity: 0.45)
}

/// JSON-backed controls for selected states, progress bars, and hover behavior.
struct RunicThemeControlStyle: Hashable {
    enum SelectedFillStyle: String, Hashable { case accentSoft, accentSolid, neutralSoft, terminalSolid }
    enum ProgressStyle: String, Hashable { case softBar, segmentedHUD, nativeBar }
    enum HoverStyle: String, Hashable { case neutral, accent, glow }

    let selectedFillStyle: SelectedFillStyle
    let progressStyle: ProgressStyle
    let hoverStyle: HoverStyle

    static let standard = RunicThemeControlStyle(
        selectedFillStyle: .accentSoft, progressStyle: .softBar, hoverStyle: .accent)
}

extension RunicThemeStyle: Decodable {
    private enum CodingKeys: String, CodingKey { case typography, chrome, effects, controls }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.typography = try values.decodeIfPresent(RunicThemeTypographyStyle.self, forKey: .typography) ?? .standard
        self.chrome = try values.decodeIfPresent(RunicThemeChromeStyle.self, forKey: .chrome) ?? .standard
        self.effects = try values.decodeIfPresent(RunicThemeEffectsStyle.self, forKey: .effects) ?? .standard
        self.controls = try values.decodeIfPresent(RunicThemeControlStyle.self, forKey: .controls) ?? .standard
    }
}

extension RunicThemeTypographyStyle: Decodable {
    private enum CodingKeys: String, CodingKey {
        case bodyFamily, numericFamily, scale, tracking, lineSpacing, contrast
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard
        self.bodyFamily = try values.decodeIfPresent(String.self, forKey: .bodyFamily)
        self.numericFamily = try values.decodeIfPresent(String.self, forKey: .numericFamily)
        self.scale = values.cgFloat(forKey: .scale, default: defaults.scale)
        self.tracking = values.cgFloat(forKey: .tracking, default: defaults.tracking)
        self.lineSpacing = values.cgFloatIfPresent(forKey: .lineSpacing)
        self.contrast = values.rawEnum(ContrastStrength.self, forKey: .contrast, default: defaults.contrast)
    }
}

extension RunicThemeChromeStyle: Decodable {
    private enum CodingKeys: String, CodingKey {
        case borderStyle, borderWeight, borderOpacity, cornerStyle, panelDepth
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard
        self.borderStyle = values.rawEnum(BorderStyle.self, forKey: .borderStyle, default: defaults.borderStyle)
        self.borderWeight = values.cgFloat(forKey: .borderWeight, default: defaults.borderWeight)
        self.borderOpacity = values.double(forKey: .borderOpacity, default: defaults.borderOpacity)
        self.cornerStyle = values.rawEnum(CornerStyle.self, forKey: .cornerStyle, default: defaults.cornerStyle)
        self.panelDepth = values.rawEnum(PanelDepth.self, forKey: .panelDepth, default: defaults.panelDepth)
    }
}

extension RunicThemeEffectsStyle: Decodable {
    private enum CodingKeys: String, CodingKey { case scanlineOpacity, glowStrength, materialIntensity }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard
        self.scanlineOpacity = values.double(forKey: .scanlineOpacity, default: defaults.scanlineOpacity)
        self.glowStrength = values.double(forKey: .glowStrength, default: defaults.glowStrength)
        self.materialIntensity = values.double(forKey: .materialIntensity, default: defaults.materialIntensity)
    }
}

extension RunicThemeControlStyle: Decodable {
    private enum CodingKeys: String, CodingKey { case selectedFillStyle, progressStyle, hoverStyle }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard
        self.selectedFillStyle = values.rawEnum(
            SelectedFillStyle.self,
            forKey: .selectedFillStyle,
            default: defaults.selectedFillStyle)
        self.progressStyle = values.rawEnum(ProgressStyle.self, forKey: .progressStyle, default: defaults.progressStyle)
        self.hoverStyle = values.rawEnum(HoverStyle.self, forKey: .hoverStyle, default: defaults.hoverStyle)
    }
}

extension KeyedDecodingContainer {
    fileprivate func rawEnum<T: RawRepresentable>(
        _ type: T.Type,
        forKey key: Key,
        default value: T)
        -> T where T.RawValue == String
    {
        (try? self.decodeIfPresent(String.self, forKey: key)).flatMap(T.init(rawValue:)) ?? value
    }

    fileprivate func double(forKey key: Key, default value: Double) -> Double {
        (try? self.decodeIfPresent(Double.self, forKey: key)) ?? value
    }

    fileprivate func cgFloat(forKey key: Key, default value: CGFloat) -> CGFloat {
        CGFloat(self.double(forKey: key, default: Double(value)))
    }

    fileprivate func cgFloatIfPresent(forKey key: Key) -> CGFloat? {
        let value: Double? = try? self.decodeIfPresent(Double.self, forKey: key)
        return value.map { CGFloat($0) }
    }
}
