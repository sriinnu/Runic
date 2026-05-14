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
    @State private var selectedBarID: String?
    @Environment(\.runicTheme) private var runicTheme

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

    var body: some View {
        let model = Self.makeModel(
            from: self.dailySummaries,
            period: self.selectedPeriod,
            currentUsedPercent: self.currentUsedPercent,
            todayTokens: self.todayTokens)
        let barColor = self.runicTheme.chartColor(at: 4)

        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Utilization")
                .font(RunicFont.subheadline)
                .fontWeight(.semibold)

            Picker("", selection: self.$selectedPeriod) {
                ForEach(Period.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if model.bars.isEmpty {
                Text("No utilization data available.")
                    .font(RunicFont.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(model.bars) { bar in
                        BarMark(
                            x: .value("Period", bar.label),
                            y: .value("Used %", bar.usedPercent))
                            .foregroundStyle(bar.isToday ? barColor : barColor.opacity(0.6))
                            .cornerRadius(RunicCornerRadius.xs)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                            .foregroundStyle(self.runicTheme.chartGridColor)
                        AxisValueLabel {
                            if let pct = value.as(Int.self) {
                                Text("\(pct)%")
                                    .font(RunicFont.caption2)
                                    .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: model.axisLabels) { _ in
                        AxisValueLabel()
                            .font(RunicFont.caption2)
                            .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                    }
                }
                .chartLegend(.hidden)
                .frame(height: RunicSpacing.chartHeight - 10)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if let rect = self.selectionBandRect(model: model, proxy: proxy, geo: geo) {
                                RoundedRectangle(cornerRadius: RunicCornerRadius.xs, style: .continuous)
                                    .fill(self.runicTheme.chartSelectionBandColor)
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .allowsHitTesting(false)
                            }
                            MouseLocationReader { location in
                                self.updateSelection(location: location, model: model, proxy: proxy, geo: geo)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                    }
                }

                // Latest detail
                Text(self.detailText(model: model))
                    .font(RunicFont.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: 16, alignment: .leading)
            }
        }
        .chartPanelStyle(width: self.width)
        .onChange(of: self.selectedPeriod) { _, _ in
            self.selectedBarID = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Subscription utilization chart")
    }

    // MARK: - Model

    private struct UtilizationModel {
        let bars: [UtilizationBar]
        let axisLabels: [String]
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
                let label = date.formatted(.dateTime.month(.defaultDigits).day())
                let isToday = offset == 13
                return UtilizationBar(id: key, label: label, date: date, usedPercent: pct, isToday: isToday)
            }
            return UtilizationModel(bars: bars, axisLabels: Self.axisLabels(from: bars, desiredCount: 5))

        case .weekly:
            // Aggregate by ISO week
            var weekBuckets: [(label: String, tokens: Int, date: Date, isThisWeek: Bool)] = []
            for weekOffset in stride(from: -3, through: 0, by: 1) {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: todayStart)
                else { continue }
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
                return UtilizationBar(
                    id: bucket.label,
                    label: bucket.label,
                    date: bucket.date,
                    usedPercent: pct,
                    isToday: bucket.isThisWeek)
            }
            return UtilizationModel(bars: bars, axisLabels: bars.map(\.label))

        case .monthly:
            var monthBuckets: [(label: String, tokens: Int, date: Date, isThisMonth: Bool)] = []
            for monthOffset in stride(from: -2, through: 0, by: 1) {
                guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: todayStart)
                else { continue }
                let monthComponents = calendar.dateComponents([.year, .month], from: monthStart)
                guard let actualMonthStart = calendar.date(from: monthComponents),
                      let range = calendar.range(of: .day, in: .month, for: actualMonthStart) else { continue }
                var total = 0
                for dayOffset in 0..<range.count {
                    guard let date = calendar.date(byAdding: .day, value: dayOffset, to: actualMonthStart)
                    else { continue }
                    total += tokensByDay[formatter.string(from: date)] ?? 0
                }
                let label = monthStart.formatted(.dateTime.month(.abbreviated))
                monthBuckets.append((label, total, monthStart, monthOffset == 0))
            }
            let maxMonthTokens = monthBuckets.map(\.tokens).max() ?? 1
            let bars = monthBuckets.map { bucket in
                let pct = maxMonthTokens > 0 ? Double(bucket.tokens) / Double(maxMonthTokens) * 100 : 0
                return UtilizationBar(
                    id: bucket.label,
                    label: bucket.label,
                    date: bucket.date,
                    usedPercent: pct,
                    isToday: bucket.isThisMonth)
            }
            return UtilizationModel(bars: bars, axisLabels: bars.map(\.label))
        }
    }

    private static func axisLabels(from bars: [UtilizationBar], desiredCount: Int) -> [String] {
        guard bars.count > desiredCount else { return bars.map(\.label) }
        let lastIndex = bars.count - 1
        return bars.enumerated().compactMap { index, bar in
            if index == 0 || index == lastIndex { return bar.label }
            let step = max(1, lastIndex / max(1, desiredCount - 1))
            return index % step == 0 ? bar.label : nil
        }
    }

    private func selectionBandRect(model: UtilizationModel, proxy: ChartProxy, geo: GeometryProxy) -> CGRect? {
        guard let selectedBarID = self.selectedBarID else { return nil }
        guard let plotAnchor = proxy.plotFrame else { return nil }
        let plotFrame = geo[plotAnchor]
        guard let index = model.bars.firstIndex(where: { $0.id == selectedBarID }) else { return nil }
        guard let x = proxy.position(forX: model.bars[index].label) else { return nil }

        let step = plotFrame.width / CGFloat(max(1, model.bars.count))
        let width = min(34, max(16, step * 0.72))
        return CGRect(
            x: plotFrame.origin.x + x - (width / 2),
            y: plotFrame.origin.y,
            width: width,
            height: plotFrame.height)
    }

    private func updateSelection(
        location: CGPoint?,
        model: UtilizationModel,
        proxy: ChartProxy,
        geo: GeometryProxy)
    {
        guard let location else {
            if self.selectedBarID != nil { self.selectedBarID = nil }
            return
        }
        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location) else { return }

        let xInPlot = location.x - plotFrame.origin.x
        var bestID: String?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for bar in model.bars {
            guard let x = proxy.position(forX: bar.label) else { continue }
            let distance = abs(x - xInPlot)
            if distance < bestDistance {
                bestDistance = distance
                bestID = bar.id
            }
        }
        if let bestID, self.selectedBarID != bestID {
            self.selectedBarID = bestID
        }
    }

    private func detailText(model: UtilizationModel) -> String {
        let bar = self.selectedBarID
            .flatMap { selected in model.bars.first(where: { $0.id == selected }) }
            ?? model.bars.last
        guard let bar else { return "Hover a bar for utilization" }
        let used = Int(bar.usedPercent.rounded())
        let unused = max(0, 100 - used)
        return "\(bar.label): \(used)% used, \(unused)% unused"
    }
}
