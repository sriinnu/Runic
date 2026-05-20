import SwiftUI

/// Two-layer bevel that gives the Retro theme its System-7 chrome: an outer
/// dark line (the cardStroke) and an inner light highlight (the surfaceAlt),
/// drawn as concentric rounded rectangles inside a single overlay.
///
/// Apply via `.retroBevel()` to any surface. No-op on non-Retro themes so the
/// modifier is safe to sprinkle everywhere — it only activates when the
/// active theme's `id` is `"retro"`.
@MainActor
struct RetroBevelOverlay: ViewModifier {
    @Environment(\.runicTheme) private var runicTheme

    /// Base corner radius of the surface being bevelled. The bevel uses the
    /// theme's `shape.cornerRadius()` to keep visual consistency.
    var baseRadius: CGFloat = RunicCornerRadius.lg

    /// Bevel intensity. Higher values make the highlight pop more.
    var intensity: Double = 1.0

    /// Whether the bevel reads "raised" (default — light top, dark bottom)
    /// or "inset" (dark top, light bottom). Inset is used for pressed
    /// buttons and inset cards.
    var inset: Bool = false

    func body(content: Content) -> some View {
        if self.runicTheme.id == "retro" {
            content.overlay {
                self.bevel
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else {
            content
        }
    }

    private var bevel: some View {
        let radius = self.runicTheme.shape.cornerRadius(self.baseRadius)
        let weight = max(0.45, self.runicTheme.style.chrome.borderWeight)
        let darkColor = self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity)
        let highlightColor = Color.white.opacity(0.48 * self.intensity)
        let shadowColor = Color.black.opacity(0.12 * self.intensity)

        // System-7 bevel: a full dark outer stroke + an asymmetric inner
        // highlight that only paints the top/leading edges (raised) or
        // bottom/trailing edges (inset/pressed). Drawn via a gradient mask
        // on a stroked path so we don't need brittle trim/rotate tricks.
        return ZStack {
            // Outer dark frame — the bevel's stroke.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(darkColor, lineWidth: weight)

            // Inner highlight ring, but masked to a diagonal gradient so it
            // fades from full opacity at top-leading to zero at bottom-trailing
            // (or reversed for inset state).
            RoundedRectangle(cornerRadius: max(radius - 1, 1), style: .continuous)
                .strokeBorder(self.inset ? shadowColor : highlightColor, lineWidth: max(0.45, weight * 0.82))
                .padding(1)
                .mask(
                    LinearGradient(
                        colors: self.inset
                            ? [.clear, .clear, .black, .black]
                            : [.black, .black, .clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
        }
    }
}

extension View {
    /// Apply the Retro two-layer bevel chrome to a surface. No-op on any
    /// other theme.
    @MainActor
    func retroBevel(
        baseRadius: CGFloat = RunicCornerRadius.lg,
        intensity: Double = 1.0,
        inset: Bool = false)
        -> some View
    {
        self.modifier(RetroBevelOverlay(baseRadius: baseRadius, intensity: intensity, inset: inset))
    }
}
