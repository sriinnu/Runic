import Charts
import RunicCore
import SwiftUI

/// Multi-line chart overlaying session and weekly usage % — inspired by Tokex dual-line chart.
/// Y-axis 0-100%, two colored lines for different rate windows.
@MainActor
struct UsageWindowComparisonChartMenuView: View {
    @Environment(\.runicFonts) private var fonts
    private struct PercentPoint: Identifiable {
        let id: String
        let dayKey: String
        let date: Date
        let percent: Double
        let series: String
        let tokens: Int
    }

    private let dailySummaries: [UsageLedgerDailySummary]
    private let primaryLabel: String
    private let secondaryLabel: String?
    private let primaryPercent: Double
    private let secondaryPercent: Double?
    private let width: CGFloat
    @State private var selectedDayKey: String?
    @Environment(\.runicTheme) private var runicTheme

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

    var body: some View {
        let model = Self.makeModel(
            from: self.dailySummaries,
            primaryLabel: self.primaryLabel,
            secondaryLabel: self.secondaryLabel,
            primaryPercent: self.primaryPercent,
            secondaryPercent: self.secondaryPercent)
        let primaryColor = self.runicTheme.chartColor(at: 0)
        let secondaryColor = self.runicTheme.chartColor(at: 1)

        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Windows")
                .font(self.fonts.subheadline)
                .fontWeight(.semibold)

            if model.points.isEmpty {
                Text("No usage window data available.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(height: 80)
            } else {
                let detail = self.detailText(model: model)
                let isTerminal = self.runicTheme.isTerminalHUD
                let isGlow = self.runicTheme.shape.separator == .glow
                let lineWidth: CGFloat = isGlow ? 2.4 : (isTerminal ? 1.4 : 2)
                Chart {
                    ForEach(model.points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("%", point.percent),
                            series: .value("Window", point.series))
                            .foregroundStyle(point.series == self.primaryLabel ? primaryColor : secondaryColor)
                            .lineStyle(StrokeStyle(lineWidth: lineWidth))
                            .interpolationMethod(isTerminal ? .linear : .catmullRom)
                    }
                    if let selected = self.selectedPoint(model: model) {
                        RuleMark(x: .value("Date", selected.date))
                            .foregroundStyle(self.runicTheme.primaryText.opacity(0.26))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
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
                                    .font(self.fonts.caption2)
                                    .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                            .foregroundStyle(self.runicTheme.chartGridColor.opacity(0.7))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                    }
                }
                .chartLegend(.hidden)
                .frame(height: RunicSpacing.chartHeight + 20)
                .help(detail)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            MouseLocationReader { location in
                                self.updateSelection(location: location, model: model, proxy: proxy, geo: geo)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                    }
                }

                // Legend
                HStack(spacing: RunicSpacing.md) {
                    HStack(spacing: RunicSpacing.xxs) {
                        Circle()
                            .fill(primaryColor)
                            .frame(width: RunicSpacing.chartLegendDot, height: RunicSpacing.chartLegendDot)
                        Text(self.primaryLabel)
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }
                    if let secondaryLabel = self.secondaryLabel {
                        HStack(spacing: RunicSpacing.xxs) {
                            Circle()
                                .fill(secondaryColor)
                                .frame(width: RunicSpacing.chartLegendDot, height: RunicSpacing.chartLegendDot)
                            Text(secondaryLabel)
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }
                    }
                }

                Text(detail)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: 16, alignment: .leading)
            }
        }
        .chartPanelStyle(width: self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage window comparison chart")
    }

    // MARK: - Model

    private struct ComparisonModel {
        let points: [PercentPoint]
        let pointsByDayKey: [String: [PercentPoint]]
        let dateKeys: [(key: String, date: Date)]
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
                dayKey: key,
                date: date,
                percent: primaryPct,
                series: primaryLabel,
                tokens: tokens))

            if secondaryLabel != nil {
                let secondaryPct = min(100, Double(tokens) * secondaryScale)
                points.append(PercentPoint(
                    id: "\(key)-secondary",
                    dayKey: key,
                    date: date,
                    percent: secondaryPct,
                    series: secondaryLabel ?? "",
                    tokens: tokens))
            }
        }

        let grouped = Dictionary(grouping: points, by: \.dayKey)
        let dateKeys = grouped.compactMap { key, values -> (key: String, date: Date)? in
            guard let date = values.first?.date else { return nil }
            return (key, date)
        }
        .sorted { $0.date < $1.date }

        return ComparisonModel(points: points, pointsByDayKey: grouped, dateKeys: dateKeys)
    }

    private func updateSelection(
        location: CGPoint?,
        model: ComparisonModel,
        proxy: ChartProxy,
        geo: GeometryProxy)
    {
        guard let location else {
            if self.selectedDayKey != nil { self.selectedDayKey = nil }
            return
        }
        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location) else {
            if self.selectedDayKey != nil { self.selectedDayKey = nil }
            return
        }
        let xInPlot = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: xInPlot) else { return }

        var bestKey: String?
        var bestDistance: TimeInterval = .greatestFiniteMagnitude
        for entry in model.dateKeys {
            let distance = abs(entry.date.timeIntervalSince(date))
            if distance < bestDistance {
                bestDistance = distance
                bestKey = entry.key
            }
        }
        if let bestKey, self.selectedDayKey != bestKey {
            self.selectedDayKey = bestKey
        }
    }

    private func selectedPoint(model: ComparisonModel) -> PercentPoint? {
        guard let selectedDayKey,
              let points = model.pointsByDayKey[selectedDayKey]
        else {
            return nil
        }
        return points.first
    }

    private func detailText(model: ComparisonModel) -> String {
        guard let selected = self.selectedPoint(model: model) else {
            return "Hover a window day for utilization"
        }
        let points = model.pointsByDayKey[selected.dayKey] ?? [selected]
        let dayLabel = selected.date.formatted(.dateTime.month(.abbreviated).day())
        var parts = ["\(dayLabel): \(UsageFormatter.tokenCountString(selected.tokens)) tokens"]
        for point in points {
            parts.append("\(point.series) \(Int(point.percent.rounded()))%")
        }
        return parts.joined(separator: " · ")
    }
}
