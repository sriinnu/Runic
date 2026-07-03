import SwiftUI

/// Runi — Runic's mascot. The menubar infinity mark come alive: a stroked
/// lemniscate with eyes resting in its loops. Drawn entirely with vector
/// paths (no bitmap assets) so it stays crisp from 40pt up, and themed via
/// `\.runicTheme` — body in the theme accent, eyes in primary text, and
/// supporting marks (ground, shadow, magnifier) in muted secondary text.
///
/// Decorative by contract: the view is `accessibilityHidden`; accompanying
/// text must carry the meaning.
@MainActor
struct RunicDoodle: View {
    /// What Runi is up to. Each mood maps to a family of empty/error states.
    enum Mood {
        /// Dozing on a flat line — empty / no-data states.
        case resting
        /// Peering through a tiny magnifier — no results for a filter/range.
        case searching
        /// Gently knotted — error states.
        case tangled
        /// Levitating with sparkles — all clear, nothing to report.
        case zen
    }

    let mood: Mood
    /// Design width in points. Height follows at a fixed 5:3 ratio.
    var size: CGFloat = 56

    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        RunicDoodleArt(
            mood: self.mood,
            bodyColor: self.runicTheme.accent,
            eyeColor: self.runicTheme.primaryText,
            detailColor: self.runicTheme.secondaryText.opacity(0.55))
            .frame(width: self.size, height: self.size * 0.6)
            .offset(y: self.bobOffset)
            .scaleEffect(self.breatheScale, anchor: .bottom)
            .onAppear {
                guard !self.reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                    self.breathing = true
                }
            }
            .accessibilityHidden(true)
    }

    /// Slow vertical bob for the floating moods. Kept under 2pt so the
    /// mascot feels alive without pulling focus.
    private var bobOffset: CGFloat {
        guard self.breathing else { return 0 }
        switch self.mood {
        case .zen, .searching: return -1.5
        case .resting, .tangled: return 0
        }
    }

    /// Grounded moods breathe in place instead of bobbing.
    private var breatheScale: CGFloat {
        guard self.breathing else { return 1 }
        switch self.mood {
        case .resting, .tangled: return 1.02
        case .zen, .searching: return 1
        }
    }
}

/// The static vector artwork. Split from `RunicDoodle` so tests can render
/// the drawing directly without waiting on animation state.
@MainActor
struct RunicDoodleArt: View {
    let mood: RunicDoodle.Mood
    let bodyColor: Color
    let eyeColor: Color
    let detailColor: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            guard w > 0, h > 0 else { return }

