import SwiftUI

/// Modern progress bar with gradient fill, glow effects, and smooth animations.
///
/// Features:
/// - Gradient fill for depth and visual interest
/// - Subtle glow/shadow on the filled portion
/// - Smooth animations with spring physics
/// - Multiple height options for different contexts
/// - Accessible with VoiceOver support
/// - Adapts to menu highlight state
struct UsageProgressBar: View {
    /// Height variants for different use cases
    enum Height {
        case compact    // 6pt - for dense layouts, team member rows
        case regular    // 8pt - default, used in most menus
        case large      // 10pt - for prominent displays

        var value: CGFloat {
            switch self {
            case .compact: return 6
            case .regular: return 8
            case .large: return 10
            }
        }
    }

    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    let height: Height

    @Environment(\.menuItemHighlighted) private var isHighlighted
    @State private var animatedPercent: Double = 0
    @State private var sheenPhase: CGFloat = 0
    @State private var sheenTask: Task<Void, Never>?

    init(
        percent: Double,
        tint: Color,
        accessibilityLabel: String,
        height: Height = .regular)
    {
        self.percent = percent
        self.tint = tint
        self.accessibilityLabel = accessibilityLabel
        self.height = height
    }

    private var clamped: Double {
        min(100, max(0, self.percent))
    }

    private var barHeight: CGFloat {
        self.height.value
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = (self.animatedPercent / 100) * width
            let trackColor = Color(nsColor: .tertiaryLabelColor).opacity(self.isHighlighted ? RunicColors.Opacity.medium : RunicColors.Opacity.medium)
            let tintColor = self.tint

            ZStack(alignment: .leading) {
                // Background track with depth
                Capsule()
                    .fill(trackColor)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                trackColor.opacity(RunicColors.Opacity.strong),
                                lineWidth: 0.5)
                    }
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(self.isHighlighted ? RunicColors.Opacity.subtle : RunicColors.Opacity.light),
                                        Color.clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom))
                    }

                // Tick marks (subtle)
                ForEach([0.25, 0.5, 0.75], id: \.self) { fraction in
                    Rectangle()
                        .fill(Color.white.opacity(RunicColors.Opacity.light))
                        .frame(width: 1, height: self.barHeight - 2)
                        .offset(x: width * fraction - 0.5)
                        .blendMode(.screen)
                }

                // Filled portion with gradient, texture, and glow
                if fillWidth > 0 {
                    Capsule()
                        .fill(self.fillGradient(base: tintColor))
                        .frame(width: max(fillWidth, self.barHeight))
                        .shadow(
                            color: tintColor.opacity(self.isHighlighted ? 0 : 0.3),
                            radius: self.barHeight * 0.4,
                            x: 0,
                            y: 0)
                        .overlay {
                            ZStack {
                                // Subtle highlight on top for glossy effect
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(RunicColors.Opacity.medium),
                                                Color.clear,
                                            ],
                                            startPoint: .top,
                                            endPoint: .center))
                                    .frame(width: max(fillWidth, self.barHeight))

                                // Texture segments for a premium "status bar" look
                                self.segmentTexture(width: max(fillWidth, self.barHeight))
                            }
                        }
                        .overlay {
                            if fillWidth > self.barHeight * 2 {
                                self.sheenOverlay(width: max(fillWidth, self.barHeight), tint: tintColor)
                            }
                        }

                    // End cap glow
                    let capSize = self.barHeight * 0.9
                    let capX = min(max(fillWidth, capSize / 2), width - capSize / 2)
                    Circle()
                        .fill(tintColor)
                        .frame(width: capSize, height: capSize)
                        .shadow(color: tintColor.opacity(RunicColors.Opacity.strong), radius: 4, x: 0, y: 0)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(RunicColors.Opacity.emphasis), lineWidth: 0.5))
                        .offset(x: capX - capSize / 2)
                }
            }
            .frame(width: width, height: self.barHeight, alignment: .leading)
        }
        .frame(height: self.barHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(self.clamped)) percent")
        .accessibilityAddTraits(.updatesFrequently)
        .drawingGroup(opaque: false)
        .onAppear {
            // Initial animation with slight delay for staggered effect
            withAnimation(RunicAnimation.barAppear) {
                self.animatedPercent = self.clamped
            }
            self.playSheen()
        }
        .onChange(of: self.clamped) { _, newValue in
            // Smooth spring animation on value changes
            withAnimation(RunicAnimation.barUpdate) {
                self.animatedPercent = newValue
            }
            self.playSheen()
        }
    }

    /// Creates a modern gradient fill with depth
    private func fillGradient(base: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                base.opacity(0.98),
                base.opacity(0.85),
                base.opacity(0.92),
            ],
            startPoint: .top,
            endPoint: .bottom)
    }

    private func segmentTexture(width: CGFloat) -> some View {
        let count = max(6, Int(width / 22))
        return HStack(spacing: RunicSpacing.xxxs) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(self.isHighlighted ? RunicColors.Opacity.subtle : RunicColors.Opacity.light))
            }
        }
        .padding(.horizontal, RunicSpacing.xxxs)
        .padding(.vertical, 1)
        .mask(Capsule())
    }

    private func sheenOverlay(width: CGFloat, tint: Color) -> some View {
        let gradient = LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(self.isHighlighted ? 0.2 : 0.45),
                Color.white.opacity(0.0),
            ],
            startPoint: .top,
            endPoint: .bottom)
        let travel = width + self.barHeight * 2
        let offset = (self.sheenPhase * travel) - (travel / 2)

        return Rectangle()
            .fill(gradient)
            .frame(width: self.barHeight * 2, height: self.barHeight * 2)
            .rotationEffect(.degrees(20))
            .offset(x: offset)
            .mask(Capsule().frame(width: width, height: self.barHeight))
            .blendMode(.screen)
    }

    private func playSheen() {
        self.sheenTask?.cancel()
        self.sheenPhase = 0
        withAnimation(.easeOut(duration: RunicAnimation.sheenDuration)) {
            self.sheenPhase = 1
        }
        self.sheenTask = Task { @MainActor in
            try? await Task.sleep(for: RunicAnimation.sheenResetDelay)
            self.sheenPhase = 0
        }
    }
}
