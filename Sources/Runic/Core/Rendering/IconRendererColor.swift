import AppKit
import RunicCore

extension IconRenderer {
    /// Active theme palette for the menubar icon. Set by SettingsStore on
    /// theme change so the vibrant accent ramp adapts to each theme's
    /// signature colors (phosphor green for Terminal, peach for Daybreak,
    /// cyan→magenta for Glass).
    ///
    /// Writes happen on the main actor (SettingsStore.theme.didSet). Reads
    /// happen during icon rendering, which may run off the main thread when
    /// callers wrap `makeIcon` in a background dispatch. Lock-guarded so a
    /// theme switch can't race a render.
    private static let palettelLock = NSLock()
    private nonisolated(unsafe) static var _themePalette: RunicThemePalette?

    static var themePalette: RunicThemePalette? {
        get { Self.palettelLock.withLock { Self._themePalette } }
        set { Self.palettelLock.withLock { Self._themePalette = newValue } }
    }

    static func vibrantAccentColor(pressure: Double, stale: Bool) -> NSColor {
        let clamped = CGFloat(max(0, min(pressure, 1)))
        let (safe, warn, hot) = Self.vibrantRamp()
        let color: NSColor = if clamped <= 0.5 {
            self.mixColor(safe, warn, p: clamped / 0.5)
        } else {
            self.mixColor(warn, hot, p: (clamped - 0.5) / 0.5)
        }
        if stale {
            return color.withAlphaComponent(0.72)
        }
        return color
    }

    /// Per-theme safe/warn/hot ramp used by the vibrant menubar icon. Falls
    /// back to the original teal/amber/coral when no theme is set.
    static func vibrantRamp() -> (NSColor, NSColor, NSColor) {
        let defaultSafe = NSColor(calibratedRed: 0.12, green: 0.86, blue: 0.78, alpha: 1)
        let defaultWarn = NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.30, alpha: 1)
        let defaultHot = NSColor(calibratedRed: 1.00, green: 0.31, blue: 0.44, alpha: 1)
        if let palette = Self.themePalette {
            return (
                palette.nsColor(palette.tertiary, fallback: defaultSafe),
                palette.nsColor(palette.highlight, fallback: defaultWarn),
                palette.nsColor(palette.warm, fallback: defaultHot))
        }
        return (defaultSafe, defaultWarn, defaultHot)
    }

    static func mixColor(_ a: NSColor, _ b: NSColor, p: CGFloat) -> NSColor {
        guard let ca = a.usingColorSpace(.deviceRGB),
              let cb = b.usingColorSpace(.deviceRGB)
        else {
            return a
        }
        let clamped = max(0, min(p, 1))
        let red = ca.redComponent + (cb.redComponent - ca.redComponent) * clamped
        let green = ca.greenComponent + (cb.greenComponent - ca.greenComponent) * clamped
        let blue = ca.blueComponent + (cb.blueComponent - ca.blueComponent) * clamped
        let alpha = ca.alphaComponent + (cb.alphaComponent - ca.alphaComponent) * clamped
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
}
