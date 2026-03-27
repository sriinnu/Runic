import Charts
import RunicCore
import SwiftUI

@MainActor
struct UsageTimelineChartMenuView: View {
    enum TimeRange: String, CaseIterable {
        case threeDays = "3d"
        case sevenDays = "7d"
        case thirtyDays = "30d"
        case quarter = "90d"
        case year = "1y"

        var cutoffInterval: TimeInterval {
            switch self {
            case .threeDays: -259_200
            case .sevenDays: -604_800
            case .thirtyDays: -2_592_000
            case .quarter: -7_776_000
            case .year: -31_536_000
            }
        }

        var usesHourlyData: Bool {
            false
        }

        var label: String {
            self.rawValue
        }
    }

    private struct Point: Identifiable {
        let id: String
        let date: Date
        let totalTokens: Int
        let key: String

        init(date: Date, totalTokens: Int, key: String) {
            self.date = date
            self.totalTokens = totalTokens
            self.key = key
            self.id = key
        }
    }

    private let dailySummaries: [UsageLedgerDailySummary]
    private let hourlySummaries: [UsageLedgerHourlySummary]
    private let width: CGFloat
    @State private var selectedTimeRange: TimeRange = .sevenDays
    @State private var selectedKey: String?

    init(
        dailySummaries: [UsageLedgerDailySummary],
        hourlySummaries: [UsageLedgerHourlySummary] = [],
        width: CGFloat)
    {
        self.dailySummaries = dailySummaries
        self.hourlySummaries = hourlySummaries
        self.width = width
    }

    private static let lineColor = RunicColors.chartColor(at: 0)
    private static let selectionBandColor = Color(nsColor: .labelColor).opacity(0.1)

