import SwiftUI

/// Staggered fade+slide entrance animation for menu card sections.
/// Each section slides up from a slight offset and fades in, with a delay
/// proportional to its index for a cascading "liquid" reveal.
struct MenuCardEntranceModifier: ViewModifier {
    let index: Int
    @State private var appeared = false
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(self.appeared ? 1 : 0)
            .offset(y: self.reduceMotion || self.appeared ? 0 : 8)
            .scaleEffect(self.reduceMotion || self.appeared ? 1 : 0.97, anchor: .top)
            .onAppear {
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
                .clipShape(RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.lg), style: .continuous)))
            .onAppear {
                guard !self.runicTheme.isTerminalHUD, !self.reduceMotion, self.runicTheme.id == "glass" else { return }
                withAnimation(.easeInOut(duration: 2.0).delay(0.5)) {
                    self.shimmerPhase = 1.2
                }
            }
    }
}

extension View {
    /// Apply staggered entrance animation. `index` controls the delay.
    func menuCardEntrance(index: Int) -> some View {
        self.modifier(MenuCardEntranceModifier(index: index))
    }

    /// Apply a single shimmer sweep across a glass surface.
    func glassShimmer() -> some View {
        self.modifier(GlassShimmerModifier())
    }
}
