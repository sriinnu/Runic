import Charts
import RunicCore
import SwiftUI

/// Subscription utilization chart — shows daily usage as % bars with Daily/Weekly/Monthly picker.
/// Inspired by CodexBar "Subscription Utilization" submenu.
@MainActor
struct SubscriptionUtilizationChartMenuView: View {
    enum Period: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    private struct UtilizationBar: Identifiable {
        let id: String
        let label: String
        let date: Date
        let usedPercent: Double
        let isToday: Bool
    }

    private let dailySummaries: [UsageLedgerDailySummary]
    private let currentUsedPercent: Double
    private let todayTokens: Int
    private let width: CGFloat
    @State private var selectedPeriod: Period = .daily

    init(
        dailySummaries: [UsageLedgerDailySummary],
        currentUsedPercent: Double,
        todayTokens: Int,
        width: CGFloat)
    {
        self.dailySummaries = dailySummaries
        self.currentUsedPercent = currentUsedPercent
        self.todayTokens = todayTokens
        self.width = width
    }

    private static let barColor = RunicColors.chartColor(at: 4)  // teal
    private static let wastedColor = Color(nsColor: .systemGray).opacity(0.2)

    var body: some View {
        let model = Self.makeModel(
            from: self.dailySummaries,
            period: self.selectedPeriod,
            currentUsedPercent: self.currentUsedPercent,
            todayTokens: self.todayTokens)

        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Utilization")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)

            Picker("", selection: self.$selectedPeriod) {
                ForEach(Period.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if model.bars.isEmpty {
                Text("No utilization data available.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(model.bars) { bar in
                        BarMark(
                            x: .value("Period", bar.label),
                            y: .value("Used %", bar.usedPercent))
                            .foregroundStyle(bar.isToday ? Self.barColor : Self.barColor.opacity(0.6))
                            .cornerRadius(RunicCornerRadius.xs)
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
                        AxisValueLabel()
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .chartLegend(.hidden)
                .frame(height: RunicSpacing.chartHeight - 10)

                // Latest detail
                if let latest = model.bars.last {
                    let used = Int(latest.usedPercent.rounded())
                    let unused = max(0, 100 - used)
                    Text("\(latest.label): \(used)% used, \(unused)% unused")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartPanelStyle(width: self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Subscription utilization chart")
    }

    // MARK: - Model

    private struct UtilizationModel {
        let bars: [UtilizationBar]
    }

    private static func makeModel(
        from summaries: [UsageLedgerDailySummary],
        period: Period,
        currentUsedPercent: Double,
        todayTokens: Int) -> UtilizationModel
    {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        // Build token counts by day
        var tokensByDay: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        for summary in summaries {
            tokensByDay[summary.dayKey, default: 0] += summary.totals.totalTokens
        }

        // Scale factor: map today's tokens to the current used %
        let scaleFactor: Double = todayTokens > 0 ? currentUsedPercent / Double(todayTokens) : 0

        switch period {
        case .daily:
            let bars = (0..<14).compactMap { offset -> UtilizationBar? in
                guard let date = calendar.date(byAdding: .day, value: offset - 13, to: todayStart) else { return nil }
                let key = formatter.string(from: date)
                let tokens = tokensByDay[key] ?? 0
                let pct = min(100, Double(tokens) * scaleFactor)
                let label = date.formatted(.dateTime.day().month(.abbreviated))
                let isToday = offset == 13
                return UtilizationBar(id: key, label: label, date: date, usedPercent: pct, isToday: isToday)
            }
            return UtilizationModel(bars: bars)

        case .weekly:
            // Aggregate by ISO week
            var weekBuckets: [(label: String, tokens: Int, date: Date, isThisWeek: Bool)] = []
            for weekOffset in stride(from: -3, through: 0, by: 1) {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: todayStart) else { continue }
                var total = 0
                for dayOffset in 0..<7 {
                    guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                    total += tokensByDay[formatter.string(from: date)] ?? 0
                }
                let label = "W\(calendar.component(.weekOfYear, from: weekStart))"
                weekBuckets.append((label, total, weekStart, weekOffset == 0))
            }
            let maxWeekTokens = weekBuckets.map(\.tokens).max() ?? 1
            let bars = weekBuckets.map { bucket in
                let pct = maxWeekTokens > 0 ? Double(bucket.tokens) / Double(maxWeekTokens) * 100 : 0
                return UtilizationBar(id: bucket.label, label: bucket.label, date: bucket.date, usedPercent: pct, isToday: bucket.isThisWeek)
            }
            return UtilizationModel(bars: bars)

        case .monthly:
            var monthBuckets: [(label: String, tokens: Int, date: Date, isThisMonth: Bool)] = []
            for monthOffset in stride(from: -2, through: 0, by: 1) {
                guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: todayStart) else { continue }
                let monthComponents = calendar.dateComponents([.year, .month], from: monthStart)
                guard let actualMonthStart = calendar.date(from: monthComponents),
                      let range = calendar.range(of: .day, in: .month, for: actualMonthStart) else { continue }
                var total = 0
                for dayOffset in 0..<range.count {
                    guard let date = calendar.date(byAdding: .day, value: dayOffset, to: actualMonthStart) else { continue }
                    total += tokensByDay[formatter.string(from: date)] ?? 0
                }
                let label = monthStart.formatted(.dateTime.month(.abbreviated))
                monthBuckets.append((label, total, monthStart, monthOffset == 0))
            }
            let maxMonthTokens = monthBuckets.map(\.tokens).max() ?? 1
            let bars = monthBuckets.map { bucket in
                let pct = maxMonthTokens > 0 ? Double(bucket.tokens) / Double(maxMonthTokens) * 100 : 0
                return UtilizationBar(id: bucket.label, label: bucket.label, date: bucket.date, usedPercent: pct, isToday: bucket.isThisMonth)
            }
            return UtilizationModel(bars: bars)
        }
    }
}