    var body: some View {
        let model = Self.makeDailyModel(from: self.dailySummaries, timeRange: self.selectedTimeRange)

        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            // Header on its own line
            Text("Timeline")
                .font(RunicFont.subheadline)
                .fontWeight(.semibold)

            // Range picker on its own line
            Picker("", selection: self.$selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if model.points.isEmpty {
                Text("No data for selected range.")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            } else {
                // Line chart
                Chart {
                    ForEach(model.points) { point in
                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("Tokens", point.totalTokens))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Self.lineColor.opacity(0.25),
                                        Self.lineColor.opacity(0.03),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Tokens", point.totalTokens))
                            .foregroundStyle(Self.lineColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                    }
                    if let peak = model.peakPoint {
                        PointMark(
                            x: .value("Time", peak.date),
                            y: .value("Tokens", peak.totalTokens))
                            .foregroundStyle(Color(nsColor: .systemYellow))
                            .symbolSize(60)
                            .annotation(position: .top, spacing: 4) {
                                Text("Peak")
                                    .font(RunicFont.caption2)
                                    .foregroundStyle(Color(nsColor: .systemYellow))
                            }
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
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: model.desiredAxisCount)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                            .foregroundStyle(Color(nsColor: .separatorColor).opacity(0.3))
                        AxisValueLabel(format: model.xAxisFormat)
                            .font(RunicFont.caption2)
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .chartLegend(.hidden)
                .frame(height: RunicSpacing.chartHeight + 30)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if let rect = self.selectionBandRect(model: model, proxy: proxy, geo: geo) {
                                Rectangle()
                                    .fill(Self.selectionBandColor)
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

                // Detail line
                let detail = self.detailText(model: model)
                Text(detail)
                    .font(RunicFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: 16, alignment: .leading)

                // Stats row
                HStack(spacing: RunicSpacing.md) {
                    StatCell(label: "Total", value: UsageFormatter.tokenCountString(model.totalTokens))
                    StatCell(
                        label: self.selectedTimeRange.usesHourlyData ? "Avg/hr" : "Avg/day",
                        value: UsageFormatter.tokenCountString(model.averagePerPeriod))
                    StatCell(label: "Peak", value: UsageFormatter.tokenCountString(model.peakTokens))
                    if let cost = model.totalCostUSD, cost > 0 {
                        StatCell(label: "Cost", value: UsageFormatter.usdString(cost))
                    }
                }
            }
        }
        .chartPanelStyle(width: self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Usage timeline chart showing \(model.points.count) data points over \(self.selectedTimeRange.label)")
    }

    // MARK: - Stat cell

    private struct StatCell: View {
        let label: String
        let value: String

        var body: some View {
            VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                Text(self.label)
                    .font(RunicFont.caption2)
                    .foregroundStyle(.tertiary)
                Text(self.value)
                    .font(RunicFont.caption)
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Model

    private struct Model {
        let points: [Point]
        let pointsByKey: [String: Point]
        let dateKeys: [(key: String, date: Date)]
        let peakPoint: Point?
        let totalTokens: Int
        let averagePerPeriod: Int
        let peakTokens: Int
        let totalCostUSD: Double?
        let desiredAxisCount: Int
        let xAxisFormat: Date.FormatStyle
        let isHourly: Bool
    }

    // MARK: - Daily model

    private static func makeDailyModel(from summaries: [UsageLedgerDailySummary], timeRange: TimeRange) -> Model {
        let now = Date()
        let cutoffDate = now.addingTimeInterval(timeRange.cutoffInterval)
        let filtered = summaries.filter { $0.dayStart >= cutoffDate }
        let sorted = filtered.sorted { $0.dayStart < $1.dayStart }

        var points: [Point] = []
        var pointsByKey: [String: Point] = [:]
        var dateKeys: [(key: String, date: Date)] = []
        var peak: Point?
        var totalTokens = 0
        var totalCost: Double = 0
        var hasCost = false

        for summary in sorted {
            let tokens = summary.totals.totalTokens
            totalTokens += tokens
            if let cost = summary.totals.costUSD {
                totalCost += cost
                hasCost = true
            }
            let point = Point(date: summary.dayStart, totalTokens: tokens, key: summary.dayKey)
            points.append(point)
            pointsByKey[summary.dayKey] = point
            dateKeys.append((summary.dayKey, summary.dayStart))

            if peak == nil || tokens > (peak?.totalTokens ?? 0) {
                peak = point
            }
        }

        let desiredAxisCount = switch timeRange {
        case .threeDays: 3
        case .sevenDays: 5
        case .thirtyDays: 6
        case .quarter: 6
        case .year: 6
        }

        return Model(
            points: points,
            pointsByKey: pointsByKey,
            dateKeys: dateKeys,
            peakPoint: peak,
            totalTokens: totalTokens,
            averagePerPeriod: points.isEmpty ? 0 : totalTokens / max(1, points.count),
            peakTokens: peak?.totalTokens ?? 0,
            totalCostUSD: hasCost ? totalCost : nil,
            desiredAxisCount: desiredAxisCount,
            xAxisFormat: .dateTime.month(.abbreviated).day(),
            isHourly: false)
    }

    // MARK: - Interaction

    private func selectionBandRect(model: Model, proxy: ChartProxy, geo: GeometryProxy) -> CGRect? {
        guard let key = self.selectedKey else { return nil }
        guard let plotAnchor = proxy.plotFrame else { return nil }
        let plotFrame = geo[plotAnchor]
        guard let index = model.dateKeys.firstIndex(where: { $0.key == key }) else { return nil }
        let date = model.dateKeys[index].date
        guard let x = proxy.position(forX: date) else { return nil }

        func xForIndex(_ idx: Int) -> CGFloat? {
            guard idx >= 0, idx < model.dateKeys.count else { return nil }
            return proxy.position(forX: model.dateKeys[idx].date)
        }

        let xPrev = xForIndex(index - 1)
        let xNext = xForIndex(index + 1)

        let leftInPlot: CGFloat = if let xPrev {
            (xPrev + x) / 2
        } else if let xNext {
            x - (xNext - x) / 2
        } else {
            x - 8
        }

        let rightInPlot: CGFloat = if let xNext {
            (xNext + x) / 2
        } else if let xPrev {
            x + (x - xPrev) / 2
        } else {
            x + 8
        }

        let left = plotFrame.origin.x + min(leftInPlot, rightInPlot)
        let right = plotFrame.origin.x + max(leftInPlot, rightInPlot)
        return CGRect(x: left, y: plotFrame.origin.y, width: right - left, height: plotFrame.height)
    }

    private func updateSelection(
        location: CGPoint?,
        model: Model,
        proxy: ChartProxy,
        geo: GeometryProxy)
    {
        guard let location else {
            if self.selectedKey != nil { self.selectedKey = nil }
            return
        }

        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location) else { return }

        let xInPlot = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: xInPlot) else { return }

        var bestKey: String?
        var bestDistance: TimeInterval = .greatestFiniteMagnitude
        for entry in model.dateKeys {
            let dist = abs(entry.date.timeIntervalSince(date))
            if dist < bestDistance {
                bestDistance = dist
                bestKey = entry.key
            }
        }

        if let bestKey, self.selectedKey != bestKey {
            self.selectedKey = bestKey
        }
    }

    private func detailText(model: Model) -> String {
        guard let key = self.selectedKey, let point = model.pointsByKey[key] else {
            return "Hover for details"
        }
        let tokens = UsageFormatter.tokenCountString(point.totalTokens)
        if model.isHourly {
            let timeLabel = point.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
            return "\(timeLabel): \(tokens) tokens"
        } else {
            let dayLabel = point.date.formatted(.dateTime.month(.abbreviated).day())
            return "\(dayLabel): \(tokens) tokens"
        }
    }
}
