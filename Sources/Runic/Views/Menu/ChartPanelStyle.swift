import SwiftUI

/// Clean style for chart panels in NSMenu submenus.
/// The NSMenu window provides its own chrome — we just add content padding
/// and a subtle top-edge gloss for polish without creating a double-border.
struct ChartPanelStyle: ViewModifier {
    let width: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, MenuCardMetrics.horizontalPadding)
            .padding(.top, RunicSpacing.sm)
            .padding(.bottom, RunicSpacing.xs)
            .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func chartPanelStyle(width: CGFloat) -> some View {
        self.modifier(ChartPanelStyle(width: width))
    }
}
