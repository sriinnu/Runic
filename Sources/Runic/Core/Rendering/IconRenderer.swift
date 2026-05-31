import AppKit
import RunicCore

// **IconRenderer** - Generates menubar status item icons with usage visualization
//
// **Purpose:**
// Creates pixel-perfect 18×18pt (36×36px @2x) template images for the macOS menubar.
// Renders usage bars, stale indicators, and provider status into the icon.
//
// **Responsibilities:**
// - Generate icons showing session/weekly usage patterns
// - Apply stale data dimming when data is > 5 minutes old
// - Cache rendered icons for performance (64 icon cache, 512 morph cache)
// - Support template (adapts to menubar theme) and vibrant appearances
// - Render loading animations and error states
//
// **Performance:**
// - **O(1) icon cache lookup** via IconCacheKey hash
// - **O(1) morph cache** for animation frames
// - Cap cache sizes via `PerformanceConstants`
// - All rendering happens off main thread in `dispatchPrecondition(condition: .notOnQueue(.main))`
//
// **Dependencies:**
// - `PerformanceConstants` - Cache sizes and timing
// - `UsageProvider` - Provider-specific rendering
// - `AppKit/CoreGraphics` - Image generation
//
// **Usage:**
// ```swift
// let icon = IconRenderer.render(
//     state: .usage(snap, status),
//     indicator: .none,
//     appearance: .template,
//     dataMode: .remaining
// )
// statusItem.button?.image = icon
// ```

enum IconAppearance {
    case template // Adapts to menubar theme (light/dark mode)
    case vibrant // Full color rendering
}

enum IconDataMode {
    case remaining // Show remaining quota
    case used // Show used quota
}

enum IconRenderer {
    static let creditsCap: Double = 1000
    static let baseSize = NSSize(width: 38, height: 22)
    // Render to a 38×22 pt template (76×44 px at 2×) for better visibility.
    static let outputSize = NSSize(width: 38, height: 22)
    static let outputScale: CGFloat = 2

    /// Infinity symbol base template - loaded lazily from Resources
    static let waveLogoTemplate: NSImage? = {
        guard let url = Bundle.main.url(forResource: "RunicMenubarIcon", withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        return image
    }()

    static func makeIcon(
        primaryRemaining: Double?,
        weeklyRemaining: Double?,
        creditsRemaining: Double?,
        stale: Bool,
        style: IconStyle,
        blink: CGFloat = 0,
        wiggle: CGFloat = 0,
        tilt: CGFloat = 0,
        statusIndicator: ProviderStatusIndicator = .none,
        appearance: IconAppearance = .template,
        dataMode: IconDataMode = .remaining) -> NSImage
    {
        let shouldCache = blink <= 0.0001 && wiggle <= 0.0001 && tilt <= 0.0001
        let render = {
            self.renderImage(isTemplate: appearance == .template) {
                let topValue = primaryRemaining
                let bottomValue = weeklyRemaining
                let creditsRatio = creditsRemaining.map { min($0 / Self.creditsCap * 100, 100) }
                let pressure = Self.usagePressure(
                    primary: topValue,
                    weekly: bottomValue,
                    credits: creditsRatio,
                    dataMode: dataMode)
                let accentColor = Self.vibrantAccentColor(pressure: pressure, stale: stale)
                let baseColor = appearance == .template ? NSColor.labelColor : accentColor

                // Disable blink effect to prevent flicker
                let opacityMultiplier = 1.0

                let fillColor = baseColor.withAlphaComponent((stale ? 0.55 : 1.0) * opacityMultiplier)
                let baseAlpha: CGFloat = (stale ? 0.18 : (appearance == .template ? 0.28 : 0.38)) * opacityMultiplier

                let fillPercent = Self.iconFillPercent(
                    primary: topValue,
                    weekly: bottomValue,
                    credits: creditsRatio,
                    dataMode: dataMode)

                Self.drawWaveLogo(
                    fillPercent: fillPercent,
                    baseColor: baseColor.withAlphaComponent(baseAlpha),
                    fillColor: fillColor)

                let overlayColor = appearance == .template
                    ? NSColor.labelColor
                    : NSColor.white.withAlphaComponent(0.92)
                Self.drawStatusOverlay(indicator: statusIndicator, color: overlayColor)
            }
        }

        if shouldCache {
            let key = IconCacheKey(
                primary: self.quantizedPercent(primaryRemaining),
                weekly: self.quantizedPercent(weeklyRemaining),
                credits: self.quantizedCredits(creditsRemaining),
                stale: stale,
                style: self.styleKey(style),
                indicator: self.indicatorKey(statusIndicator),
                appearance: self.appearanceKey(appearance),
                dataMode: self.dataModeKey(dataMode),
                family: RunicFontStore.shared.family,
                themeID: Self.themePalette?.id ?? "")
            if let cached = self.cachedIcon(for: key) {
                return cached
            }
            let image = render()
            self.storeIcon(image, for: key)
            return image
        }

        return render()
    }

    /// Morph helper: unbraids a simplified knot into our bar icon.
    static func makeMorphIcon(
        progress: Double,
        style: IconStyle,
        appearance: IconAppearance = .template) -> NSImage
    {
        let clamped = max(0, min(progress, 1))
        let key = self.morphCacheKey(progress: clamped, style: style, appearance: appearance)
        if let cached = self.morphCache.image(for: key) {
            return cached
        }
        let baseColor = appearance == .template
            ? NSColor.labelColor
            : self.vibrantAccentColor(pressure: 0.15, stale: false)
        let image = self.renderImage(isTemplate: appearance == .template) {
            self.drawUnbraidMorph(t: clamped, style: style, color: baseColor, appearance: appearance)
        }
        self.morphCache.set(image, for: key)
        return image
    }
}
