import Charts
import RunicCore
import SwiftUI

/// Multi-line chart overlaying session and weekly usage % — inspired by Tokex dual-line chart.
/// Y-axis 0-100%, two colored lines for different rate windows.
@MainActor
struct UsageWindowComparisonChartMenuView: View {
    private struct PercentPoint: Identifiable {
        let id: String
        let date: Date
        let percent: Double
        let series: String
    }

    private let dailySummaries: [UsageLedgerDailySummary]
    private let primaryLabel: String
    private let secondaryLabel: String?
    private let primaryPercent: Double
    private let secondaryPercent: Double?
    private let width: CGFloat

    init(
        dailySummaries: [UsageLedgerDailySummary],
        primaryLabel: String,
        secondaryLabel: String?,
        primaryPercent: Double,
        secondaryPercent: Double?,
        width: CGFloat)
    {
        self.dailySummaries = dailySummaries
        self.primaryLabel = primaryLabel
        self.secondaryLabel = secondaryLabel
        self.primaryPercent = primaryPercent
        self.secondaryPercent = secondaryPercent
        self.width = width
    }

    private static let primaryColor = RunicColors.chartColor(at: 0)
    private static let secondaryColor = RunicColors.chartColor(at: 1)

    var body: some View {
        let model = Self.makeModel(
            from: self.dailySummaries,
            primaryLabel: self.primaryLabel,
            secondaryLabel: self.secondaryLabel,
            primaryPercent: self.primaryPercent,
            secondaryPercent: self.secondaryPercent)

        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Windows")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)

            if model.points.isEmpty {
                Text("No usage window data available.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(model.points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("%", point.percent),
                            series: .value("Window", point.series))
                            .foregroundStyle(point.series == self.primaryLabel ? Self.primaryColor : Self.secondaryColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                            .foregroundStyle(Color(nsColor: .separatorColor).opacity(0.5))
                        AxisValueLabel {
                            if let pct = value.as(Int.self) {
                                Text("\(pct)%")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                            .foregroundStyle(Color(nsColor: .separatorColor).opacity(0.3))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .chartLegend(.hidden)
                .frame(height: RunicSpacing.chartHeight + 20)

                // Legend
                HStack(spacing: RunicSpacing.md) {
                    HStack(spacing: RunicSpacing.xxs) {
                        Circle()
                            .fill(Self.primaryColor)
                            .frame(width: RunicSpacing.chartLegendDot, height: RunicSpacing.chartLegendDot)
                        Text(self.primaryLabel)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if let secondaryLabel = self.secondaryLabel {
                        HStack(spacing: RunicSpacing.xxs) {
                            Circle()
                                .fill(Self.secondaryColor)
                                .frame(width: RunicSpacing.chartLegendDot, height: RunicSpacing.chartLegendDot)
                            Text(secondaryLabel)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .chartPanelStyle(width: self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage window comparison chart")
    }

    // MARK: - Model

    private struct ComparisonModel {
        let points: [PercentPoint]
    }

    private static func makeModel(
        from summaries: [UsageLedgerDailySummary],
        primaryLabel: String,
        secondaryLabel: String?,
        primaryPercent: Double,
        secondaryPercent: Double?) -> ComparisonModel
    {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let cutoff = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart

        // Get last 7 days of daily token totals
        var tokensByDay: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        for summary in summaries where summary.dayStart >= cutoff {
            tokensByDay[summary.dayKey, default: 0] += summary.totals.totalTokens
        }

        // Today's tokens for scaling
        let todayKey = formatter.string(from: todayStart)
        let todayTokens = tokensByDay[todayKey] ?? 0

        // Scale: today's tokens maps to primaryPercent
        let primaryScale: Double = todayTokens > 0 ? primaryPercent / Double(todayTokens) : 0
        let secondaryScale: Double = if let secondaryPercent, todayTokens > 0 {
            secondaryPercent / Double(todayTokens)
        } else {
            0
        }

        var points: [PercentPoint] = []
        for offset in stride(from: -6, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: todayStart) else { continue }
            let key = formatter.string(from: date)
            let tokens = tokensByDay[key] ?? 0

            let primaryPct = min(100, Double(tokens) * primaryScale)
            points.append(PercentPoint(
                id: "\(key)-primary",
                date: date,
                percent: primaryPct,
                series: primaryLabel))

            if secondaryLabel != nil {
                let secondaryPct = min(100, Double(tokens) * secondaryScale)
                points.append(PercentPoint(
                    id: "\(key)-secondary",
                    date: date,
                    percent: secondaryPct,
                    series: secondaryLabel ?? ""))
            }
        }

        return ComparisonModel(points: points)
    }
}
