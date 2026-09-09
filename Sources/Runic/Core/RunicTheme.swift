import AppKit
import SwiftUI

// MARK: - Runtime palette

struct RunicThemePalette {
    let id: String
    let displayName: String
    let tagline: String
    let symbolName: String
    let isCustom: Bool
    let prefersDarkAppearance: Bool?
    let primary: Color
    let secondary: Color
    let accent: Color
    let highlight: Color
    let warm: Color
    let tertiary: Color
    let surface: Color
    let surfaceAlt: Color
    let cardFill: Color
    let cardStroke: Color
    let primaryText: Color
    let secondaryText: Color

    // Non-color identity. Defaults keep existing themes backward-compatible;
    // themes that want a distinct personality override at the call site.
    var fonts: RunicThemeFonts = .system
    var shape: RunicThemeShape = .standard
    var motion: RunicThemeMotion = .standard
    var density: RunicThemeDensity = .normal
    var style: RunicThemeStyle = .standard

    var swatchColors: [Color] {
        [self.primary, self.accent, self.highlight, self.tertiary]
    }

    var isTerminalHUD: Bool {
        self.id == "terminal"
    }

    /// Theme-owned checkbox chrome (accent-filled box, theme stroke) for
    /// every opinionated theme. Only System and Dark keep the native
    /// checkbox, which follows the macOS accent and reads foreign everywhere
    /// else.
    var prefersRetroToggleChrome: Bool {
        self.isCustom || self.isTerminalHUD
    }

    var readableSecondaryText: Color {
        self.secondaryText(minimumAlpha: self.isTerminalHUD ? 0.92 : 0.86)
    }

    var subduedSecondaryText: Color {
        self.secondaryText(minimumAlpha: self.isTerminalHUD ? 0.84 : 0.78)
    }

    var chartScanlineOpacity: Double {
        self.style.effects.scanlineOpacity
    }

    var meshColors: [Color] {
        if self.isTerminalHUD {
            [self.surface, self.accent, self.highlight, self.secondary, self.tertiary]
        } else {
            [self.primary, self.secondary, self.accent, self.warm, self.tertiary]
        }
    }

    func chartColor(at index: Int) -> Color {
        let palette: [Color] = switch self.style.controls.chartSeries {
        case .monochrome:
            // Lead series takes the one accent; everything after it is a
            // ramp of the text tone so a stacked chart reads like a
            // halftone print with a single red overprint.
            [
                self.accent,
                self.primaryText.opacity(0.92),
                self.primaryText.opacity(0.64),
                self.primaryText.opacity(0.44),
                self.primaryText.opacity(0.30),
                self.highlight,
            ]
        case .themed:
            self.isTerminalHUD
                ? [self.accent, self.highlight, self.secondary, self.warm, self.tertiary, self.primary]
                : [self.accent, self.highlight, self.tertiary, self.warm, self.secondary, self.primary]
        }
        return palette[index % palette.count]
    }

    /// Whether the theme paints a full-surface texture (paper fibre, film
    /// grain). Callers add `RunicSurfaceTextureOverlay` behind content when
    /// this is true.
    var hasSurfaceTexture: Bool {
        self.style.effects.texture != .none && self.style.effects.textureOpacity > 0.01
    }

    /// Whether surfaces carry real light: raised cards, recessed wells.
    var isElevated: Bool {
        self.style.effects.elevation > 0.01
    }

    /// Shadow pair for a raised surface. `lift` scales both (hover = 1.4).
    func elevationShadows(lift: Double = 1) -> (ambient: (Color, CGFloat, CGFloat), key: (Color, CGFloat, CGFloat)) {
        let strength = self.style.effects.elevation * lift
        let ink = self.primaryText
        return (
            ambient: (ink.opacity(0.10 * strength), 14 * lift, 6 * lift),
            key: (ink.opacity(0.16 * strength), 2.5, 1.5))
    }

    /// Top-edge highlight for a raised surface — the lamp catching the rim.
    var elevationRimColor: Color {
        Color.white.opacity(0.85 * self.style.effects.elevation)
    }

