import Charts
import RunicCore
import SwiftUI

@MainActor
struct UsageTimelineChartMenuView: View {
    enum TimeRange: String, CaseIterable {
        case sevenDays = "7d"
        case fourteenDays = "14d"
        case thirtyDays = "30d"

        var days: Int {
            switch self {
            case .sevenDays: return 7
            case .fourteenDays: return 14
            case .thirtyDays: return 30
            }
        }

        var label: String { self.rawValue }
    }

    private struct Point: Identifiable {
        let id: String
        let date: Date
        let totalTokens: Int

        init(date: Date, totalTokens: Int) {
            self.date = date
            self.totalTokens = totalTokens
            self.id = "\(Int(date.timeIntervalSince1970))-\(totalTokens)"
        }
    }

    private let dailySummaries: [UsageLedgerDailySummary]
    private let width: CGFloat
    @State private var selectedTimeRange: TimeRange = .fourteenDays
    @State private var selectedDateKey: String?
    @State private var scrollOffset: CGFloat = 0

    init(dailySummaries: [UsageLedgerDailySummary], width: CGFloat) {
        self.dailySummaries = dailySummaries
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(from: self.dailySummaries, timeRange: self.selectedTimeRange)
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            HStack {
                Text("Token Usage Timeline")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Picker("Range", selection: self.$selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if model.points.isEmpty {
                Text("No timeline data for selected range.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(model.points) { point in
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Tokens", point.totalTokens))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.26, green: 0.55, blue: 0.96).opacity(0.3),
                                        Color(red: 0.26, green: 0.55, blue: 0.96).opacity(0.05),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom))
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Tokens", point.totalTokens))
                            .foregroundStyle(Color(red: 0.26, green: 0.55, blue: 0.96))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    if let peak = model.peakPoint {
                        PointMark(
                            x: .value("Date", peak.date, unit: .day),
                            y: .value("Tokens", peak.totalTokens))
                            .foregroundStyle(Color(nsColor: .systemYellow))
                            .symbolSize(80)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let tokens = value.as(Int.self) {
                                Text(UsageFormatter.tokenCountString(tokens))
                                    .font(.caption2)
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: model.axisDates) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 180)
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

                let detail = self.detailLines(model: model)
                VStack(alignment: .leading, spacing: 0) {
                    Text(detail.primary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 16, alignment: .leading)
                    Text(detail.secondary ?? " ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 16, alignment: .leading)
                        .opacity(detail.secondary == nil ? 0 : 1)
                }

                // Stats
                HStack(spacing: RunicSpacing.md) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        Text("Total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(UsageFormatter.tokenCountString(model.totalTokens))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        Text("Avg/day")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(UsageFormatter.tokenCountString(model.averagePerDay))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        Text("Peak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(UsageFormatter.tokenCountString(model.peakTokens))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private struct Model {
        let points: [Point]
        let summariesByDateKey: [String: UsageLedgerDailySummary]
        let dateKeys: [(key: String, date: Date)]
        let axisDates: [Date]
        let peakPoint: Point?
        let totalTokens: Int
        let averagePerDay: Int
        let peakTokens: Int
    }

    private static let selectionBandColor = Color(nsColor: .labelColor).opacity(0.1)

    private static func makeModel(from summaries: [UsageLedgerDailySummary], timeRange: TimeRange) -> Model {
        let now = Date()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: now) ?? now
        let filtered = summaries.filter { $0.dayStart >= cutoffDate }
        let sorted = filtered.sorted { $0.dayStart < $1.dayStart }

        var points: [Point] = []
        var summariesByKey: [String: UsageLedgerDailySummary] = [:]
        var dateKeys: [(key: String, date: Date)] = []
        var peak: Point?
        var totalTokens = 0

        for summary in sorted {
            let tokens = summary.totals.totalTokens
            totalTokens += tokens
            let point = Point(date: summary.dayStart, totalTokens: tokens)
            points.append(point)
            summariesByKey[summary.dayKey] = summary
            dateKeys.append((summary.dayKey, summary.dayStart))

            if let currentPeak = peak {
                if tokens > currentPeak.totalTokens {
                    peak = point
                }
            } else {
                peak = point
            }
        }

        let axisDates: [Date] = {
            guard let first = dateKeys.first?.date, let last = dateKeys.last?.date else { return [] }
            if Calendar.current.isDate(first, inSameDayAs: last) { return [first] }
            return [first, last]
        }()

        let averagePerDay = points.isEmpty ? 0 : totalTokens / max(1, points.count)
        let peakTokens = peak?.totalTokens ?? 0

        return Model(
            points: points,
            summariesByDateKey: summariesByKey,
            dateKeys: dateKeys,
            axisDates: axisDates,
            peakPoint: peak,
            totalTokens: totalTokens,
            averagePerDay: averagePerDay,
            peakTokens: peakTokens)
    }

    private func selectionBandRect(model: Model, proxy: ChartProxy, geo: GeometryProxy) -> CGRect? {
        guard let key = self.selectedDateKey else { return nil }
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
            if self.selectedDateKey != nil { self.selectedDateKey = nil }
            return
        }

        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location) else { return }

        let xInPlot = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: xInPlot) else { return }
        guard let nearest = self.nearestDateKey(to: date, model: model) else { return }

        if self.selectedDateKey != nearest {
            self.selectedDateKey = nearest
        }
    }

    private func nearestDateKey(to date: Date, model: Model) -> String? {
        guard !model.dateKeys.isEmpty else { return nil }
        var best: (key: String, distance: TimeInterval)?
        for entry in model.dateKeys {
            let dist = abs(entry.date.timeIntervalSince(date))
            if let cur = best {
                if dist < cur.distance { best = (entry.key, dist) }
            } else {
                best = (entry.key, dist)
            }
        }
        return best?.key
    }

    private func detailLines(model: Model) -> (primary: String, secondary: String?) {
        guard let key = self.selectedDateKey,
              let summary = model.summariesByDateKey[key]
        else {
            return ("Hover the chart for details", nil)
        }

        let dayLabel = summary.dayStart.formatted(.dateTime.month(.abbreviated).day())
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        let primary = "\(dayLabel): \(tokens) tokens"

        var details: [String] = []
        if let cost = summary.totals.costUSD {
            details.append(UsageFormatter.usdString(cost))
        }
        let cacheTotal = summary.totals.cacheCreationTokens + summary.totals.cacheReadTokens
        if cacheTotal > 0 {
            details.append("Cache: \(UsageFormatter.tokenCountString(cacheTotal))")
        }
        if !summary.modelsUsed.isEmpty {
            if let models = Self.modelsDetailText(from: summary.modelsUsed) {
                details.append("Models: \(models)")
            }
        }

        let secondary = details.isEmpty ? nil : details.joined(separator: " · ")
        return (primary, secondary)
    }

    private static func modelsDetailText(from modelsUsed: [String]) -> String? {
        var seen: Set<String> = []
        let deduplicated = modelsUsed.filter { model in
            let inserted = seen.insert(model).inserted
            return inserted
        }

        guard !deduplicated.isEmpty else { return nil }

        let maxShown = 3
        let shown = deduplicated.prefix(maxShown)
        let rendered = shown.map { model in
            if let context = UsageFormatter.modelContextLabel(for: model) {
                return "\(UsageFormatter.modelDisplayName(model)) \(context)"
            }
            return UsageFormatter.modelDisplayName(model)
        }

        var detail = rendered.joined(separator: " · ")
        let extra = deduplicated.count - shown.count
        if extra > 0 {
            detail += " · +\(extra) more"
        }
        return detail
    }
}
