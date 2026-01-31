import SwiftUI

/// Smooth progress bar with animated fill.
struct UsageProgressBar: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @State private var animatedPercent: Double = 0

    private let barHeight: CGFloat = 7

    private var clamped: Double {
        min(100, max(0, self.percent))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = (self.animatedPercent / 100) * width
            let trackColor = MenuHighlightStyle.progressTrack(self.isHighlighted)
            let tintColor = MenuHighlightStyle.progressTint(self.isHighlighted, fallback: self.tint)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)

                if fillWidth > 0 {
                    Capsule()
                        .fill(self.fillGradient(base: tintColor))
                        .frame(width: max(fillWidth, self.barHeight))
                }
            }
            .frame(width: width, height: self.barHeight, alignment: .leading)
        }
        .frame(height: self.barHeight)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(self.clamped)) percent")
        .drawingGroup()
        .onAppear {
            self.animatedPercent = self.clamped
        }
        .onChange(of: self.clamped) { _, newValue in
            withAnimation(.easeOut(duration: 0.35)) {
                self.animatedPercent = newValue
            }
        }
    }

    private func fillGradient(base: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                base.opacity(0.95),
                base.opacity(0.75),
            ],
            startPoint: .top,
            endPoint: .bottom)
    }
}
