import SwiftUI

/// A shimmer loading skeleton that mirrors the `MenuCardView` layout.
/// Shown when `store.isFetching` and no cached data exists.
@MainActor
struct MenuCardSkeletonView: View {
    let width: CGFloat

    // MARK: - Placeholder dimensions

    private static let avatarSize: CGFloat = 40
    private static let nameBarWidth: CGFloat = 100
    private static let nameBarHeight: CGFloat = 14
    private static let emailBarWidth: CGFloat = 140
    private static let emailBarHeight: CGFloat = 10
    private static let progressBarHeight: CGFloat = 8
    private static let subtitleBarWidth: CGFloat = 80
    private static let subtitleBarHeight: CGFloat = 10

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = self.shimmerPhase(date: timeline.date)

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                // Header row: avatar + text placeholders
                HStack(alignment: .center, spacing: RunicSpacing.sm) {
                    // Avatar placeholder
                    RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                        .fill(self.shimmerGradient(phase: phase))
                        .frame(width: Self.avatarSize, height: Self.avatarSize)

                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        // Provider name placeholder
                        RoundedRectangle(cornerRadius: RunicCornerRadius.xs, style: .continuous)
                            .fill(self.shimmerGradient(phase: phase))
                            .frame(width: Self.nameBarWidth, height: Self.nameBarHeight)

                        // Email placeholder
                        RoundedRectangle(cornerRadius: RunicCornerRadius.xs, style: .continuous)
                            .fill(self.shimmerGradient(phase: phase))
                            .frame(width: Self.emailBarWidth, height: Self.emailBarHeight)
                    }

                    Spacer()
                }

                // Subtitle placeholder
                RoundedRectangle(cornerRadius: RunicCornerRadius.xs, style: .continuous)
                    .fill(self.shimmerGradient(phase: phase))
                    .frame(width: Self.subtitleBarWidth, height: Self.subtitleBarHeight)

                Divider()
                    .padding(.vertical, RunicSpacing.xxs)

                // Usage section title placeholder
                RoundedRectangle(cornerRadius: RunicCornerRadius.xs, style: .continuous)
                    .fill(self.shimmerGradient(phase: phase))
                    .frame(width: 80, height: Self.nameBarHeight)

                // Progress bar placeholder
                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                    .fill(self.shimmerGradient(phase: phase))
                    .frame(height: Self.progressBarHeight)

                // Percent label placeholder
                RoundedRectangle(cornerRadius: RunicCornerRadius.xs, style: .continuous)
                    .fill(self.shimmerGradient(phase: phase))
                    .frame(width: 60, height: Self.subtitleBarHeight)
            }
            .padding(.horizontal, MenuCardMetrics.horizontalPadding)
            .padding(.top, MenuCardMetrics.headerTopPadding)
            .padding(.bottom, MenuCardMetrics.headerBottomPadding)
            .frame(width: self.width, alignment: .leading)
            .animation(RunicAnimation.shimmer, value: phase)
        }
    }

    // MARK: - Shimmer helpers

    /// Computes a repeating phase (0...1) from the timeline date for the sliding gradient.
    private func shimmerPhase(date: Date) -> Double {
        let seconds = date.timeIntervalSinceReferenceDate
        let period: Double = 1.5
        return (seconds.truncatingRemainder(dividingBy: period)) / period
    }

    /// A sliding `LinearGradient` that produces the shimmer effect.
    private func shimmerGradient(phase: Double) -> LinearGradient {
        let baseColor = Color(nsColor: .separatorColor).opacity(0.3)
        let highlightColor = Color(nsColor: .separatorColor).opacity(0.6)

        let leading = max(0, phase - 0.3)
        let trailing = min(1, phase + 0.3)

        return LinearGradient(
            stops: [
                .init(color: baseColor, location: max(0, leading - 0.01)),
                .init(color: highlightColor, location: phase),
                .init(color: baseColor, location: min(1, trailing + 0.01)),
            ],
            startPoint: .leading,
            endPoint: .trailing)
    }
}
