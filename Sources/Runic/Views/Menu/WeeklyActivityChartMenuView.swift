import Charts
import RunicCore
import SwiftUI

/// Bar chart showing the last 7 days of usage — inspired by Tokex "Last 7 Days".
@MainActor
struct WeeklyActivityChartMenuView: View {
    private struct DayBar: Identifiable {
        let id: String
        let date: Date
        let dayLabel: String
        let totalTokens: Int
        let isToday: Bool

        var weekdayShort: String {
            self.date.formatted(.dateTime.weekday(.short))
        }
    }

    private let dailySummaries: [UsageLedgerDailySummary]
    private let width: CGFloat
    init(dailySummaries: [UsageLedgerDailySummary], width: CGFloat) {
        self.dailySummaries = dailySummaries
        self.width = width
    }

    private static let barColor = Color(nsColor: .systemGray).opacity(0.4)
    private static let todayColor = RunicColors.chartColor(at: 0)

    var body: some View {
        let model = Self.makeModel(from: self.dailySummaries)

        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 7 Days")
                    .font(RunicFont.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if model.bars.count > 1 {
                    let avg = model.totalTokens / max(1, model.bars.filter { $0.totalTokens > 0 }.count)
                    Text("\(UsageFormatter.tokenCountString(avg)) avg")
                        .font(RunicFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if model.bars.allSatisfy({ $0.totalTokens == 0 }) {
                Text("No usage in the last 7 days.")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(model.bars) { bar in
                        BarMark(
                            x: .value("Day", bar.weekdayShort),
                            y: .value("Tokens", bar.totalTokens))
                            .foregroundStyle(bar.isToday ? Self.todayColor : Self.barColor)
                            .cornerRadius(RunicCornerRadius.sm)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(RunicFont.caption2)
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                            .foregroundStyle(Color(nsColor: .separatorColor).opacity(0.5))
                        AxisValueLabel {
                            if let tokens = value.as(Int.self) {
                                Text(UsageFormatter.tokenCountString(tokens))
                                    .font(RunicFont.caption2)
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: RunicSpacing.chartHeight - 40)
            }
        }
        .chartPanelStyle(width: self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last 7 days usage bar chart")
    }

    // MARK: - Model

    private struct WeeklyModel {
        let bars: [DayBar]
        let totalTokens: Int
    }

    private static func makeModel(from summaries: [UsageLedgerDailySummary]) -> WeeklyModel {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // Build lookup by dayKey
        var tokensByDayKey: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        for summary in summaries {
            tokensByDayKey[summary.dayKey, default: 0] += summary.totals.totalTokens
        }

        // Generate last 7 days
        var bars: [DayBar] = []
        for offset in stride(from: -6, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: todayStart) else { continue }
            let key = formatter.string(from: date)
            let tokens = tokensByDayKey[key] ?? 0
            let isToday = offset == 0
            let dayLabel = date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            bars.append(DayBar(
                id: key,
                date: date,
                dayLabel: dayLabel,
                totalTokens: tokens,
                isToday: isToday))
        }

        let total = bars.reduce(0) { $0 + $1.totalTokens }
        return WeeklyModel(bars: bars, totalTokens: total)
    }
}
