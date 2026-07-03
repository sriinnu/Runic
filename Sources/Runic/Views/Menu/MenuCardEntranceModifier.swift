import SwiftUI

/// Staggered fade+slide entrance animation for menu card sections.
/// Each section slides up from a slight offset and fades in, with a delay
/// proportional to its index for a cascading "liquid" reveal.
///
/// Pass `animated: false` for refresh-driven repopulates of an already-open
/// menu: the cascade should only play on first open, not replay every time a
/// background store write rebuilds the visible menu.
struct MenuCardEntranceModifier: ViewModifier {
    let index: Int
    let animated: Bool
    @State private var appeared: Bool
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(index: Int, animated: Bool) {
        self.index = index
        self.animated = animated
        self._appeared = State(initialValue: !animated)
    }

    func body(content: Content) -> some View {
        content
            .opacity(self.appeared ? 1 : 0)
            .offset(y: self.reduceMotion || self.appeared ? 0 : 8)
            .scaleEffect(self.reduceMotion || self.appeared ? 1 : 0.97, anchor: .top)
            .onAppear {
                guard !self.appeared else { return }
                let delay = Double(self.index) * RunicAnimation.cardEntranceStagger
                withAnimation(self.runicTheme.motion.delayedCurve(reduceMotion: self.reduceMotion, delay: delay)) {
                    self.appeared = true
                }
            }
    }
}

/// Subtle continuous shimmer sweep on glass surfaces.
struct GlassShimmerModifier: ViewModifier {
    @State private var shimmerPhase: CGFloat = -1
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if !self.runicTheme.isTerminalHUD, !self.reduceMotion, self.runicTheme.id == "glass" {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: max(0, self.shimmerPhase - 0.15)),
                                .init(color: .white.opacity(0.06), location: self.shimmerPhase),
                                .init(color: .clear, location: min(1, self.shimmerPhase + 0.15)),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(
                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.lg),
                    style: .continuous)))
            .onAppear {
                guard !self.runicTheme.isTerminalHUD, !self.reduceMotion, self.runicTheme.id == "glass" else { return }
                withAnimation(.easeInOut(duration: 2.0).delay(0.5)) {
                    self.shimmerPhase = 1.2
                }
            }
    }
}

extension View {
    /// Apply staggered entrance animation. `index` controls the delay;
    /// `animated: false` renders the settled state immediately.
    func menuCardEntrance(index: Int, animated: Bool = true) -> some View {
        self.modifier(MenuCardEntranceModifier(index: index, animated: animated))
    }

    /// Apply a single shimmer sweep across a glass surface.
    func glassShimmer() -> some View {
        self.modifier(GlassShimmerModifier())
    }
}
