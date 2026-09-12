import SwiftUI

// MARK: - Cut-out shape

/// A rounded rectangle whose edges wobble like a hand-cut sticker. Each
/// straight edge is subdivided and every vertex nudged by a seeded amount,
/// so the outline is never machine-straight but never changes between
/// redraws either. Corners stay smooth quadratic arcs.
struct RunicCutoutRect: Shape {
    var cornerRadius: CGFloat
    /// Maximum edge deviation in points. 0.7 reads as "cut with scissors";
    /// above 1.5 it starts to read as damage.
    var wobble: CGFloat = 0.7
    var seed: UInt64 = 7

    func path(in rect: CGRect) -> Path {
        let r = min(self.cornerRadius, min(rect.width, rect.height) / 2)
        guard rect.width > r * 2 + 4, rect.height > r * 2 + 4 else {
            return Path(roundedRect: rect, cornerRadius: r, style: .continuous)
        }
        var rng = RunicSeededRandom(seed: self.seed &+ UInt64(rect.width * 3 + rect.height * 5))
        func jitter() -> CGFloat {
            CGFloat(rng.nextUnit() - 0.5) * 2 * self.wobble
        }
        func points(from a: CGPoint, to b: CGPoint) -> [CGPoint] {
            let length = hypot(b.x - a.x, b.y - a.y)
            let steps = max(1, Int(length / 22))
            var out: [CGPoint] = []
            for i in 1..<max(steps, 1) {
                let t = CGFloat(i) / CGFloat(steps)
                let x = a.x + (b.x - a.x) * t
                let y = a.y + (b.y - a.y) * t
                // Perpendicular nudge only, so edges stay edges.
                if abs(b.x - a.x) > abs(b.y - a.y) {
                    out.append(CGPoint(x: x, y: y + jitter()))
                } else {
                    out.append(CGPoint(x: x + jitter(), y: y))
                }
            }
            return out
        }

        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        var p = Path()
        // Top edge, left to right.
        p.move(to: CGPoint(x: minX + r, y: minY))
        for pt in points(from: CGPoint(x: minX + r, y: minY), to: CGPoint(x: maxX - r, y: minY)) {
            p.addLine(to: pt)
        }
        p.addLine(to: CGPoint(x: maxX - r, y: minY))
        p.addQuadCurve(to: CGPoint(x: maxX, y: minY + r), control: CGPoint(x: maxX, y: minY))
        // Right edge.
        for pt in points(from: CGPoint(x: maxX, y: minY + r), to: CGPoint(x: maxX, y: maxY - r)) {
            p.addLine(to: pt)
        }
        p.addLine(to: CGPoint(x: maxX, y: maxY - r))
        p.addQuadCurve(to: CGPoint(x: maxX - r, y: maxY), control: CGPoint(x: maxX, y: maxY))
        // Bottom edge, right to left.
        for pt in points(from: CGPoint(x: maxX - r, y: maxY), to: CGPoint(x: minX + r, y: maxY)) {
            p.addLine(to: pt)
        }
        p.addLine(to: CGPoint(x: minX + r, y: maxY))
        p.addQuadCurve(to: CGPoint(x: minX, y: maxY - r), control: CGPoint(x: minX, y: maxY))
        // Left edge.
        for pt in points(from: CGPoint(x: minX, y: maxY - r), to: CGPoint(x: minX, y: minY + r)) {
            p.addLine(to: pt)
        }
        p.addLine(to: CGPoint(x: minX, y: minY + r))
        p.addQuadCurve(to: CGPoint(x: minX + r, y: minY), control: CGPoint(x: minX, y: minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Sticker chrome

/// Paper-craft chrome for a surface: a hard offset shadow in ink, a white
/// halo just outside the outline, and the wobbly marker outline itself.
/// No-op unless the theme's border style is `cutout`, so it can sit on
/// every card, button and control alongside the retro bevel.
///
/// Layering (back to front): shadow → halo → the view's own background →
/// ink outline. The halo is a wide stroke centred on the edge; the view's
/// fill covers its inner half, leaving a white rim outside.
@MainActor
struct RunicCutoutChrome: ViewModifier {
    @Environment(\.runicTheme) private var runicTheme
    let radius: CGFloat
    /// Scales shadow offset. 1 for a card at rest, ~1.4 hovered, ~0.5 for
    /// small controls.
    var lift: Double = 1
    var seed: UInt64 = 7
    /// Degrees. Stickers are rarely stuck down perfectly straight; a degree
    /// or two on small chrome (tabs, the mascot) sells the hand-placed look.
    /// Keep cards at 0 — text must stay level.
    var tilt: Double = 0
    /// Off = plain passthrough, for chrome that is only a sticker in one
    /// state (a selected sidebar row).
    var enabled: Bool = true

    func body(content: Content) -> some View {
        if self.runicTheme.isPaperCutout, self.enabled {
            let ink = self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity)
            let inkWidth = max(1, self.runicTheme.style.chrome.borderWeight)
            let halo: CGFloat = 2.8
            let shape = RunicCutoutRect(cornerRadius: self.radius, seed: self.seed)
            content
                .background {
                    // Shadow and halo both have the sticker's own footprint
                    // cut out, so a translucent fill on top never shows
                    // them through as a gray or white wash.
                    ZStack {
                        RunicCutoutShadow(
                            shape: shape,
                            offset: CGSize(width: 2.5 * self.lift, height: 3 * self.lift))
                            .fill(self.runicTheme.primaryText.opacity(0.30), style: FillStyle(eoFill: false))
                        RunicCutoutHalo(shape: shape, width: inkWidth + halo * 2)
                            .fill(Color.white)
                    }
                    .allowsHitTesting(false)
                }
                .overlay {
                    shape
                        .stroke(ink, style: StrokeStyle(lineWidth: inkWidth, lineCap: .round, lineJoin: .round))
                        .allowsHitTesting(false)
                }
                .rotationEffect(.degrees(self.tilt))
        } else {
            content
        }
    }
}

/// The sticker's hard shadow: the outline shifted by `offset`, minus the
/// outline itself, so only the part peeking out past the edge is painted.
struct RunicCutoutShadow: Shape {
    let shape: RunicCutoutRect
    let offset: CGSize

    func path(in rect: CGRect) -> Path {
        let body = self.shape.path(in: rect)
        let shifted = self.shape.path(in: rect.offsetBy(dx: self.offset.width, dy: self.offset.height))
        return shifted.subtracting(body)
    }
}

/// The white rim outside the outline: a wide stroke minus the interior.
struct RunicCutoutHalo: Shape {
    let shape: RunicCutoutRect
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        let body = self.shape.path(in: rect)
        let rim = body.strokedPath(StrokeStyle(lineWidth: self.width, lineJoin: .round))
        return rim.subtracting(body)
    }
}

extension View {
    /// Sticker chrome (shadow, halo, marker outline). No-op off paper themes.
    @MainActor
    func runicCutout(
        radius: CGFloat,
        lift: Double = 1,
        seed: UInt64 = 7,
        tilt: Double = 0,
        enabled: Bool = true)
        -> some View
    {
        self.modifier(RunicCutoutChrome(radius: radius, lift: lift, seed: seed, tilt: tilt, enabled: enabled))
    }
}

// MARK: - Stage

/// The full paper-craft backdrop: a sky, a cream sheet glued over it with
/// a cut top edge, pencil hatching on the sheet only, hills along the
/// bottom, and a few stickers (clouds, a star) in the sky. `skyBand` is
/// how much sky shows above the sheet — the folder-tab strip lives there.
/// Zero means the sheet covers the whole surface and only the hills show.
@MainActor
struct RunicPaperStage: View {
    @Environment(\.runicTheme) private var runicTheme
    var skyBand: CGFloat = 0
    var hillHeight: CGFloat = 72

    /// Decorative pastel sky. Fixed rather than derived: the palette's
    /// `secondary` is a text-safe ink, far too dark for a backdrop.
    static let sky = Color(red: 0.69, green: 0.85, blue: 0.94)
    /// Sticker yellow for the star. Decorative only, never text.
    static let starYellow = Color(red: 0.96, green: 0.78, blue: 0.20)
    /// Craft-binder pastels for selected folder tabs: peach, butter, mint,
    /// sky, lilac. Light enough that ink text clears 4.5:1 on every one;
    /// mixed from the palette's dark inks they went muddy.
    static let pastels: [Color] = [
        Color(red: 0.96, green: 0.78, blue: 0.65), // peach
        Color(red: 0.97, green: 0.87, blue: 0.55), // butter
        Color(red: 0.75, green: 0.89, blue: 0.75), // mint
        Color(red: 0.74, green: 0.88, blue: 0.95), // sky
        Color(red: 0.85, green: 0.80, blue: 0.94), // lilac
    ]

    static func pastel(_ index: Int) -> Color {
        self.pastels[((index % self.pastels.count) + self.pastels.count) % self.pastels.count]
    }

    var body: some View {
        let ink = self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity)
        let inkWidth = max(1, self.runicTheme.style.chrome.borderWeight)
        let sheetTop = self.skyBand
        GeometryReader { proxy in
            let size = proxy.size
            // Sheet runs off the sides and bottom so only its top edge is cut.
            let sheetRect = CGRect(
                x: -24,
                y: sheetTop,
                width: size.width + 48,
                height: size.height - sheetTop + 60)
            let sheet = RunicCutoutRect(cornerRadius: 18, wobble: 0.9, seed: 31)
            ZStack(alignment: .topLeading) {
                Self.sky
                if self.skyBand > 0 {
                    RunicSkyStickers(inkColor: ink, inkWidth: inkWidth, sheet: self.runicTheme.cardFill)
                        .frame(width: size.width, height: self.skyBand)
                }
                // The sheet: halo, shadow, paper, outline — in that order.
                ZStack {
                    sheet.stroke(Color.white, lineWidth: inkWidth + 6)
                    sheet.fill(self.runicTheme.primaryText.opacity(0.22))
                        .offset(y: -3)
                    sheet.fill(self.runicTheme.surface)
                    RunicSurfaceTextureOverlay()
                        .clipShape(sheet)
                    sheet.stroke(ink, style: StrokeStyle(lineWidth: inkWidth, lineJoin: .round))
                }
                .frame(width: sheetRect.width, height: sheetRect.height)
                .offset(x: sheetRect.minX, y: sheetRect.minY)
                VStack {
                    Spacer(minLength: 0)
                    RunicPaperSceneryStrip(height: self.hillHeight)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Two clouds and a star, stuck on the sky band. Seeded placement.
private struct RunicSkyStickers: View {
    let inkColor: Color
    let inkWidth: CGFloat
    let sheet: Color

    var body: some View {
        Canvas { context, size in
            guard size.width > 80, size.height > 20 else { return }
            func cloud(cx: CGFloat, cy: CGFloat, cr: CGFloat) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: cx - cr * 2.2, y: cy + cr * 0.6))
                p.addArc(
                    center: CGPoint(x: cx - cr * 1.3, y: cy + cr * 0.1),
                    radius: cr * 0.95,
                    startAngle: .degrees(150),
                    endAngle: .degrees(270),
                    clockwise: false)
                p.addArc(
                    center: CGPoint(x: cx, y: cy - cr * 0.35),
                    radius: cr * 1.25,
                    startAngle: .degrees(210),
                    endAngle: .degrees(330),
                    clockwise: false)
                p.addArc(
                    center: CGPoint(x: cx + cr * 1.4, y: cy + cr * 0.1),
                    radius: cr * 0.95,
                    startAngle: .degrees(270),
                    endAngle: .degrees(30),
                    clockwise: false)
                p.addLine(to: CGPoint(x: cx + cr * 2.2, y: cy + cr * 0.6))
                p.closeSubpath()
                return p
            }
            func star(cx: CGFloat, cy: CGFloat, r: CGFloat, tilt: CGFloat) -> Path {
                var p = Path()
                for i in 0..<10 {
                    let radius = i.isMultiple(of: 2) ? r : r * 0.48
                    let angle = tilt + CGFloat(i) * .pi / 5 - .pi / 2
                    let point = CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
                    if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
                }
                p.closeSubpath()
                return p
            }
            func sticker(_ path: Path, fill: Color, outline: CGFloat) {
                let shadow = path.applying(CGAffineTransform(translationX: 1.5, y: 2))
                context.fill(shadow, with: .color(self.inkColor.opacity(0.22)))
                context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: outline + 4, lineJoin: .round))
                context.fill(path, with: .color(fill))
                context.stroke(
                    path,
                    with: .color(self.inkColor),
                    style: StrokeStyle(lineWidth: outline, lineJoin: .round))
            }
            let w = size.width, h = size.height
            // One cloud tucked behind the strip's trailing end, the star high
            // right. Nothing on the leading side: the first tab lives there.
            sticker(cloud(cx: w * 0.93, cy: h * 0.42, cr: h * 0.16), fill: self.sheet, outline: self.inkWidth * 0.8)
            sticker(
                star(cx: w * 0.80, cy: h * 0.26, r: h * 0.13, tilt: -0.18),
                fill: RunicPaperStage.starYellow,
                outline: self.inkWidth * 0.8)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A hand-drawn marker underline: uniform weight, seeded wobble, round
/// ends, stopping a little short of the text. Used under section titles.
struct RunicMarkerUnderline: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard size.width > 6 else { return }
            var rng = RunicSeededRandom(seed: UInt64(size.width * 5 + 3))
            var path = Path()
            let steps = max(4, Int(size.width / 12))
            let midY = size.height / 2
            path.move(to: CGPoint(x: 1, y: midY + CGFloat(rng.nextUnit() - 0.5) * 0.8))
            for i in 1...steps {
                let x = CGFloat(i) / CGFloat(steps) * (size.width - 2) + 1
                path.addLine(to: CGPoint(x: x, y: midY + CGFloat(rng.nextUnit() - 0.5) * 1.2))
            }
            context.stroke(path, with: .color(self.color), style: StrokeStyle(lineWidth: size.height, lineCap: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Scenery

/// A strip of paper-cut scenery for the bottom of a surface: two hills in
/// the theme's green with marker outlines and white halos, one cloud, a
/// couple of flowers. Everything is vector and seeded, so it's crisp at any
/// width and never shimmers. Decorative; hidden from accessibility.
@MainActor
struct RunicPaperSceneryStrip: View {
    @Environment(\.runicTheme) private var runicTheme
    /// Design height of the strip. Hills fill the lower ~70%.
    var height: CGFloat = 64

    var body: some View {
        // Everything the canvas needs is captured up front: the drawing
        // closure is nonisolated and can't read the environment itself.
        let ink = self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity)
        let inkWidth = max(1, self.runicTheme.style.chrome.borderWeight)
        let green = self.runicTheme.tertiary
        let shadowInk = self.runicTheme.primaryText.opacity(0.22)
        let sheet = self.runicTheme.cardFill
        let flowerCenter = self.runicTheme.highlight
        Canvas { context, size in
            guard size.width > 40, size.height > 12 else { return }
            let w = size.width
            let h = size.height
            let base = h + 6 // hills run off the bottom edge

            func hill(centerX: CGFloat, halfWidth: CGFloat, peakY: CGFloat) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: centerX - halfWidth, y: base))
                p.addCurve(
                    to: CGPoint(x: centerX + halfWidth, y: base),
                    control1: CGPoint(x: centerX - halfWidth * 0.55, y: peakY),
                    control2: CGPoint(x: centerX + halfWidth * 0.55, y: peakY))
                p.closeSubpath()
                return p
            }
            func sticker(_ path: Path, fill: Color) {
                // Hard offset shadow, then halo, fill, outline.
                let shadow = path.applying(CGAffineTransform(translationX: 2, y: 2))
                context.fill(shadow, with: .color(shadowInk))
                context.stroke(path, with: .color(.white), lineWidth: inkWidth + 4)
                context.fill(path, with: .color(fill))
                context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: inkWidth, lineJoin: .round))
            }

            // Back hills: paler green, further away.
            let back = green.opacity(0.42)
            sticker(hill(centerX: w * 0.18, halfWidth: w * 0.30, peakY: h * 0.28), fill: back)
            sticker(hill(centerX: w * 0.80, halfWidth: w * 0.34, peakY: h * 0.20), fill: back)
            // Front hills: the theme green, closer.
            let front = green.opacity(0.62)
            sticker(hill(centerX: w * 0.50, halfWidth: w * 0.38, peakY: h * 0.50), fill: front)
            sticker(hill(centerX: w * 1.02, halfWidth: w * 0.30, peakY: h * 0.58), fill: front)

            // A cloud, top-left: one closed outline — a flat base with three
            // bumps arched over it — so the halo and ink trace the silhouette
            // rather than three separate rings.
            let cx = w * 0.14, cy = h * 0.30, cr = h * 0.11
            var cloud = Path()
            cloud.move(to: CGPoint(x: cx - cr * 2.2, y: cy + cr * 0.6))
            cloud.addArc(
                center: CGPoint(x: cx - cr * 1.3, y: cy + cr * 0.1),
                radius: cr * 0.95,
                startAngle: .degrees(150),
                endAngle: .degrees(270),
                clockwise: false)
            cloud.addArc(
                center: CGPoint(x: cx, y: cy - cr * 0.35),
                radius: cr * 1.25,
                startAngle: .degrees(210),
                endAngle: .degrees(330),
                clockwise: false)
            cloud.addArc(
                center: CGPoint(x: cx + cr * 1.4, y: cy + cr * 0.1),
                radius: cr * 0.95,
                startAngle: .degrees(270),
                endAngle: .degrees(30),
                clockwise: false)
            cloud.addLine(to: CGPoint(x: cx + cr * 2.2, y: cy + cr * 0.6))
            cloud.closeSubpath()
            context.stroke(cloud, with: .color(.white), style: StrokeStyle(lineWidth: inkWidth + 3, lineJoin: .round))
            context.fill(cloud, with: .color(sheet))
            context.stroke(cloud, with: .color(ink), style: StrokeStyle(lineWidth: inkWidth * 0.8, lineJoin: .round))

            // Two flowers on the front hill: a dot with five petals.
            var rng = RunicSeededRandom(seed: UInt64(w))
            for i in 0..<2 {
                let fx = w * (0.30 + 0.36 * CGFloat(i)) + CGFloat(rng.nextUnit() - 0.5) * 12
                let fy = h * 0.80
                let pr: CGFloat = 2.4
                for k in 0..<5 {
                    let a = CGFloat(k) / 5 * .pi * 2
                    let petal = CGRect(
                        x: fx + cos(a) * pr * 1.4 - pr,
                        y: fy + sin(a) * pr * 1.4 - pr,
                        width: pr * 2,
                        height: pr * 2)
                    context.fill(Path(ellipseIn: petal), with: .color(.white))
                    context.stroke(Path(ellipseIn: petal), with: .color(ink), lineWidth: 0.7)
                }
                context.fill(
                    Path(ellipseIn: CGRect(x: fx - pr, y: fy - pr, width: pr * 2, height: pr * 2)),
                    with: .color(flowerCenter))
            }
        }
        .frame(height: self.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
