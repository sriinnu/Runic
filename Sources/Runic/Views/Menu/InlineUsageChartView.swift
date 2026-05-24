import Charts
import RunicCore
import SwiftUI

/// Compact inline line chart displayed directly in the main menu card.
/// Shows recent usage with a time-range segmented picker — inspired by Tokex.
@MainActor
struct InlineUsageChartView: View {
    @Environment(\.runicFonts) private var fonts
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
    }

    private struct ChartPoint: Identifiable {
        let id: String
        let date: Date
        let tokens: Int
    }

    let dailySummaries: [UsageLedgerDailySummary]
    let hourlySummaries: [UsageLedgerHourlySummary]
    let chartStyle: ChartStyle
    let width: CGFloat
    @State private var selectedRange: TimeRange = .sevenDays
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let points = Self.dailyPoints(from: self.dailySummaries, range: self.selectedRange)
        let lineColor = self.runicTheme.chartColor(at: 0)

        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            // Time range picker
            Picker("", selection: self.$selectedRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)

            // Chart area
            if points.isEmpty {
                HStack {
                    Spacer()
                    Text("No data")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                    Spacer()
                }
                .frame(height: 70)
            } else {
                // Capture `now` once so a clock jump between calls can't put
                // domain.upperBound below lowerBound. Theme-branch the chart
                // marks the same way UsageTimelineChartMenuView does.
                let now = Date()
                let isTerminal = self.runicTheme.isTerminalHUD
                let isGlow = self.runicTheme.shape.separator == .glow
                let chartStyle = self.chartStyle
                let areaTopAlpha: Double = isTerminal ? 0 : (isGlow ? 0.32 : (self.runicTheme.id == "daybreak" ? 0.30 : 0.20))
                let areaBottomAlpha: Double = isTerminal ? 0 : 0.02
                let lineWidth: CGFloat = isGlow ? 2.0 : (isTerminal ? 1.2 : 1.5)
                ZStack(alignment: .topTrailing) {
                    Chart {
                        ForEach(points) { point in
                            if chartStyle == .bar {
                                BarMark(
                                    x: .value("Time", point.date),
                                    y: .value("Tokens", point.tokens))
                                    .foregroundStyle(lineColor.opacity(isTerminal ? 0.86 : 0.70))
                                    .cornerRadius(self.runicTheme.shape.cornerRadius(3))
                            } else if chartStyle == .area, !isTerminal {
                                AreaMark(
                                    x: .value("Time", point.date),
                                    y: .value("Tokens", point.tokens))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                lineColor.opacity(areaTopAlpha),
                                                lineColor.opacity(areaBottomAlpha),
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom))
                                    .interpolationMethod(.catmullRom)
                            }
                            if chartStyle != .bar {
                                LineMark(
                                    x: .value("Time", point.date),
                                    y: .value("Tokens", point.tokens))
                                    .foregroundStyle(lineColor)
                                    .lineStyle(StrokeStyle(lineWidth: lineWidth))
                                    .interpolationMethod(isTerminal ? .linear : .catmullRom)
                            }
                        }
                    }
                    .id(chartStyle.id)
                    .chartXScale(domain: now.addingTimeInterval(self.selectedRange.cutoffInterval)...now)
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3, 3]))
                                .foregroundStyle(self.runicTheme.chartGridColor)
                            AxisValueLabel {
                                if let tokens = value.as(Int.self) {
                                    Text(UsageFormatter.tokenCountString(tokens))
                                        .font(self.fonts.system(size: 8))
                                        .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel(format: self.xAxisFormat)
                                .font(self.fonts.system(size: 8))
                                .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 70)

                    // Peak badge
                    if let peak = points.max(by: { $0.tokens < $1.tokens }), peak.tokens > 0 {
                        Text("Peak \(UsageFormatter.tokenCountString(peak.tokens))")
                            .font(self.fonts.system(size: 8, weight: .medium))
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(self.runicTheme.menuSubtleFill))
                            .padding(4)
                    }
                }
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Usage \(self.chartStyle.label.lowercased()) chart, \(self.selectedRange.rawValue) range, \(points.count) data points")
    }

    private var xAxisFormat: Date.FormatStyle {
        if self.selectedRange.usesHourlyData {
            return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        }
        return .dateTime.month(.abbreviated).day()
    }

    // MARK: - Data

    private static func hourlyPoints(from summaries: [UsageLedgerHourlySummary], range: TimeRange) -> [ChartPoint] {
        let cutoff = Date().addingTimeInterval(range.cutoffInterval)
        let filtered = summaries.filter { $0.hourStart >= cutoff }.sorted { $0.hourStart < $1.hourStart }
        return filtered.map { ChartPoint(id: $0.hourKey, date: $0.hourStart, tokens: $0.totals.totalTokens) }
    }

    private static func dailyPoints(from summaries: [UsageLedgerDailySummary], range: TimeRange) -> [ChartPoint] {
        let cutoff = Date().addingTimeInterval(range.cutoffInterval)
        let filtered = summaries.filter { $0.dayStart >= cutoff }.sorted { $0.dayStart < $1.dayStart }
        return filtered.map { ChartPoint(id: $0.dayKey, date: $0.dayStart, tokens: $0.totals.totalTokens) }
    }
}
