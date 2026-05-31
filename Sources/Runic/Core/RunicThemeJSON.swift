import AppKit
import RunicCore
import SwiftUI

// MARK: - Codable DTO

/// Wire-format representation of a theme. Mirrors `RunicThemePalette` but
/// with primitive types (hex strings, preset names) so it can live in a
/// JSON file. Decoded by `ThemeLoader`, then converted to a runtime palette.
struct RunicThemeJSON: Decodable {
    let id: String
    let displayName: String
    let tagline: String
    let symbolName: String
    let isCustom: Bool
    /// `nil` = follow macOS, `false` = light, `true` = dark.
    let prefersDarkAppearance: Bool?
    let colors: Colors
    let fonts: Fonts
    let shape: Shape
    let motion: Motion
    let density: Density
    let style: RunicThemeStyle?

    struct Colors: Decodable {
        let primary: String
        let secondary: String
        let accent: String
        let highlight: String
        let warm: String
        let tertiary: String
        let surface: String
        let surfaceAlt: String
        let cardFill: String
        let cardStroke: String
        let primaryText: String
        let secondaryText: String
    }

    /// Each is the name of a `RunicThemeFonts.Body` / `.Numeric` case
    /// (`"system"`, `"rounded"`, `"mono"`, `"serif"`, `"tabular"`).
    struct Fonts: Decodable {
        let body: String
        let numeric: String
    }

    /// Either named preset (`"standard"`, `"soft"`, `"sharp"`, `"glassy"`,
    /// `"retroBevel"`) — or custom `cornerMultiplier` + `separator`
    /// (`"hairline"`, `"glow"`, `"ascii"`).
    struct Shape: Decodable {
        let preset: String?
        let cornerMultiplier: Double?
        let separator: String?
    }

    /// Named motion preset.
    struct Motion: Decodable {
        let preset: String // standard / slow / snappy / instant / mechanical
    }

    /// Named density preset.
    struct Density: Decodable {
        let preset: String // compact / normal / generous
    }
}

// MARK: - Color value parsing

extension Color {
    /// Parse one of:
    /// - `"#RRGGBB"` / `"#RRGGBBAA"` — fixed hex (with optional alpha byte)
    /// - `"$systemColorName"` — dynamic NSColor that adapts to system
    ///   appearance (e.g. `"$controlAccentColor"`, `"$windowBackgroundColor"`)
    /// - `"$systemColorName@0.34"` — same, with an opacity multiplier
    ///
    /// Returns nil on bad input. Authoring tip: if you see fuchsia in the
    /// UI, the parse failed for that field.
    init?(colorToken token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("$") {
            if let color = Self.systemColorToken(trimmed) {
                self = color
                return
            }
            return nil
        }
        if let color = Self.hexColor(trimmed) {
            self = color
            return
        }
        return nil
    }

    private static func hexColor(_ token: String) -> Color? {
        var s = token
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        } else {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1
        }
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    private static func systemColorToken(_ token: String) -> Color? {
        var body = token
        body.removeFirst() // drop leading $
        var opacity = 1.0
        if let atIndex = body.firstIndex(of: "@") {
            let opString = String(body[body.index(after: atIndex)...])
            body = String(body[..<atIndex])
            opacity = Double(opString) ?? 1.0
        }
        let nsColor: NSColor? = switch body {
        case "controlAccentColor": .controlAccentColor
        case "windowBackgroundColor": .windowBackgroundColor
        case "controlBackgroundColor": .controlBackgroundColor
        case "separatorColor": .separatorColor
        case "controlTextColor": .controlTextColor
        case "labelColor": .labelColor
        case "secondaryLabelColor": .secondaryLabelColor
        case "tertiaryLabelColor": .tertiaryLabelColor
        case "white": .white
        case "black": .black
        default: nil
        }
        guard let ns = nsColor else { return nil }
        return Color(nsColor: ns).opacity(opacity)
    }

    /// Backwards-compatible alias for the older `Color(hex:)` initializer.
    init?(hex: String) {
        self.init(colorToken: hex)
    }
}

// MARK: - DTO → runtime palette

extension RunicThemeJSON {
    /// Same as `toPalette()` but callable from any thread. The runtime
    /// palette struct is value-type and immutable, so building one off the
    /// main actor is safe.
    nonisolated func toPaletteUnsafe() -> RunicThemePalette {
        self.buildPalette()
    }

    /// Convert the wire-format DTO into the runtime `RunicThemePalette`. Hex
    /// strings that don't parse default to fuchsia so they're visually loud
    /// and easy to spot during authoring.
    @MainActor
    func toPalette() -> RunicThemePalette {
        self.buildPalette()
    }

