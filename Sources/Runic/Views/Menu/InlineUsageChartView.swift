import Charts
import RunicCore
import SwiftUI

/// Compact inline line chart displayed directly in the main menu card.
/// Shows recent usage with a time-range segmented picker — inspired by Tokex.
@MainActor
struct InlineUsageChartView: View {
    enum TimeRange: String, CaseIterable {
        case oneHour = "1h"
        case sixHours = "6h"
        case oneDay = "1d"
        case sevenDays = "7d"
        case thirtyDays = "30d"

        var cutoffInterval: TimeInterval {
            switch self {
            case .oneHour: return -3600
            case .sixHours: return -21600
            case .oneDay: return -86400
            case .sevenDays: return -604800
            case .thirtyDays: return -2592000
            }
        }

        var usesHourlyData: Bool {
            switch self {
            case .oneHour, .sixHours, .oneDay: return true
            default: return false
            }
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
    @State private var selectedRange: TimeRange = .oneDay
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private static let lineColor = RunicColors.chartColor(at: 0)

    var body: some View {
        let points = self.selectedRange.usesHourlyData
            ? Self.hourlyPoints(from: self.hourlySummaries, range: self.selectedRange)
            : Self.dailyPoints(from: self.dailySummaries, range: self.selectedRange)

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
                        .font(.system(.caption2, design: .rounded))
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
                                        .font(.system(size: 8, design: .rounded))
                                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel(format: self.xAxisFormat)
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 70)

                    // Peak badge
                    if let peak = points.max(by: { $0.tokens < $1.tokens }), peak.tokens > 0 {
                        Text("Peak \(UsageFormatter.tokenCountString(peak.tokens))")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
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
