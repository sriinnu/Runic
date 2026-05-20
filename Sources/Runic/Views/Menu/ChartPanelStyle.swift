import SwiftUI

/// Clean style for chart panels in NSMenu submenus.
/// The NSMenu window provides its own chrome — we just add content padding
/// and a subtle top-edge gloss for polish without creating a double-border.
struct ChartPanelStyle: ViewModifier {
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(self.runicTheme.primaryText)
            .tint(self.runicTheme.accent)
            .padding(.horizontal, MenuCardMetrics.horizontalPadding)
            .padding(.top, RunicSpacing.sm)
            .padding(.bottom, RunicSpacing.xs)
            .frame(width: self.width, alignment: .leading)
            .background {
                ZStack {
                    self.runicTheme.menuSurfaceGradient
                    if self.runicTheme.isTerminalHUD {
                        RunicTerminalScanlineOverlay(opacity: 0.90)
                    }
                }
            }
    }
}

extension View {
    func chartPanelStyle(width: CGFloat) -> some View {
        self.modifier(ChartPanelStyle(width: width))
    }
}