    private func buildPalette() -> RunicThemePalette {
        let c = self.colors
        return RunicThemePalette(
            id: self.id,
            displayName: self.displayName,
            tagline: self.tagline,
            symbolName: self.symbolName,
            isCustom: self.isCustom,
            prefersDarkAppearance: self.prefersDarkAppearance,
            primary: Self.color(c.primary),
            secondary: Self.color(c.secondary),
            accent: Self.color(c.accent),
            highlight: Self.color(c.highlight),
            warm: Self.color(c.warm),
            tertiary: Self.color(c.tertiary),
            surface: Self.color(c.surface),
            surfaceAlt: Self.color(c.surfaceAlt),
            cardFill: Self.color(c.cardFill),
            cardStroke: Self.color(c.cardStroke),
            primaryText: Self.color(c.primaryText),
            secondaryText: Self.color(c.secondaryText),
            fonts: self.makeFonts(),
            shape: self.makeShape(),
            motion: self.makeMotion(),
            density: self.makeDensity(),
            style: self.style ?? .standard)
    }

    private static func color(_ token: String) -> Color {
        Color(colorToken: token) ?? Color(red: 1, green: 0, blue: 1)
    }

    private func makeFonts() -> RunicThemeFonts {
        let body: RunicThemeFonts.Body = switch self.fonts.body {
        case "rounded": .rounded
        case "mono": .mono
        case "serif": .serif
        default: .system
        }
        let numeric: RunicThemeFonts.Numeric = switch self.fonts.numeric {
        case "rounded": .rounded
        case "mono": .mono
        case "tabular": .tabular
        default: .system
        }
        return RunicThemeFonts(body: body, numeric: numeric)
    }

    private func makeShape() -> RunicThemeShape {
        if let preset = self.shape.preset {
            switch preset {
            case "soft": return .soft
            case "sharp": return .sharp
            case "glassy": return .glassy
            case "retroBevel": return .retroBevel
            default: return .standard
            }
        }
        let mult = CGFloat(self.shape.cornerMultiplier ?? 1.0)
        let sep: RunicThemeShape.Separator = switch self.shape.separator ?? "hairline" {
        case "glow": .glow
        case "ascii": .ascii
        default: .hairline
        }
        return RunicThemeShape(cornerMultiplier: mult, separator: sep)
    }

    private func makeMotion() -> RunicThemeMotion {
        switch self.motion.preset {
        case "slow": .slow
        case "snappy": .snappy
        case "instant": .instant
        case "mechanical": .mechanical
        default: .standard
        }
    }

    private func makeDensity() -> RunicThemeDensity {
        switch self.density.preset {
        case "compact": .compact
        case "generous": .generous
        default: .normal
        }
    }
}

// MARK: - Loader

/// Loads and caches theme JSON files. Searches bundled
/// `Resources/Themes/*.json` first, then user-supplied
/// `~/Library/Application Support/Runic/Themes/*.json`.
///
/// Not `@MainActor` so the SwiftUI environment default value (which is
/// evaluated in a nonisolated context) can call into it. Internal state is
/// guarded by a lock; writes only happen on initial load + `reload()`.
final class ThemeLoader: @unchecked Sendable {
    static let shared = ThemeLoader()
    private let lock = NSLock()
    private var cache: [String: RunicThemePalette] = [:]
    private var loaded = false

    func palette(for id: String) -> RunicThemePalette? {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.loadIfNeededLocked()
        return self.cache[id]
    }

    /// Force a re-scan. Call after a user drops a new theme file in.
    func reload() {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.cache.removeAll()
        self.loaded = false
        self.loadIfNeededLocked()
    }

    private func loadIfNeededLocked() {
        guard !self.loaded else { return }
        self.loaded = true
        for url in self.themeURLs() {
            do {
                let data = try Data(contentsOf: url)
                let dto = try JSONDecoder().decode(RunicThemeJSON.self, from: data)
                self.cache[dto.id] = dto.toPaletteUnsafe()
            } catch {
                RunicLog.logger("themes").error("Failed to load theme \(url.lastPathComponent): \(error)")
            }
        }
    }

    private func themeURLs() -> [URL] {
        var urls: [URL] = []
        // Bundled themes (Resources/Themes/*.json).
        if let bundle = RunicResourceLocator.directories(named: "Themes").first {
            urls += self.jsonFiles(in: bundle)
        }
        // User themes (Application Support).
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let userDir = support.appendingPathComponent("Runic/Themes", isDirectory: true)
            urls += self.jsonFiles(in: userDir)
        }
        return urls
    }

    private func jsonFiles(in dir: URL) -> [URL] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])
        else { return [] }
        return items.filter { $0.pathExtension.lowercased() == "json" }
    }
}
