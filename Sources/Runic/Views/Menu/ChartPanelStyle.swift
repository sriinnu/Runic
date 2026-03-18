import SwiftUI

/// Shared liquid-style modifier for chart panels hosted in NSMenu submenus.
/// Adds glass material background, refined border, subtle shadow, and consistent spacing.
struct ChartPanelStyle: ViewModifier {
    let width: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, MenuCardMetrics.horizontalPadding)
            .padding(.vertical, RunicSpacing.sm)
            .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .separatorColor).opacity(RunicColors.Opacity.medium),
                                Color(nsColor: .separatorColor).opacity(RunicColors.Opacity.subtle),
                            ],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 0.5)
            )
            .padding(RunicSpacing.xxs)
    }
}

extension View {
    func chartPanelStyle(width: CGFloat) -> some View {
        self.modifier(ChartPanelStyle(width: width))
    }
}
