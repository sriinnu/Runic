import AppKit
import Charts
import RunicCore
import SwiftUI

// MARK: - Hero Today Stat (Feature 4)

/// Large bold today usage stat with provider icon — inspired by Tokex "2h 21m Today usage".
@MainActor
struct HeroTodayStatView: View {
    let providerIcon: NSImage?
    let tokenCount: Int
    let costUSD: Double?
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        HStack(alignment: .center, spacing: RunicSpacing.xs) {
            if let icon = self.providerIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: RunicSpacing.xxs) {
                    Text(UsageFormatter.tokenCountString(self.tokenCount))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
                    Text("today")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                }
            }
            Spacer()
            if let cost = self.costUSD, cost > 0 {
                Text(UsageFormatter.usdString(cost))
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                    .padding(.horizontal, RunicSpacing.xs)
                    .padding(.vertical, RunicSpacing.xxxs)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(RunicColors.Opacity.light))
                    )
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xxs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today usage: \(UsageFormatter.tokenCountString(self.tokenCount)) tokens\(self.costUSD.map { ", \(UsageFormatter.usdString($0))" } ?? "")")
    }
}

// MARK: - Glassmorphism Stat Cards (Feature 2)

/// Two side-by-side frosted glass cards: Peak Hour + This Week — inspired by Tokex.
@MainActor
struct GlassmorphismStatCardsView: View {
    let peakHourLabel: String
    let peakHourTokens: String
    let hourlySparkline: [Int]
    let weekTotalTokens: String
    let dailySparkline: [Int]
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
            GlassStatCard(
                title: "Peak Hour",
                value: self.peakHourLabel,
                detail: self.peakHourTokens,
                sparkline: self.hourlySparkline,
                sparkColor: Color(red: 0.34, green: 0.56, blue: 1.0),
                isHighlighted: self.isHighlighted)
            GlassStatCard(
                title: "This Week",
                value: self.weekTotalTokens,
                detail: nil,
                sparkline: self.dailySparkline,
                sparkColor: Color(nsColor: .systemGray),
                isHighlighted: self.isHighlighted)
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xxs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Peak hour \(self.peakHourLabel), \(self.peakHourTokens). This week \(self.weekTotalTokens)")
    }
}

private struct GlassStatCard: View {
    let title: String
    let value: String
    let detail: String?
    let sparkline: [Int]
    let sparkColor: Color
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            Text(self.title)
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            MiniSparklineView(data: self.sparkline, color: self.sparkColor)
                .frame(height: 24)
            Text(self.value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
            if let detail {
                Text(detail)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
        }
        .padding(RunicSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(RunicColors.Opacity.medium), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .glassShimmer()
    }
}

/// Lightweight sparkline with gradient fill — no Swift Charts overhead.
private struct MiniSparklineView: View {
    let data: [Int]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let maxVal = self.data.max() ?? 0
            if self.data.count >= 2, maxVal > 0 {
                let points = self.normalizedPoints(size: geo.size, max: maxVal)
                // Filled gradient area under the line
                Path { path in
                    path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                    for point in points { path.addLine(to: point) }
                    path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [self.color.opacity(0.25), self.color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom))
                // Line stroke
                Path { path in
                    path.move(to: points[0])
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(self.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            } else if self.data.count == 1, maxVal > 0 {
                // Single data point: show a dot
                Circle()
                    .fill(self.color)
                    .frame(width: 4, height: 4)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    private func normalizedPoints(size: CGSize, max maxVal: Int) -> [CGPoint] {
        let count = self.data.count
        guard count >= 2 else { return [] }
        let step = size.width / CGFloat(count - 1)
        let yPadding: CGFloat = 3
        let usableHeight = size.height - yPadding * 2
        return self.data.enumerated().map { index, value in
            let x = CGFloat(index) * step
            let y = yPadding + usableHeight * (1 - CGFloat(value) / CGFloat(maxVal))
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Updated Ago Timestamp (Feature 7)

/// Shows "Updated X ago" with second-level precision.
@MainActor
struct UpdatedTimestampView: View {
    let updatedAt: Date
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let text = Self.relativeString(from: self.updatedAt, to: context.date)
            Text(text)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted).opacity(0.7))
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xxxs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.relativeString(from: self.updatedAt, to: Date()))
    }

    private static func relativeString(from date: Date, to now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 5 { return "Updated just now" }
        if seconds < 60 { return "Updated \(seconds)s ago" }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes < 60 {
            if remainingSeconds > 0 {
                return "Updated \(minutes)m \(remainingSeconds)s ago"
            }
            return "Updated \(minutes)m ago"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "Updated \(hours)h \(remainingMinutes)m ago"
    }
}