    /// Inner shadow tone for a recessed well.
    var elevationWellShadow: Color {
        self.primaryText.opacity(0.22 * self.style.effects.elevation)
    }

    /// Card-surface fill that switches to frosted material on Glass theme.
    /// Lets every existing `fill(menuCardGradient)` callsite become themed by
    /// swapping `.menuCardGradient` → `.cardBackgroundStyle`. Other themes
    /// keep their gradient; Glass gets actual translucency.
    var cardBackgroundStyle: AnyShapeStyle {
        if self.id == "glass" {
            return AnyShapeStyle(.regularMaterial)
        }
        return AnyShapeStyle(self.menuCardGradient)
    }

    /// Outer-surface fill that switches to thin material on Glass theme.
    var surfaceBackgroundStyle: AnyShapeStyle {
        if self.id == "glass" {
            return AnyShapeStyle(.thinMaterial)
        }
        return AnyShapeStyle(self.menuSurfaceGradient)
    }

    var menuSurfaceGradient: LinearGradient {
        if self.hasSurfaceTexture || self.isElevated {
            // Paper and film need a solid ground — the texture is the depth.
            // A translucent tail here let the desktop bleed through the panel.
            LinearGradient(
                colors: [self.surface, self.surfaceAlt.opacity(1.0), self.surface],
                startPoint: .top,
                endPoint: .bottom)
        } else if self.isTerminalHUD {
            LinearGradient(
                colors: [
                    self.surface,
                    self.surfaceAlt.opacity(0.72),
                    self.surface,
                ],
                startPoint: .top,
                endPoint: .bottom)
        } else {
            LinearGradient(
                colors: [
                    self.surface.opacity(self.isCustom ? 0.98 : 0.88),
                    self.surfaceAlt.opacity(self.isCustom ? 0.92 : 0.62),
                    self.cardFill.opacity(self.isCustom ? 0.72 : 0.44),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        }
    }

    var menuCardGradient: LinearGradient {
        if self.isTerminalHUD {
            LinearGradient(
                colors: [
                    self.cardFill.opacity(0.88),
                    self.surface.opacity(0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        } else {
            LinearGradient(
                colors: [
                    self.cardFill.opacity(self.isCustom ? 0.92 : 0.52),
                    self.surfaceAlt.opacity(self.isCustom ? 0.72 : 0.38),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        }
    }

    var menuTrackColor: Color {
        self.isTerminalHUD
            ? self.accent.opacity(0.12 + self.style.effects.scanlineOpacity * 0.12)
            : self.cardStroke.opacity(self.isCustom ? 0.42 : 0.26)
    }

    var menuSubtleFill: Color {
        self.isTerminalHUD ? self.cardFill.opacity(0.40) : self.cardFill.opacity(self.isCustom ? 0.62 : 0.34)
    }

    var chartGridColor: Color {
        self.isTerminalHUD ? self.accent.opacity(0.20) : self.cardStroke.opacity(self.isCustom ? 0.58 : 0.42)
    }

    var chartAxisLabelColor: Color {
        self.isTerminalHUD ? self.readableSecondaryText : self.secondaryText(minimumAlpha: self.isCustom ? 0.88 : 0.82)
    }

    var chartSelectionBandColor: Color {
        self.isTerminalHUD ? self.accent.opacity(0.10) : self.primaryText.opacity(self.isCustom ? 0.12 : 0.08)
    }

    /// Emphasis color for a chart's peak bar/annotation. Every theme keeps
    /// its `highlight` here — series colors lead with `accent`, so the
    /// highlight pole reads as "peak" in all bundled palettes. (Was a
    /// degenerate ternary that returned `highlight` in both branches.)
    var chartPeakColor: Color {
        self.highlight
    }

    var menuHoverFill: Color {
        self.isTerminalHUD ? self.accent.opacity(0.16) : self.accent.opacity(self.isCustom ? 0.20 : 0.14)
    }

    var menuSeparatorColor: Color {
        self.isTerminalHUD
            ? self.accent.opacity(0.24 + self.style.chrome.borderOpacity * 0.32)
            : self.cardStroke.opacity(self.isCustom ? self.style.chrome.borderOpacity : 0.48)
    }

    var nsPrimaryTextColor: NSColor {
        self.nsColor(self.primaryText, fallback: .labelColor)
    }

    var nsSecondaryTextColor: NSColor {
        self.nsColor(self.secondaryText, fallback: .secondaryLabelColor)
    }

    var nsAccentColor: NSColor {
        self.nsColor(self.accent, fallback: .controlAccentColor)
    }

    var nsWarmColor: NSColor {
        self.nsColor(self.warm, fallback: .systemRed)
    }

    var colorScheme: ColorScheme? {
        switch self.prefersDarkAppearance {
        case nil: nil
        case .some(true): .dark
        case .some(false): .light
        }
    }

    var nsAppearance: NSAppearance? {
        guard let prefersDarkAppearance else { return nil }
        return NSAppearance(named: prefersDarkAppearance ? .darkAqua : .aqua)
    }

    var nsCardStrokeColor: NSColor {
        self.nsColor(self.cardStroke, fallback: .separatorColor)
    }

    var nsMenuSubtleFillColor: NSColor {
        self.nsColor(self.menuSubtleFill, fallback: .controlBackgroundColor)
    }

    /// Convert a SwiftUI `Color` to a deviceRGB `NSColor`, falling back to
    /// the supplied AppKit color when conversion fails (e.g., dynamic system
    /// colors that need a context to resolve). Public so AppKit-only code
    /// like `IconRenderer` can read the theme accent ramp.
    func nsColor(_ color: Color, fallback: NSColor = .controlAccentColor) -> NSColor {
        NSColor(color).usingColorSpace(.deviceRGB) ?? fallback
    }

    private func secondaryText(minimumAlpha: CGFloat) -> Color {
        let ns = self.nsColor(self.secondaryText, fallback: .secondaryLabelColor)
        guard ns.alphaComponent < minimumAlpha else { return self.secondaryText }
        return Color(nsColor: ns.withAlphaComponent(minimumAlpha))
    }
}

extension EnvironmentValues {
    @Entry var runicTheme: RunicThemePalette = Theme.system.palette
}

/// Theme-aware separator. Renders ASCII when a theme asks for it, a glowing
/// accent line for glow themes, and a hairline for everyone else. Use this
/// instead of SwiftUI's `Divider()` inside menu / preferences surfaces so
/// inner section breaks carry the theme's personality.
@MainActor
struct RunicDivider: View {
    @Environment(\.runicTheme) private var runicTheme
    var opacity: Double = 1.0

    var body: some View {
        Group {
            switch self.runicTheme.shape.separator {
            case .ascii:
                Text(String(repeating: "─", count: 96))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(self.runicTheme.menuSeparatorColor.opacity(0.55 * self.opacity))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
            case .glow:
                Rectangle()
                    .fill(LinearGradient(
                        colors: [
                            .clear,
                            self.runicTheme.accent.opacity(0.48 * self.opacity),
                            self.runicTheme.highlight.opacity(0.36 * self.opacity),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing))
                    .frame(height: 1)
                    .shadow(color: self.runicTheme.accent.opacity(0.28 * self.opacity), radius: 3.5)
            case .brush:
                RunicBrushStrokeRule(color: self.runicTheme.primaryText.opacity(0.62 * self.opacity))
                    .frame(height: 3)
            case .rule:
                Rectangle()
                    .fill(self.runicTheme.primaryText.opacity(0.78 * self.opacity))
                    .frame(height: 1.5)
            case .hairline:
                Rectangle()
                    .fill(self.runicTheme.menuSeparatorColor.opacity(0.65 * self.opacity))
                    .frame(height: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A single sumi brush stroke: starts thick where the brush lands, thins as
/// it lifts, with a slight wobble so no two spans look machine-drawn. The
/// wobble is seeded from the width so it stays put across redraws.
struct RunicBrushStrokeRule: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard size.width > 8 else { return }
            var rng = RunicSeededRandom(seed: UInt64(size.width * 7 + 13))
            let midY = size.height / 2
            let steps = max(12, Int(size.width / 14))
            var top = Path()
            var bottom: [CGPoint] = []
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let x = t * size.width
                // Thick head (0.9 of height), tapering to a hair at the tail.
                let thickness = max(0.35, (1 - t * t) * size.height * 0.9)
                let wobble = CGFloat(rng.nextUnit() - 0.5) * 0.5
                let y = midY + wobble
                let p1 = CGPoint(x: x, y: y - thickness / 2)
                let p2 = CGPoint(x: x, y: y + thickness / 2)
                if i == 0 { top.move(to: p1) } else { top.addLine(to: p1) }
                bottom.append(p2)
            }
            for point in bottom.reversed() {
                top.addLine(to: point)
            }
            top.closeSubpath()
            context.fill(top, with: .color(self.color))
            // Dry-brush breakup near the tail.
            for _ in 0..<6 {
                let x = size.width * (0.55 + 0.42 * CGFloat(rng.nextUnit()))
                let len = 2 + 5 * CGFloat(rng.nextUnit())
                var dash = Path()
                dash.move(to: CGPoint(x: x, y: midY))
                dash.addLine(to: CGPoint(x: min(size.width, x + len), y: midY + CGFloat(rng.nextUnit() - 0.5) * 0.8))
                context.stroke(dash, with: .color(self.color.opacity(0.55)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Tiny deterministic generator for texture overlays. Same seed, same
/// picture — textures must never flicker between redraws.
struct RunicSeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &* 0x9E37_79B9_7F4A_7C15 | 1
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        self.state ^= self.state >> 12
        self.state ^= self.state << 25
        self.state ^= self.state >> 27
        return self.state &* 0x2545_F491_4F6C_DD1D
    }

    mutating func nextUnit() -> Double {
        Double(self.next() >> 11) / Double(1 << 53)
    }
}

/// Full-surface texture for themes that ask for one. `paper` scatters washi
/// fibres plus a warm edge vignette; `grain` lays film grain, a heavy dark
/// vignette, and faint diagonal light slats. Drawn once per size, seeded, so
/// it reads as material rather than noise.
@MainActor
struct RunicSurfaceTextureOverlay: View {
    @Environment(\.runicTheme) private var runicTheme
    /// Scale applied on top of the theme's `textureOpacity` so inner panels
    /// can run lighter than the outer surface.
    var strength: Double = 1.0

    var body: some View {
        let effects = self.runicTheme.style.effects
        let opacity = effects.textureOpacity * self.strength
        Group {
            switch effects.texture {
            case .none:
                EmptyView()
            case .paper:
                RunicPaperTextureCanvas(opacity: opacity, ink: self.runicTheme.primaryText, warm: self.runicTheme.warm)
            case .grain:
                RunicFilmGrainCanvas(opacity: opacity, light: self.runicTheme.primaryText)
            case .grid:
                RunicDraftingGridCanvas(opacity: opacity, ink: self.runicTheme.primaryText)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct RunicPaperTextureCanvas: View {
    let opacity: Double
    let ink: Color
    let warm: Color

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            var rng = RunicSeededRandom(seed: UInt64(size.width * 31 + size.height * 17))
            let fibres = Int((size.width * size.height) / 520)
            for _ in 0..<fibres {
                let x = CGFloat(rng.nextUnit()) * size.width
                let y = CGFloat(rng.nextUnit()) * size.height
                let length = 4 + CGFloat(rng.nextUnit()) * 16
                let angle = CGFloat(rng.nextUnit()) * .pi
                var fibre = Path()
                fibre.move(to: CGPoint(x: x, y: y))
                fibre.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
                let alpha = 0.035 + 0.05 * rng.nextUnit()
                context.stroke(fibre, with: .color(self.ink.opacity(alpha * self.opacity)), lineWidth: 0.45)
            }
            // A handful of faint warm blotches — the uneven sizing of real washi.
            for _ in 0..<max(3, Int(size.width / 90)) {
                let x = CGFloat(rng.nextUnit()) * size.width
                let y = CGFloat(rng.nextUnit()) * size.height
                let radius = 24 + CGFloat(rng.nextUnit()) * 60
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [self.warm.opacity(0.035 * self.opacity), .clear]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: radius))
            }
            // Edge vignette, warm and light-handed.
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    Gradient(colors: [.clear, .clear, self.ink.opacity(0.06 * self.opacity)]),
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.78))
        }
    }
}

/// Drafting-paper grid: a fine rule every 8pt, a heavier one every 40pt,
/// drawn in the ink tone at low opacity. No randomness — a blueprint is
/// exact by definition.
private struct RunicDraftingGridCanvas: View {
    let opacity: Double
    let ink: Color

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let minor = self.ink.opacity(0.045 * self.opacity)
            let major = self.ink.opacity(0.11 * self.opacity)
            var x: CGFloat = 0.5
            var column = 0
            while x < size.width {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(column % 5 == 0 ? major : minor), lineWidth: 0.5)
                x += 8
                column += 1
            }
            var y: CGFloat = 0.5
            var row = 0
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(row % 5 == 0 ? major : minor), lineWidth: 0.5)
                y += 8
                row += 1
            }
        }
    }
}

private struct RunicFilmGrainCanvas: View {
    let opacity: Double
    let light: Color

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            var rng = RunicSeededRandom(seed: UInt64(size.width * 53 + size.height * 29))
            let grains = Int((size.width * size.height) / 95)
            for _ in 0..<grains {
                let x = CGFloat(rng.nextUnit()) * size.width
                let y = CGFloat(rng.nextUnit()) * size.height
                let d = 0.6 + CGFloat(rng.nextUnit()) * 0.9
                let alpha = 0.03 + 0.09 * rng.nextUnit()
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)),
                    with: .color(self.light.opacity(alpha * self.opacity)))
            }
            // Venetian-blind light: three soft diagonal slats.
            let slatSpacing = max(48, size.height / 5)
            var slatY: CGFloat = -size.width * 0.35
            while slatY < size.height {
                var slat = Path()
                slat.move(to: CGPoint(x: 0, y: slatY + size.width * 0.35))
                slat.addLine(to: CGPoint(x: size.width, y: slatY))
                slat.addLine(to: CGPoint(x: size.width, y: slatY + 14))
                slat.addLine(to: CGPoint(x: 0, y: slatY + size.width * 0.35 + 14))
                slat.closeSubpath()
                context.fill(slat, with: .color(self.light.opacity(0.022 * self.opacity)))
                slatY += slatSpacing
            }
            // Heavy vignette — the corners fall into black.
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    Gradient(colors: [
                        .clear,
                        Color.black.opacity(0.10 * self.opacity),
                        Color.black.opacity(0.55 * self.opacity),
                    ]),
                    center: CGPoint(x: size.width / 2, y: size.height * 0.42),
                    startRadius: min(size.width, size.height) * 0.25,
                    endRadius: max(size.width, size.height) * 0.85))
        }
    }
}