            let stroke = max(2, w * 0.062)
            let style = StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)
            let detailStyle = StrokeStyle(lineWidth: max(1, stroke * 0.45), lineCap: .round)

            // Body box: horizontally centered, vertical placement per mood.
            let rx = w * 0.40
            let ry = h * 0.26
            let floating = self.mood == .zen
            let grounded = self.mood == .resting
            let centerY = floating ? h * 0.42 : (grounded ? h * 0.60 : h * 0.50)
            let center = CGPoint(x: w * 0.5, y: centerY)

            // Supporting marks first so the body overlaps them.
            switch self.mood {
            case .resting:
                self.drawGroundLine(in: &context, width: w, y: center.y + ry + stroke * 0.75, style: detailStyle)
                self.drawSnooze(
                    in: &context,
                    at: CGPoint(x: center.x + rx * 0.9, y: center.y - ry * 1.65),
                    scale: w * 0.045)
            case .zen:
                self.drawShadow(in: &context, at: CGPoint(x: center.x, y: h * 0.88), rx: rx * 0.62, ry: h * 0.045)
            case .searching, .tangled:
                break
            }

            // Body: the lemniscate.
            let body = Self.infinityPath(center: center, rx: rx, ry: ry, knotted: self.mood == .tangled)
            context.stroke(body, with: .color(self.bodyColor), style: style)

            // Eyes sit inside the loops.
            let eyeOffsetX = rx * 0.55
            let left = CGPoint(x: center.x - eyeOffsetX, y: center.y)
            let right = CGPoint(x: center.x + eyeOffsetX, y: center.y)
            self.drawEyes(in: &context, left: left, right: right, unit: rx, stroke: stroke)

            // Foreground props.
            switch self.mood {
            case .searching:
                self.drawMagnifier(
                    in: &context,
                    at: CGPoint(x: center.x + rx * 0.98, y: center.y + ry * 1.15),
                    radius: rx * 0.22,
                    style: detailStyle)
            case .zen:
                self.drawSparkle(
                    in: &context,
                    at: CGPoint(x: center.x - rx * 1.05, y: center.y - ry * 1.3),
                    r: w * 0.030)
                self.drawSparkle(
                    in: &context,
                    at: CGPoint(x: center.x + rx * 1.10, y: center.y - ry * 0.55),
                    r: w * 0.022)
            case .resting, .tangled:
                break
            }
        }
    }

    // MARK: - Body

    /// One continuous lemniscate (∞) with a true center crossover — the same
    /// silhouette as the menubar glyph. `knotted` pulls a small extra loop
    /// tight around the crossing for the error mood.
    static func infinityPath(center c: CGPoint, rx: CGFloat, ry: CGFloat, knotted: Bool) -> Path {
        var p = Path()
        p.move(to: c)
        p.addCurve(
            to: CGPoint(x: c.x - rx, y: c.y),
            control1: CGPoint(x: c.x - rx * 0.353, y: c.y - ry * 1.35),
            control2: CGPoint(x: c.x - rx, y: c.y - ry * 1.24))
        p.addCurve(
            to: c,
            control1: CGPoint(x: c.x - rx, y: c.y + ry * 1.24),
            control2: CGPoint(x: c.x - rx * 0.353, y: c.y + ry * 1.35))
        p.addCurve(
            to: CGPoint(x: c.x + rx, y: c.y),
            control1: CGPoint(x: c.x + rx * 0.353, y: c.y - ry * 1.35),
            control2: CGPoint(x: c.x + rx, y: c.y - ry * 1.24))
        p.addCurve(
            to: c,
            control1: CGPoint(x: c.x + rx, y: c.y + ry * 1.24),
            control2: CGPoint(x: c.x + rx * 0.353, y: c.y + ry * 1.35))
        p.closeSubpath()
        if knotted {
            p.addEllipse(in: CGRect(
                x: c.x - rx * 0.28,
                y: c.y - rx * 0.28,
                width: rx * 0.56,
                height: rx * 0.56))
        }
        return p
    }

    // MARK: - Eyes

    private func drawEyes(
        in context: inout GraphicsContext,
        left: CGPoint,
        right: CGPoint,
        unit: CGFloat,
        stroke: CGFloat)
    {
        let r = unit * 0.085
        let lidStyle = StrokeStyle(lineWidth: max(1.2, stroke * 0.6), lineCap: .round)
        switch self.mood {
        case .searching:
            // Bright dot eyes, glancing toward the magnifier.
            let shift = CGSize(width: unit * 0.06, height: unit * 0.05)
            for eye in [left, right] {
                let rect = CGRect(
                    x: eye.x + shift.width - r,
                    y: eye.y + shift.height - r,
                    width: r * 2,
                    height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(self.eyeColor))
            }
        case .resting:
            // Softly closed lids: shallow arcs, drooping at the edges.
            for eye in [left, right] {
                var lid = Path()
                lid.move(to: CGPoint(x: eye.x - r * 1.5, y: eye.y))
                lid.addQuadCurve(
                    to: CGPoint(x: eye.x + r * 1.5, y: eye.y),
                    control: CGPoint(x: eye.x, y: eye.y + r * 1.3))
                context.stroke(lid, with: .color(self.eyeColor), style: lidStyle)
            }
        case .zen:
            // Content closed eyes: calm upward arcs.
            for eye in [left, right] {
                var lid = Path()
                lid.move(to: CGPoint(x: eye.x - r * 1.5, y: eye.y + r * 0.4))
                lid.addQuadCurve(
                    to: CGPoint(x: eye.x + r * 1.5, y: eye.y + r * 0.4),
                    control: CGPoint(x: eye.x, y: eye.y - r * 1.6))
                context.stroke(lid, with: .color(self.eyeColor), style: lidStyle)
            }
        case .tangled:
            // Wide, startled ring eyes.
            for eye in [left, right] {
                let rect = CGRect(x: eye.x - r * 1.1, y: eye.y - r * 1.1, width: r * 2.2, height: r * 2.2)
                context.stroke(Path(ellipseIn: rect), with: .color(self.eyeColor), style: lidStyle)
            }
        }
    }

    // MARK: - Props

    private func drawGroundLine(in context: inout GraphicsContext, width: CGFloat, y: CGFloat, style: StrokeStyle) {
        var line = Path()
        line.move(to: CGPoint(x: width * 0.08, y: y))
        line.addLine(to: CGPoint(x: width * 0.92, y: y))
        context.stroke(line, with: .color(self.detailColor), style: style)
    }

    private func drawShadow(in context: inout GraphicsContext, at point: CGPoint, rx: CGFloat, ry: CGFloat) {
        let rect = CGRect(x: point.x - rx, y: point.y - ry, width: rx * 2, height: ry * 2)
        context.fill(Path(ellipseIn: rect), with: .color(self.detailColor.opacity(0.5)))
    }

    /// A single tiny "z" drifting up — the universal doze cue, kept small.
    private func drawSnooze(in context: inout GraphicsContext, at point: CGPoint, scale s: CGFloat) {
        var z = Path()
        z.move(to: CGPoint(x: point.x - s, y: point.y - s))
        z.addLine(to: CGPoint(x: point.x + s, y: point.y - s))
        z.addLine(to: CGPoint(x: point.x - s, y: point.y + s))
        z.addLine(to: CGPoint(x: point.x + s, y: point.y + s))
        context.stroke(
            z,
            with: .color(self.detailColor),
            style: StrokeStyle(lineWidth: max(1, s * 0.4), lineCap: .round, lineJoin: .round))
    }

    private func drawMagnifier(
        in context: inout GraphicsContext,
        at point: CGPoint,
        radius: CGFloat,
        style: StrokeStyle)
    {
        let lens = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: lens), with: .color(self.detailColor), style: style)
        var handle = Path()
        let start = CGPoint(x: point.x + radius * 0.72, y: point.y + radius * 0.72)
        handle.move(to: start)
        handle.addLine(to: CGPoint(x: start.x + radius * 0.85, y: start.y + radius * 0.85))
        context.stroke(
            handle,
            with: .color(self.detailColor),
            style: StrokeStyle(lineWidth: style.lineWidth * 1.6, lineCap: .round))
    }

    /// Four-point sparkle in the body color — the single focal accent.
    private func drawSparkle(in context: inout GraphicsContext, at point: CGPoint, r: CGFloat) {
        var star = Path()
        let pinch = r * 0.22
        star.move(to: CGPoint(x: point.x, y: point.y - r))
        star.addQuadCurve(
            to: CGPoint(x: point.x + r, y: point.y),
            control: CGPoint(x: point.x + pinch, y: point.y - pinch))
        star.addQuadCurve(
            to: CGPoint(x: point.x, y: point.y + r),
            control: CGPoint(x: point.x + pinch, y: point.y + pinch))
        star.addQuadCurve(
            to: CGPoint(x: point.x - r, y: point.y),
            control: CGPoint(x: point.x - pinch, y: point.y + pinch))
        star.addQuadCurve(
            to: CGPoint(x: point.x, y: point.y - r),
            control: CGPoint(x: point.x - pinch, y: point.y - pinch))
        star.closeSubpath()
        context.fill(star, with: .color(self.bodyColor.opacity(0.85)))
    }
}
