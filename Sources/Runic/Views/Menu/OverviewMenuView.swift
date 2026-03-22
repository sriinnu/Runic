import AppKit
import Charts
import RunicCore
import SwiftUI

/// Overview showing all enabled providers at a glance — usage bars, today's tokens, and a combined chart.
@MainActor
struct OverviewMenuView: View {
    struct ProviderSummary: Identifiable {
        let id: String
        let provider: UsageProvider
        let name: String
        let icon: NSImage?
        let usedPercent: Double
        let todayTokens: Int
        let brandColor: Color
        let resetDescription: String?
    }

    struct DailyPoint: Identifiable {
        let id: String
        let date: Date
        let tokens: Int
        let provider: String
    }

    let summaries: [ProviderSummary]
    let chartPoints: [DailyPoint]
    let totalTodayTokens: Int
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Overview")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                Spacer()
                if self.totalTodayTokens > 0 {
                    Text("\(UsageFormatter.tokenCountString(self.totalTodayTokens)) today")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Provider rows
            if self.summaries.isEmpty {
                Text("No providers enabled.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: RunicSpacing.xs) {
                    ForEach(self.summaries) { summary in
                        HStack(spacing: RunicSpacing.xs) {
                            // Provider icon
                            if let icon = summary.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                            }

                            // Name
                            Text(summary.name)
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.medium)
                                .frame(width: 60, alignment: .leading)
                                .lineLimit(1)

                            // Mini progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(nsColor: .separatorColor).opacity(0.2))
                                    Capsule()
                                        .fill(summary.brandColor)
                                        .frame(width: max(0, geo.size.width * min(1, summary.usedPercent / 100)))
                                }
                            }
                            .frame(height: 6)

                            // Percentage
                            Text("\(Int(summary.usedPercent))%")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }

            // Combined 7-day chart
            if !self.chartPoints.isEmpty {
                Divider()
                    .padding(.vertical, RunicSpacing.xxxs)

                Text("Last 7 days")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)

                Chart {
                    ForEach(self.chartPoints) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Tokens", point.tokens))
                            .foregroundStyle(by: .value("Provider", point.provider))
                    }
                }
                .chartForegroundStyleScale(range: self.chartColors)
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel {
                            if let tokens = value.as(Int.self) {
                                Text(UsageFormatter.tokenCountString(tokens))
                                    .font(.system(size: 8, design: .rounded))
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.short))
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .frame(height: 70)
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.sm)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private var chartColors: [Color] {
        self.summaries.map(\.brandColor)
    }
}