@MainActor
struct RunicTerminalScanlineOverlay: View {
    let opacity: Double
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            let lineColor = self.runicTheme.accent.opacity(0.060 * self.opacity)
            let faintColor = self.runicTheme.accent.opacity(0.030 * self.opacity)
            var y: CGFloat = 1.5
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(lineColor), lineWidth: 0.5)
                y += 4
            }

            var gridY: CGFloat = 16
            while gridY < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: gridY))
                line.addLine(to: CGPoint(x: size.width, y: gridY))
                context.stroke(line, with: .color(faintColor), lineWidth: 0.7)
                gridY += 16
            }

            let glowHeight = min(72, size.height * 0.28)
            context.fill(
                Path(CGRect(x: 0, y: 0, width: size.width, height: glowHeight)),
                with: .linearGradient(
                    Gradient(colors: [
                        self.runicTheme.accent.opacity(0.050 * self.opacity),
                        .clear,
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: glowHeight)))
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
struct RunicTerminalCornerOverlay: View {
    let inset: CGFloat
    let length: CGFloat
    let lineWidth: CGFloat
    let opacity: Double
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Canvas { context, size in
            guard size.width > self.inset * 2, size.height > self.inset * 2 else { return }

            let left = self.inset
            let right = size.width - self.inset
            let top = self.inset
            let bottom = size.height - self.inset
            let length = min(self.length, min(size.width, size.height) / 3)
            let style = StrokeStyle(lineWidth: self.lineWidth, lineCap: .square, lineJoin: .miter)
            let color = self.runicTheme.accent.opacity(self.opacity)

            var path = Path()
            path.move(to: CGPoint(x: left, y: top + length))
            path.addLine(to: CGPoint(x: left, y: top))
            path.addLine(to: CGPoint(x: left + length, y: top))

            path.move(to: CGPoint(x: right - length, y: top))
            path.addLine(to: CGPoint(x: right, y: top))
            path.addLine(to: CGPoint(x: right, y: top + length))

            path.move(to: CGPoint(x: right, y: bottom - length))
            path.addLine(to: CGPoint(x: right, y: bottom))
            path.addLine(to: CGPoint(x: right - length, y: bottom))

            path.move(to: CGPoint(x: left + length, y: bottom))
            path.addLine(to: CGPoint(x: left, y: bottom))
            path.addLine(to: CGPoint(x: left, y: bottom - length))

            context.stroke(path, with: .color(color), style: style)
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
private struct RunicMenuPanelChrome: ViewModifier {
    @Environment(\.runicTheme) private var runicTheme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(self.runicTheme.primaryText)
            .tint(self.runicTheme.accent)
            .background {
                ZStack {
                    self.runicTheme.menuSurfaceGradient
                    if self.runicTheme.isTerminalHUD {
                        RunicTerminalScanlineOverlay(opacity: self.runicTheme.style.effects.scanlineOpacity)
                    }
                    if self.runicTheme.hasSurfaceTexture {
                        RunicSurfaceTextureOverlay()
                    }
                }
            }
    }
}

extension View {
    @ViewBuilder
    func runicColorScheme(_ palette: RunicThemePalette) -> some View {
        if let colorScheme = palette.colorScheme {
            self.environment(\.colorScheme, colorScheme)
        } else {
            self
        }
    }

    func runicMenuPanelChrome() -> some View {
        self.modifier(RunicMenuPanelChrome())
    }
}

// MARK: - Elevation

/// Raise a surface on the theme's two-light shadow, with a rim highlight
/// along the top edge. No-op on flat themes so it can sit on every card.
@MainActor
struct RunicRaisedSurface: ViewModifier {
    @Environment(\.runicTheme) private var runicTheme
    let radius: CGFloat
    var lift: Double = 1

    func body(content: Content) -> some View {
        if self.runicTheme.isElevated {
            let shadows = self.runicTheme.elevationShadows(lift: self.lift)
            content
                .overlay(
                    RoundedRectangle(cornerRadius: self.radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [self.runicTheme.elevationRimColor, .clear, .clear],
                                startPoint: .top,
                                endPoint: .bottom),
                            lineWidth: 1)
                        .allowsHitTesting(false))
                .shadow(color: shadows.ambient.0, radius: shadows.ambient.1, y: shadows.ambient.2)
                .shadow(color: shadows.key.0, radius: shadows.key.1, y: shadows.key.2)
        } else {
            content
        }
    }
}

/// Press a control into the surface: an inner shadow along the top and
/// leading edges, a faint rim at the bottom. No-op on flat themes.
@MainActor
struct RunicRecessedWell: ViewModifier {
    @Environment(\.runicTheme) private var runicTheme
    let radius: CGFloat

    func body(content: Content) -> some View {
        if self.runicTheme.isElevated {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: self.radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [self.runicTheme.elevationWellShadow, .clear],
                                startPoint: .top,
                                endPoint: .bottom),
                            lineWidth: 1.5)
                        .blur(radius: 0.6)
                        .allowsHitTesting(false))
                .overlay(
                    RoundedRectangle(cornerRadius: self.radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.clear, self.runicTheme.elevationRimColor.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom),
                            lineWidth: 0.8)
                        .allowsHitTesting(false))
        } else {
            content
        }
    }
}

extension View {
    @MainActor
    func runicRaised(radius: CGFloat, lift: Double = 1) -> some View {
        self.modifier(RunicRaisedSurface(radius: radius, lift: lift))
    }

    @MainActor
    func runicRecessed(radius: CGFloat) -> some View {
        self.modifier(RunicRecessedWell(radius: radius))
    }
}
