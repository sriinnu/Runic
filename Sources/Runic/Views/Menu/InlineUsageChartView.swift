import Charts
import RunicCore
import SwiftUI

/// Compact inline line chart displayed directly in the main menu card.
/// Shows recent usage with a time-range segmented picker — inspired by Tokex.
@MainActor
struct InlineUsageChartView: View {
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
    let width: CGFloat
    @State private var selectedRange: TimeRange = .sevenDays
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private static let lineColor = RunicColors.chartColor(at: 0)

    var body: some View {
        let points = Self.dailyPoints(from: self.dailySummaries, range: self.selectedRange)

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
                        .font(RunicFont.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 70)
            } else {
                ZStack(alignment: .topTrailing) {
                    Chart {
                        ForEach(points) { point in
                            AreaMark(
                                x: .value("Time", point.date),
                                y: .value("Tokens", point.tokens))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Self.lineColor.opacity(0.2),
                                            Self.lineColor.opacity(0.02),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Tokens", point.tokens))
                                .foregroundStyle(Self.lineColor)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3, 3]))
                                .foregroundStyle(Color(nsColor: .separatorColor).opacity(0.3))
                            AxisValueLabel {
                                if let tokens = value.as(Int.self) {
                                    Text(UsageFormatter.tokenCountString(tokens))
                                        .font(RunicFont.system(size: 8))
                                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel(format: self.xAxisFormat)
                                .font(RunicFont.system(size: 8))
                                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 70)

                    // Peak badge
                    if let peak = points.max(by: { $0.tokens < $1.tokens }), peak.tokens > 0 {
                        Text("Peak \(UsageFormatter.tokenCountString(peak.tokens))")
                            .font(RunicFont.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(.ultraThinMaterial))
                            .padding(4)
                    }
                }
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage chart, \(self.selectedRange.rawValue) range, \(points.count) data points")
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
