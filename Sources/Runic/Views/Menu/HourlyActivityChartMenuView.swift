import Charts
import RunicCore
import SwiftUI

/// Bar chart showing today's hourly usage — inspired by Tokex "Today by Hour".
@MainActor
struct HourlyActivityChartMenuView: View {
    private struct HourBar: Identifiable {
        let id: Int // hour 0-23
        let hour: Int
        let totalTokens: Int
        let isPeak: Bool

        var label: String {
            if self.hour == 0 { return "12A" }
            if self.hour < 12 { return "\(self.hour)A" }
            if self.hour == 12 { return "12P" }
            return "\(self.hour - 12)P"
        }
    }

    private let hourlySummaries: [UsageLedgerHourlySummary]
    private let width: CGFloat
    @State private var selectedHour: Int?

    init(hourlySummaries: [UsageLedgerHourlySummary], width: CGFloat) {
        self.hourlySummaries = hourlySummaries
        self.width = width
    }

    private static let barColor = Color(red: 0.34, green: 0.56, blue: 1.0)
    private static let peakColor = Color(nsColor: .systemYellow)

    var body: some View {
        let model = Self.makeModel(from: self.hourlySummaries)

        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Today by Hour")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                if let peak = model.peakHour {
                    Text("Peak \(peak.label)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if model.bars.allSatisfy({ $0.totalTokens == 0 }) {
                Text("No usage recorded today.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(model.bars) { bar in
                        BarMark(
                            x: .value("Hour", bar.hour),
                            y: .value("Tokens", bar.totalTokens))
                            .foregroundStyle(bar.isPeak ? Self.peakColor : Self.barColor)
                            .cornerRadius(RunicCornerRadius.xs)
                    }
                    if let selected = self.selectedHour,
                       let bar = model.bars.first(where: { $0.hour == selected })
                    {
                        RuleMark(x: .value("Hour", selected))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            .foregroundStyle(Color(nsColor: .labelColor).opacity(0.3))
                            .annotation(position: .top, spacing: 4) {
                                Text(UsageFormatter.tokenCountString(bar.totalTokens))
                                    .font(.system(.caption2, design: .rounded))
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: RunicCornerRadius.xs)
                                            .fill(.ultraThinMaterial))
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(Self.hourAxisLabel(hour))
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
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
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: RunicSpacing.chartHeight - 30)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        MouseLocationReader { location in
                            self.updateHourSelection(location: location, proxy: proxy, geo: geo)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                }

                // Summary stats
                HStack(spacing: RunicSpacing.md) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        Text("Today")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Text(UsageFormatter.tokenCountString(model.totalTokens))
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.medium)
                    }
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        Text("Active hours")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Text("\(model.activeHours)")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.medium)
                    }
                    if model.totalRequests > 0 {
                        VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                            Text("Requests")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.tertiary)
                            Text("\(model.totalRequests)")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .chartPanelStyle(width: self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today by hour chart with \(model.activeHours) active hours")
    }

    // MARK: - Model

    private struct HourlyModel {
        let bars: [HourBar]
        let peakHour: HourBar?
        let totalTokens: Int
        let activeHours: Int
        let totalRequests: Int
    }

    private static func makeModel(from summaries: [UsageLedgerHourlySummary]) -> HourlyModel {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        // Bucket by hour
        var tokensByHour: [Int: Int] = [:]
        var requestsByHour: [Int: Int] = [:]
        for summary in summaries where summary.hourStart >= todayStart {
            let hour = calendar.component(.hour, from: summary.hourStart)
            tokensByHour[hour, default: 0] += summary.totals.totalTokens
            requestsByHour[hour, default: 0] += summary.requestCount
        }

        let maxTokens = tokensByHour.values.max() ?? 0
        var peakHour: HourBar?

        let bars = (0..<24).map { hour in
            let tokens = tokensByHour[hour] ?? 0
            let isPeak = tokens > 0 && tokens == maxTokens
            let bar = HourBar(id: hour, hour: hour, totalTokens: tokens, isPeak: isPeak)
            if isPeak && tokens > 0 { peakHour = bar }
            return bar
        }

        let totalTokens = tokensByHour.values.reduce(0, +)
        let activeHours = tokensByHour.values.filter { $0 > 0 }.count
        let totalRequests = requestsByHour.values.reduce(0, +)

        return HourlyModel(
            bars: bars,
            peakHour: peakHour,
            totalTokens: totalTokens,
            activeHours: activeHours,
            totalRequests: totalRequests)
    }

    private func updateHourSelection(
        location: CGPoint?,
        proxy: ChartProxy,
        geo: GeometryProxy)
    {
        guard let location else {
            if self.selectedHour != nil { self.selectedHour = nil }
            return
        }
        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location) else {
            if self.selectedHour != nil { self.selectedHour = nil }
            return
        }
        let xInPlot = location.x - plotFrame.origin.x
        guard let hour: Int = proxy.value(atX: xInPlot) else { return }
        let clamped = max(0, min(23, hour))
        if self.selectedHour != clamped { self.selectedHour = clamped }
    }

    private static func hourAxisLabel(_ hour: Int) -> String {
        if hour == 0 { return "12AM" }
        if hour < 12 { return "\(hour)AM" }
        if hour == 12 { return "12PM" }
        return "\(hour - 12)PM"
    }
}
