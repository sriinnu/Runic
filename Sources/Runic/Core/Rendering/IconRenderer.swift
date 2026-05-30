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
    private static let creditsCap: Double = 1000
    private static let baseSize = NSSize(width: 38, height: 22)
    // Render to a 38×22 pt template (76×44 px at 2×) for better visibility.
    private static let outputSize = NSSize(width: 38, height: 22)
    private static let outputScale: CGFloat = 2
    private static let canvasPx = Int(outputSize.width * outputScale)

    /// Infinity symbol base template - loaded lazily from Resources
    private static let waveLogoTemplate: NSImage? = {
        guard let url = Bundle.main.url(forResource: "RunicMenubarIcon", withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        return image
    }()

    private struct PixelGrid {
        let scale: CGFloat

        func pt(_ px: Int) -> CGFloat {
            CGFloat(px) / self.scale
        }

        func rect(x: Int, y: Int, w: Int, h: Int) -> CGRect {
            CGRect(x: self.pt(x), y: self.pt(y), width: self.pt(w), height: self.pt(h))
        }

        func snapDelta(_ value: CGFloat) -> CGFloat {
            (value * self.scale).rounded() / self.scale
        }
    }

    private static let grid = PixelGrid(scale: outputScale)
    private static let styleKeys: [IconStyle: Int] = [
        .codex: 0,
        .claude: 1,
        .zai: 2,
        .gemini: 3,
        .antigravity: 4,
        .cursor: 5,
        .factory: 6,
        .copilot: 7,
        .minimax: 8,
        .openrouter: 9,
        .groq: 10,
        .deepseek: 11,
        .fireworks: 12,
        .mistral: 13,
        .perplexity: 14,
        .kimi: 15,
        .auggie: 16,
        .together: 17,
        .cohere: 18,
        .xai: 19,
        .cerebras: 20,
        .sambanova: 21,
        .azure: 22,
        .bedrock: 23,
        .vertexai: 24,
        .qwen: 25,
        .vercelai: 26,
        .localLLM: 27,
        .combined: 99,
    ]

    private struct IconCacheKey: Hashable {
        let primary: Int
        let weekly: Int
        let credits: Int
        let stale: Bool
        let style: Int
        let indicator: Int
        let appearance: Int
        let dataMode: Int
        /// User font family + theme palette id. Without these in the key,
        /// changing font/theme would serve a stale cached icon.
        let family: String
        let themeID: String
    }

    private final class IconCacheStore: @unchecked Sendable {
        private var cache: [IconCacheKey: NSImage] = [:]
        private var order: [IconCacheKey] = []
        private let lock = NSLock()

        func cachedIcon(for key: IconCacheKey) -> NSImage? {
            self.lock.lock()
            defer { self.lock.unlock() }
            guard let image = self.cache[key] else { return nil }
            if let idx = self.order.firstIndex(of: key) {
                self.order.remove(at: idx)
                self.order.append(key)
            }
            return image
        }

        func storeIcon(_ image: NSImage, for key: IconCacheKey, limit: Int) {
            self.lock.lock()
            defer { self.lock.unlock() }
            self.cache[key] = image
            self.order.removeAll { $0 == key }
            self.order.append(key)
            while self.order.count > limit {
                let oldest = self.order.removeFirst()
                self.cache.removeValue(forKey: oldest)
            }
        }
    }

    private static let iconCacheStore = IconCacheStore()
    private static let iconCacheLimit = PerformanceConstants.iconCacheSize
    private static let morphBucketCount = 200
    private static let morphCache = MorphCache(limit: PerformanceConstants.morphCacheSize)

    private final class MorphCache: @unchecked Sendable {
        private let cache = NSCache<NSNumber, NSImage>()

        init(limit: Int) {
            self.cache.countLimit = limit
        }

        func image(for key: NSNumber) -> NSImage? {
            self.cache.object(forKey: key)
        }

        func set(_ image: NSImage, for key: NSNumber) {
            self.cache.setObject(image, forKey: key)
        }
    }

    private struct RectPx: Hashable {
        let x: Int
        let y: Int
        let w: Int
        let h: Int

        var midXPx: Int {
            self.x + self.w / 2
        }

        var midYPx: Int {
            self.y + self.h / 2
        }

        func rect() -> CGRect {
            Self.grid.rect(x: self.x, y: self.y, w: self.w, h: self.h)
        }

        private static let grid = IconRenderer.grid
    }

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

    private static func chamferedPath(rectPx: RectPx, chamferPx: Int) -> NSBezierPath {
        let rect = rectPx.rect()
        let chamfer = Self.grid.pt(chamferPx)
        let x = rect.minX
        let y = rect.minY
        let w = rect.width
        let h = rect.height
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x + chamfer, y: y))
        path.line(to: NSPoint(x: x + w - chamfer, y: y))
        path.line(to: NSPoint(x: x + w, y: y + chamfer))
        path.line(to: NSPoint(x: x + w, y: y + h - chamfer))
        path.line(to: NSPoint(x: x + w - chamfer, y: y + h))
        path.line(to: NSPoint(x: x + chamfer, y: y + h))
        path.line(to: NSPoint(x: x, y: y + h - chamfer))
        path.line(to: NSPoint(x: x, y: y + chamfer))
        path.close()
        return path
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

    private static func iconFillPercent(
        primary: Double?,
        weekly: Double?,
        credits: Double?,
        dataMode: IconDataMode) -> Double
    {
        let value = primary ?? weekly ?? credits
        guard let value else { return 0 }
        let clamped = max(0, min(value / 100, 1))
        switch dataMode {
        case .remaining:
            return clamped
        case .used:
            return clamped
        }
    }

    private static func drawWaveLogo(
        fillPercent: Double,
        baseColor: NSColor,
        fillColor: NSColor)
    {
        guard let waveLogo = self.waveLogoTemplate,
              let ctx = NSGraphicsContext.current?.cgContext
        else {
            return
        }

        let rect = CGRect(origin: .zero, size: self.outputSize)
        let clamped = max(0, min(fillPercent, 1))

        // Base silhouette
        ctx.saveGState()
        waveLogo.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        ctx.setBlendMode(.sourceIn)
        baseColor.setFill()
        ctx.fill(rect)
        ctx.restoreGState()

        // Usage fill: left-to-right reveal within the infinity symbol.
        guard clamped > 0 else { return }
        ctx.saveGState()
        waveLogo.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        ctx.setBlendMode(.sourceIn)
        fillColor.setFill()
        let fillRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width * clamped, height: rect.height)
        ctx.fill(fillRect)
        ctx.restoreGState()
    }

    private static func usagePressure(
        primary: Double?,
        weekly: Double?,
        credits: Double?,
        dataMode: IconDataMode) -> Double
    {
        let values = [primary, weekly, credits].compactMap(\.self)
        guard !values.isEmpty else { return 0 }
        let normalized = values.map { max(0, min($0 / 100, 1)) }
        switch dataMode {
        case .used:
            return normalized.max() ?? 0
        case .remaining:
            let minRemaining = normalized.min() ?? 1
            return max(0, min(1, 1 - minRemaining))
        }
    }

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

    private static func vibrantAccentColor(pressure: Double, stale: Bool) -> NSColor {
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
    private static func vibrantRamp() -> (NSColor, NSColor, NSColor) {
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

    private static func mixColor(_ a: NSColor, _ b: NSColor, p: CGFloat) -> NSColor {
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

    private static func quantizedPercent(_ value: Double?) -> Int {
        guard let value else { return -1 }
        return Int((value * 10).rounded())
    }

    private static func quantizedCredits(_ value: Double?) -> Int {
        guard let value else { return -1 }
        let clamped = max(0, min(value, self.creditsCap))
        return Int((clamped * 10).rounded())
    }

    private static func styleKey(_ style: IconStyle) -> Int {
        self.styleKeys[style] ?? Self.styleKeys[.combined] ?? 99
    }

    private static func indicatorKey(_ indicator: ProviderStatusIndicator) -> Int {
        switch indicator {
        case .none: 0
        case .minor: 1
        case .major: 2
        case .critical: 3
        case .maintenance: 4
        case .unknown: 5
        }
    }

    private static func appearanceKey(_ appearance: IconAppearance) -> Int {
        switch appearance {
        case .template: 0
        case .vibrant: 1
        }
    }

    private static func dataModeKey(_ mode: IconDataMode) -> Int {
        switch mode {
        case .remaining: 0
        case .used: 1
        }
    }

    private static func morphCacheKey(
        progress: Double,
        style: IconStyle,
        appearance: IconAppearance) -> NSNumber
    {
        let bucket = Int((progress * Double(self.morphBucketCount)).rounded())
        let key = self.styleKey(style) * 10000 + self.appearanceKey(appearance) * 1000 + bucket
        return NSNumber(value: key)
    }

    private static func cachedIcon(for key: IconCacheKey) -> NSImage? {
        self.iconCacheStore.cachedIcon(for: key)
    }

    private static func storeIcon(_ image: NSImage, for key: IconCacheKey) {
        self.iconCacheStore.storeIcon(image, for: key, limit: self.iconCacheLimit)
    }

    private static func drawUnbraidMorph(
        t: Double,
        style: IconStyle,
        color: NSColor,
        appearance: IconAppearance)
    {
        let t = CGFloat(max(0, min(t, 1)))
        let size = Self.baseSize
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let baseColor = color

        struct Segment {
            let startCenter: CGPoint
            let endCenter: CGPoint
            let startAngle: CGFloat
            let endAngle: CGFloat
            let startLength: CGFloat
            let endLength: CGFloat
            let startThickness: CGFloat
            let endThickness: CGFloat
            let fadeOut: Bool
        }

        let segments: [Segment] = [
            // Upper ribbon -> top bar
            .init(
                startCenter: center.offset(dx: 0, dy: 2),
                endCenter: CGPoint(x: center.x, y: 9.0),
                startAngle: -30,
                endAngle: 0,
                startLength: 16,
                endLength: 14,
                startThickness: 3.4,
                endThickness: 3.0,
                fadeOut: false),
            // Lower ribbon -> bottom bar
            .init(
                startCenter: center.offset(dx: 0, dy: -2),
                endCenter: CGPoint(x: center.x, y: 4.0),
                startAngle: 210,
                endAngle: 0,
                startLength: 16,
                endLength: 12,
                startThickness: 3.4,
                endThickness: 2.4,
                fadeOut: false),
            // Side ribbon fades away
            .init(
                startCenter: center,
                endCenter: center.offset(dx: 0, dy: 6),
                startAngle: 90,
                endAngle: 0,
                startLength: 16,
                endLength: 8,
                startThickness: 3.4,
                endThickness: 1.8,
                fadeOut: true),
        ]

        for seg in segments {
            let p = seg.fadeOut ? t * 1.1 : t
            let c = seg.startCenter.lerp(to: seg.endCenter, p: p)
            let angle = seg.startAngle.lerp(to: seg.endAngle, p: p)
            let length = seg.startLength.lerp(to: seg.endLength, p: p)
            let thickness = seg.startThickness.lerp(to: seg.endThickness, p: p)
            let alpha = seg.fadeOut ? (1 - p) : 1

            self.drawRoundedRibbon(
                center: c,
                length: length,
                thickness: thickness,
                angle: angle,
                color: baseColor.withAlphaComponent(alpha))
        }

        // Cross-fade in bar fill emphasis near the end of the morph.
        if t > 0.55 {
            let barT = (t - 0.55) / 0.45
            let bars = self.makeIcon(
                primaryRemaining: 100,
                weeklyRemaining: 100,
                creditsRemaining: nil,
                stale: false,
                style: style,
                appearance: appearance)
            bars.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: barT)
        }
    }

    private static func drawRoundedRibbon(
        center: CGPoint,
        length: CGFloat,
        thickness: CGFloat,
        angle: CGFloat,
        color: NSColor)
    {
        var transform = AffineTransform.identity
        transform.translate(x: center.x, y: center.y)
        transform.rotate(byDegrees: angle)
        transform.translate(x: -center.x, y: -center.y)

        let rect = CGRect(
            x: center.x - length / 2,
            y: center.y - thickness / 2,
            width: length,
            height: thickness)

        let path = NSBezierPath(roundedRect: rect, xRadius: thickness / 2, yRadius: thickness / 2)
        path.transform(using: transform)
        color.setFill()
        path.fill()
    }

    private static func drawStatusOverlay(indicator: ProviderStatusIndicator, color: NSColor) {
        guard indicator.hasIssue else { return }
        switch indicator {
        case .minor, .maintenance:
            let size: CGFloat = 4
            let rect = Self.snapRect(
                x: Self.baseSize.width - size - 2,
                y: 2,
                width: size,
                height: size)
            let path = NSBezierPath(ovalIn: rect)
            color.setFill()
            path.fill()
        case .major, .critical, .unknown:
            let lineRect = Self.snapRect(
                x: Self.baseSize.width - 6,
                y: 4,
                width: 2.0,
                height: 6)
            let linePath = NSBezierPath(roundedRect: lineRect, xRadius: 1, yRadius: 1)
            color.setFill()
            linePath.fill()

            let dotRect = Self.snapRect(
                x: Self.baseSize.width - 6,
                y: 2,
                width: 2.0,
                height: 2.0)
            NSBezierPath(ovalIn: dotRect).fill()
        case .none:
            break
        }
    }

    private static func withScaledContext(_ draw: () -> Void) {
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            draw()
            return
        }
        ctx.saveGState()
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .none
        draw()
        ctx.restoreGState()
    }

    private static func snap(_ value: CGFloat) -> CGFloat {
        (value * self.outputScale).rounded() / self.outputScale
    }

    private static func snapRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: self.snap(x), y: self.snap(y), width: self.snap(width), height: self.snap(height))
    }

    private static func renderImage(isTemplate: Bool, _ draw: () -> Void) -> NSImage {
        let image = NSImage(size: Self.outputSize)

        if let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(Self.outputSize.width * Self.outputScale),
            pixelsHigh: Int(Self.outputSize.height * Self.outputScale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)
        {
            rep.size = Self.outputSize // points
            image.addRepresentation(rep)

            NSGraphicsContext.saveGraphicsState()
            if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
                NSGraphicsContext.current = ctx
                Self.withScaledContext(draw)
            }
            NSGraphicsContext.restoreGraphicsState()
        } else {
            // Fallback to legacy focus if the bitmap rep fails for any reason.
            image.lockFocus()
            Self.withScaledContext(draw)
            image.unlockFocus()
        }

        image.isTemplate = isTemplate
        return image
    }
}

extension CGPoint {
    fileprivate func lerp(to other: CGPoint, p: CGFloat) -> CGPoint {
        CGPoint(x: self.x + (other.x - self.x) * p, y: self.y + (other.y - self.y) * p)
    }

    fileprivate func offset(dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: self.x + dx, y: self.y + dy)
    }
}

extension CGFloat {
    fileprivate func lerp(to other: CGFloat, p: CGFloat) -> CGFloat {
        self + (other - self) * p
    }
}
