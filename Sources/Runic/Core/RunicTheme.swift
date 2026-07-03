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

    var prefersRetroToggleChrome: Bool {
        self.id == "retro" || self.isTerminalHUD
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
        let palette = self.isTerminalHUD
            ? [self.accent, self.highlight, self.secondary, self.warm, self.tertiary, self.primary]
            : [self.accent, self.highlight, self.tertiary, self.warm, self.secondary, self.primary]
        return palette[index % palette.count]
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
        if self.isTerminalHUD {
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
            case .hairline:
                Rectangle()
                    .fill(self.runicTheme.menuSeparatorColor.opacity(0.65 * self.opacity))
                    .frame(height: 1)
            }
        }
        .accessibilityHidden(true)
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
