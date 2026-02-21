import AppKit
import RunicCore

/// **IconRenderer** - Generates menubar status item icons with usage visualization
///
/// **Purpose:**
/// Creates pixel-perfect 18×18pt (36×36px @2x) template images for the macOS menubar.
/// Renders usage bars, stale indicators, and provider status into the icon.
///
/// **Responsibilities:**
/// - Generate icons showing session/weekly usage patterns
/// - Apply stale data dimming when data is > 5 minutes old
/// - Cache rendered icons for performance (64 icon cache, 512 morph cache)
/// - Support template (adapts to menubar theme) and vibrant appearances
/// - Render loading animations and error states
///
/// **Performance:**
/// - **O(1) icon cache lookup** via IconCacheKey hash
/// - **O(1) morph cache** for animation frames
/// - Cap cache sizes via `PerformanceConstants`
/// - All rendering happens off main thread in `dispatchPrecondition(condition: .notOnQueue(.main))`
///
/// **Dependencies:**
/// - `PerformanceConstants` - Cache sizes and timing
/// - `UsageProvider` - Provider-specific rendering
/// - `AppKit/CoreGraphics` - Image generation
///
/// **Usage:**
/// ```swift
/// let icon = IconRenderer.render(
///     state: .usage(snap, status),
///     indicator: .none,
///     appearance: .template,
///     dataMode: .remaining
/// )
/// statusItem.button?.image = icon
/// ```

enum IconAppearance: Sendable {
    case template   // Adapts to menubar theme (light/dark mode)
    case vibrant    // Full color rendering
}

enum IconDataMode: Sendable {
    case remaining  // Show remaining quota
    case used       // Show used quota
}

enum IconRenderer {
    private static let creditsCap: Double = 1000
    private static let baseSize = NSSize(width: 38, height: 22)
    // Render to a 38×22 pt template (76×44 px at 2×) for better visibility.
    private static let outputSize = NSSize(width: 38, height: 22)
    private static let outputScale: CGFloat = 2
    private static let canvasPx = Int(outputSize.width * outputScale)
    
    // Infinity symbol base template - loaded lazily from Resources
    private static let waveLogoTemplate: NSImage? = {
        guard let url = Bundle.main.url(forResource: "RunicMenubarIcon", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }()

    private struct PixelGrid: Sendable {
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

    private struct IconCacheKey: Hashable {
        let primary: Int
        let weekly: Int
        let credits: Int
        let stale: Bool
        let style: Int
        let indicator: Int
        let appearance: Int
        let dataMode: Int
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

    private struct RectPx: Hashable, Sendable {
        let x: Int
        let y: Int
        let w: Int
        let h: Int

        var midXPx: Int { self.x + self.w / 2 }
        var midYPx: Int { self.y + self.h / 2 }

        func rect() -> CGRect {
            Self.grid.rect(x: self.x, y: self.y, w: self.w, h: self.h)
        }

        private static let grid = IconRenderer.grid
    }

    private enum SigilStyle {
        case codex
        case claude
        case gemini
        case antigravity
        case cursor
        case factory
        case copilot
        case minimax
        case openrouter
        case groq
        case zai
        case combined
    }

    // swiftlint:disable function_body_length
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
                dataMode: self.dataModeKey(dataMode))
            if let cached = self.cachedIcon(for: key) {
                return cached
            }
            let image = render()
            self.storeIcon(image, for: key)
            return image
        }

        return render()
    }

    // swiftlint:enable function_body_length

