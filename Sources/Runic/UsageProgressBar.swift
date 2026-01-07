import SwiftUI

/// Static progress fill with no implicit animations, used inside the menu card.
struct UsageProgressBar: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private let segmentCount: Int = 12
    private let segmentGap: CGFloat = 2
    private let cornerRadius: CGFloat = 2

    private var clamped: Double {
        min(100, max(0, self.percent))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let gap = self.segmentGap
            let segments = self.segmentCount
            let available = max(0, width - gap * CGFloat(max(segments - 1, 0)))
            let segmentWidth = max(1, available / CGFloat(max(segments, 1)))
            let rawFill = Int((self.clamped / 100) * Double(segments))
            let fillCount = self.clamped > 0 && rawFill == 0 ? 1 : rawFill
            let trackColor = MenuHighlightStyle.progressTrack(self.isHighlighted)
            let tintColor = MenuHighlightStyle.progressTint(self.isHighlighted, fallback: self.tint)

            HStack(alignment: .center, spacing: gap) {
                ForEach(0..<segments, id: \.self) { index in
                    RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                        .fill(index < fillCount ? tintColor : trackColor)
                        .frame(width: segmentWidth)
                }
            }
            .frame(width: width, height: proxy.size.height, alignment: .leading)
        }
        .frame(height: 6)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(self.clamped)) percent")
        .drawingGroup()
    }
}
