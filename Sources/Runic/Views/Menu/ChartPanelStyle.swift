import SwiftUI

/// Liquid-style modifier for chart panels in NSMenu submenus.
/// Layered glass background with inner glow, top-edge highlight, and depth shadow.
struct ChartPanelStyle: ViewModifier {
    let width: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, MenuCardMetrics.horizontalPadding + 2)
            .padding(.top, RunicSpacing.sm)
            .padding(.bottom, RunicSpacing.xs)
            .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    // Base: subtle solid tint for depth
                    RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))

                    // Glass layer
                    RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Top-edge highlight (liquid gloss)
                    RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.08), location: 0),
                                    .init(color: .white.opacity(0.02), location: 0.3),
                                    .init(color: .clear, location: 0.5),
                                ],
                                startPoint: .top,
                                endPoint: .bottom))

                    // Inner glow at edges
                    RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.18), location: 0),
                                    .init(color: .white.opacity(0.06), location: 0.4),
                                    .init(color: Color(nsColor: .separatorColor).opacity(0.15), location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom),
                            lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            )
            .padding(RunicSpacing.xxs + 2)
    }
}

extension View {
    func chartPanelStyle(width: CGFloat) -> some View {
        self.modifier(ChartPanelStyle(width: width))
    }
}