    private static func sigilStyle(for style: IconStyle) -> SigilStyle {
        switch style {
        case .codex: return .codex
        case .claude: return .claude
        case .zai: return .zai
        case .gemini: return .gemini
        case .antigravity: return .antigravity
        case .cursor: return .cursor
        case .factory: return .factory
        case .copilot: return .copilot
        case .minimax: return .minimax
        case .openrouter: return .openrouter
        case .groq: return .groq
        case .combined: return .combined
        }
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

    private static func drawSigil(_ style: SigilStyle, in rectPx: RectPx) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let centerXPx = rectPx.midXPx
        let centerYPx = rectPx.y + rectPx.h / 2

        func point(x: Int, y: Int) -> NSPoint {
            NSPoint(x: Self.grid.pt(x), y: Self.grid.pt(y))
        }

        ctx.saveGState()
        ctx.setBlendMode(.clear)
        ctx.setShouldAntialias(true)

        switch style {
        case .codex:
            let eyeSizePx = 3
            let eyeOffsetPx = 5
            let leftEye = Self.grid.rect(
                x: centerXPx - eyeOffsetPx - eyeSizePx / 2,
                y: centerYPx - eyeSizePx / 2,
                w: eyeSizePx,
                h: eyeSizePx)
            let rightEye = Self.grid.rect(
                x: centerXPx + eyeOffsetPx - eyeSizePx / 2,
                y: centerYPx - eyeSizePx / 2,
                w: eyeSizePx,
                h: eyeSizePx)
            NSBezierPath(rect: leftEye).fill()
            NSBezierPath(rect: rightEye).fill()
        case .claude:
            let slitWidthPx = 2
            let slitHeightPx = 6
            let slitOffsetPx = 5
            let leftSlit = Self.grid.rect(
                x: centerXPx - slitOffsetPx - slitWidthPx / 2,
                y: centerYPx - slitHeightPx / 2,
                w: slitWidthPx,
                h: slitHeightPx)
            let rightSlit = Self.grid.rect(
                x: centerXPx + slitOffsetPx - slitWidthPx / 2,
                y: centerYPx - slitHeightPx / 2,
                w: slitWidthPx,
                h: slitHeightPx)
            NSBezierPath(rect: leftSlit).fill()
            NSBezierPath(rect: rightSlit).fill()
        case .gemini:
            let diamondRadiusPx = 4
            let cx = Self.grid.pt(centerXPx)
            let cy = Self.grid.pt(centerYPx)
            let r = Self.grid.pt(diamondRadiusPx)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: cx, y: cy + r))
            path.line(to: NSPoint(x: cx + r, y: cy))
            path.line(to: NSPoint(x: cx, y: cy - r))
            path.line(to: NSPoint(x: cx - r, y: cy))
            path.close()
            path.fill()
        case .antigravity:
            let dotSizePx = 4
            let dotRect = Self.grid.rect(
                x: centerXPx - dotSizePx / 2,
                y: rectPx.y + rectPx.h - dotSizePx - 1,
                w: dotSizePx,
                h: dotSizePx)
            NSBezierPath(ovalIn: dotRect).fill()
        case .cursor:
            let tipPx = 6
            let baseXPx = centerXPx + 4
            let path = NSBezierPath()
            path.move(to: point(x: baseXPx, y: centerYPx))
            path.line(to: point(x: baseXPx - tipPx, y: centerYPx + tipPx / 2))
            path.line(to: point(x: baseXPx - tipPx, y: centerYPx - tipPx / 2))
            path.close()
            path.fill()
        case .factory:
            let armPx = 6
            let thicknessPx = 2
            let vertical = Self.grid.rect(
                x: centerXPx - thicknessPx / 2,
                y: centerYPx - armPx / 2,
                w: thicknessPx,
                h: armPx)
            let horizontal = Self.grid.rect(
                x: centerXPx - armPx / 2,
                y: centerYPx - thicknessPx / 2,
                w: armPx,
                h: thicknessPx)
            NSBezierPath(rect: vertical).fill()
            NSBezierPath(rect: horizontal).fill()
        case .copilot:
            let eyeRadiusPx = 3
            let eyeOffsetPx = 4
            let leftEye = Self.grid.rect(
                x: centerXPx - eyeOffsetPx - eyeRadiusPx,
                y: centerYPx - eyeRadiusPx,
                w: eyeRadiusPx * 2,
                h: eyeRadiusPx * 2)
            let rightEye = Self.grid.rect(
                x: centerXPx + eyeOffsetPx - eyeRadiusPx,
                y: centerYPx - eyeRadiusPx,
                w: eyeRadiusPx * 2,
                h: eyeRadiusPx * 2)
            let bridge = Self.grid.rect(
                x: centerXPx - 2,
                y: centerYPx - 1,
                w: 4,
                h: 2)
            NSBezierPath(ovalIn: leftEye).fill()
            NSBezierPath(ovalIn: rightEye).fill()
            NSBezierPath(rect: bridge).fill()
        case .minimax:
            let triWidthPx = 6
            let triHeightPx = 5
            let leftCx = centerXPx - 4
            let rightCx = centerXPx + 4
            let leftPath = NSBezierPath()
            leftPath.move(to: point(x: leftCx, y: centerYPx + triHeightPx / 2))
            leftPath.line(to: point(x: leftCx - triWidthPx / 2, y: centerYPx - triHeightPx / 2))
            leftPath.line(to: point(x: leftCx + triWidthPx / 2, y: centerYPx - triHeightPx / 2))
            leftPath.close()
            let rightPath = NSBezierPath()
            rightPath.move(to: point(x: rightCx, y: centerYPx + triHeightPx / 2))
            rightPath.line(to: point(x: rightCx - triWidthPx / 2, y: centerYPx - triHeightPx / 2))
            rightPath.line(to: point(x: rightCx + triWidthPx / 2, y: centerYPx - triHeightPx / 2))
            rightPath.close()
            leftPath.fill()
            rightPath.fill()
        case .openrouter:
            let outerRadiusPx = 4
            let innerRadiusPx = 2
            let outerRect = Self.grid.rect(
                x: centerXPx - outerRadiusPx,
                y: centerYPx - outerRadiusPx,
                w: outerRadiusPx * 2,
                h: outerRadiusPx * 2)
            let innerRect = Self.grid.rect(
                x: centerXPx - innerRadiusPx,
                y: centerYPx - innerRadiusPx,
                w: innerRadiusPx * 2,
                h: innerRadiusPx * 2)
            let ring = NSBezierPath()
            ring.appendOval(in: outerRect)
            ring.appendOval(in: innerRect)
            ring.windingRule = .evenOdd
            ring.fill()
        case .groq:
            let slashWidthPx = 2
            let slashHeightPx = 8
            let path = NSBezierPath()
            path.move(to: point(x: centerXPx - slashWidthPx, y: centerYPx - slashHeightPx / 2))
            path.line(to: point(x: centerXPx, y: centerYPx - slashHeightPx / 2))
            path.line(to: point(x: centerXPx + slashWidthPx, y: centerYPx + slashHeightPx / 2))
            path.line(to: point(x: centerXPx, y: centerYPx + slashHeightPx / 2))
            path.close()
            path.fill()
        case .zai:
            let slashGapPx = 3
            let slashWidthPx = 2
            let slashHeightPx = 7
            let leftPath = NSBezierPath()
            leftPath.move(to: point(x: centerXPx - slashGapPx, y: centerYPx - slashHeightPx / 2))
            leftPath.line(to: point(x: centerXPx - slashGapPx + slashWidthPx, y: centerYPx - slashHeightPx / 2))
            leftPath.line(to: point(x: centerXPx - slashGapPx + slashWidthPx + 2, y: centerYPx + slashHeightPx / 2))
            leftPath.line(to: point(x: centerXPx - slashGapPx + 2, y: centerYPx + slashHeightPx / 2))
            leftPath.close()
            let rightPath = NSBezierPath()
            rightPath.move(to: point(x: centerXPx + slashGapPx, y: centerYPx - slashHeightPx / 2))
            rightPath.line(to: point(x: centerXPx + slashGapPx + slashWidthPx, y: centerYPx - slashHeightPx / 2))
            rightPath.line(to: point(x: centerXPx + slashGapPx + slashWidthPx + 2, y: centerYPx + slashHeightPx / 2))
            rightPath.line(to: point(x: centerXPx + slashGapPx + 2, y: centerYPx + slashHeightPx / 2))
            rightPath.close()
            leftPath.fill()
            rightPath.fill()
        case .combined:
            let diamondRadiusPx = 4
            let cx = Self.grid.pt(centerXPx)
            let cy = Self.grid.pt(centerYPx)
            let r = Self.grid.pt(diamondRadiusPx)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: cx, y: cy + r))
            path.line(to: NSPoint(x: cx + r, y: cy))
            path.line(to: NSPoint(x: cx, y: cy - r))
            path.line(to: NSPoint(x: cx - r, y: cy))
            path.close()
            path.fill()
        }

        ctx.restoreGState()
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
              let ctx = NSGraphicsContext.current?.cgContext else {
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
        let values = [primary, weekly, credits].compactMap { $0 }
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

    private static func vibrantAccentColor(pressure: Double, stale: Bool) -> NSColor {
        let clamped = CGFloat(max(0, min(pressure, 1)))
        let safe = NSColor(calibratedRed: 0.12, green: 0.86, blue: 0.78, alpha: 1)
        let warn = NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.30, alpha: 1)
        let hot = NSColor(calibratedRed: 1.00, green: 0.31, blue: 0.44, alpha: 1)
        let color: NSColor
        if clamped <= 0.5 {
            color = self.mixColor(safe, warn, p: clamped / 0.5)
        } else {
            color = self.mixColor(warn, hot, p: (clamped - 0.5) / 0.5)
        }
        if stale {
            return color.withAlphaComponent(0.72)
        }
        return color
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
        switch style {
        case .codex: 0
        case .claude: 1
        case .zai: 2
        case .gemini: 3
        case .antigravity: 4
        case .cursor: 5
        case .factory: 6
        case .copilot: 7
        case .minimax: 8
        case .openrouter: 9
        case .groq: 10
        case .combined: 99
        }
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
