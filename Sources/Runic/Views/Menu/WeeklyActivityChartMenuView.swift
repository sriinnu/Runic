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
    @State private var selectedDayID: String?
    @Environment(\.runicTheme) private var runicTheme

    init(dailySummaries: [UsageLedgerDailySummary], width: CGFloat) {
        self.dailySummaries = dailySummaries
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(from: self.dailySummaries)
        let todayColor = self.runicTheme.chartColor(at: 0)
        let barColor = self.runicTheme.menuTrackColor.opacity(0.85)

        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 7 Days")
                    .font(RunicFont.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if model.bars.count > 1 {
                    let avg = model.totalTokens / max(1, model.bars.count(where: { $0.totalTokens > 0 }))
                    Text("\(UsageFormatter.tokenCountString(avg)) avg")
                        .font(RunicFont.caption)
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
            }

            if model.bars.allSatisfy({ $0.totalTokens == 0 }) {
                Text("No usage in the last 7 days.")
                    .font(RunicFont.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(height: 80)
            } else {
                let detail = self.detailText(model: model)
                Chart {
                    ForEach(model.bars) { bar in
                        BarMark(
                            x: .value("Day", bar.weekdayShort),
                            y: .value("Tokens", bar.totalTokens))
                            .foregroundStyle(bar.isToday ? todayColor : barColor)
                            .cornerRadius(RunicCornerRadius.sm)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(RunicFont.caption2)
                            .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                            .foregroundStyle(self.runicTheme.chartGridColor)
                        AxisValueLabel {
                            if let tokens = value.as(Int.self) {
                                Text(UsageFormatter.tokenCountString(tokens))
                                    .font(RunicFont.caption2)
                                    .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: RunicSpacing.chartHeight - 40)
                .help(detail)
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

                Text(detail)
                    .font(RunicFont.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: 16, alignment: .leading)
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

    private func selectionBandRect(model: WeeklyModel, proxy: ChartProxy, geo: GeometryProxy) -> CGRect? {
        guard let selectedDayID = self.selectedDayID else { return nil }
        guard let plotAnchor = proxy.plotFrame else { return nil }
        let plotFrame = geo[plotAnchor]
        guard let index = model.bars.firstIndex(where: { $0.id == selectedDayID }) else { return nil }
        guard let x = proxy.position(forX: model.bars[index].weekdayShort) else { return nil }

        let step = plotFrame.width / CGFloat(max(1, model.bars.count))
        let width = min(36, max(18, step * 0.72))
        return CGRect(
            x: plotFrame.origin.x + x - (width / 2),
            y: plotFrame.origin.y,
            width: width,
            height: plotFrame.height)
    }

    private func updateSelection(
        location: CGPoint?,
        model: WeeklyModel,
        proxy: ChartProxy,
        geo: GeometryProxy)
    {
        guard let location else {
            if self.selectedDayID != nil { self.selectedDayID = nil }
            return
        }
        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location) else { return }

        let xInPlot = location.x - plotFrame.origin.x
        var bestID: String?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for bar in model.bars {
            guard let x = proxy.position(forX: bar.weekdayShort) else { continue }
            let distance = abs(x - xInPlot)
            if distance < bestDistance {
                bestDistance = distance
                bestID = bar.id
            }
        }
        if let bestID, self.selectedDayID != bestID {
            self.selectedDayID = bestID
        }
    }

    private func detailText(model: WeeklyModel) -> String {
        guard let selectedDayID = self.selectedDayID,
              let bar = model.bars.first(where: { $0.id == selectedDayID })
        else {
            return "Hover a day for tokens"
        }
        return "\(bar.dayLabel): \(UsageFormatter.tokenCountString(bar.totalTokens)) tokens"
    }
}
