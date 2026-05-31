import AppKit
import RunicCore

extension IconRenderer {
    static func iconFillPercent(
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

    static func drawWaveLogo(
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

    static func usagePressure(
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

    static func drawUnbraidMorph(
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

    static func drawRoundedRibbon(
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

    static func drawStatusOverlay(indicator: ProviderStatusIndicator, color: NSColor) {
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

    static func withScaledContext(_ draw: () -> Void) {
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

    static func snap(_ value: CGFloat) -> CGFloat {
        (value * self.outputScale).rounded() / self.outputScale
    }

    static func snapRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: self.snap(x), y: self.snap(y), width: self.snap(width), height: self.snap(height))
    }

    static func renderImage(isTemplate: Bool, _ draw: () -> Void) -> NSImage {
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
