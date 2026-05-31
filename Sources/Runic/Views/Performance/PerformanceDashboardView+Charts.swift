import Charts
import RunicCore
import SwiftUI

extension PerformanceDashboardView {
    var latencyChartSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Latency Over Time")
                .font(self.fonts.headline)
                .fontWeight(.semibold)

            if self.stats.isEmpty {
                Text("No latency data available")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(self.stats, id: \.id) { stat in
                        if let date = self.dateFromKey(stat.date) {
                            LineMark(
                                x: .value("Date", date),
                                y: .value("Latency (ms)", stat.avgLatencyMs))
                                .foregroundStyle(self.providerColor)
                                .interpolationMethod(.catmullRom)

                            if stat.p95LatencyMs > 0 {
                                AreaMark(
                                    x: .value("Date", date),
                                    yStart: .value("Min", stat.avgLatencyMs),
                                    yEnd: .value("P95", stat.p95LatencyMs))
                                    .foregroundStyle(self.providerColor.opacity(0.2))
                            }
                        }
                    }
                }
                .chartYAxisLabel("Latency (ms)")
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(self.fonts.caption2)
                        AxisGridLine()
                    }
                }
                .frame(height: 150)
                .padding(.top, RunicSpacing.xxs)
            }

            if self.hasPercentileData {
                HStack(spacing: RunicSpacing.sm) {
                    Text("Line: Avg")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Text("•")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Text("Area: P95")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
            }
        }
    }

    var errorRateChartSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Error Rate Over Time")
                .font(self.fonts.headline)
                .fontWeight(.semibold)

            if self.stats.isEmpty {
                Text("No error data available")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(self.stats, id: \.id) { stat in
                        if let date = self.dateFromKey(stat.date) {
                            BarMark(
                                x: .value("Date", date),
                                y: .value("Error Rate", stat.errorRate * 100))
                                .foregroundStyle(self.errorRateColor(stat.errorRate))

                            if stat.errorCount > 0 {
                                RuleMark(y: .value("Threshold", 5.0))
                                    .foregroundStyle(.red.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            }
                        }
                    }
                }
                .chartYAxisLabel("Error Rate (%)")
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(self.fonts.caption2)
                        AxisGridLine()
                    }
                }
                .frame(height: 150)
                .padding(.top, RunicSpacing.xxs)
            }

            self.errorBreakdown
        }
    }

    var errorBreakdown: some View {
        let aggregated = self.aggregateStats()
        let hasErrors = aggregated.errorCount > 0

        return VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            if hasErrors {
                Text("Error Breakdown")
                    .font(self.fonts.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(self.runicTheme.secondaryText)

                HStack(spacing: RunicSpacing.sm) {
                    if aggregated.timeoutCount > 0 {
                        ErrorTypeLabel(type: "Timeout", count: aggregated.timeoutCount, color: .orange)
                    }
                    if aggregated.quotaCount > 0 {
                        ErrorTypeLabel(type: "Quota", count: aggregated.quotaCount, color: .red)
                    }
                    if aggregated.networkCount > 0 {
                        ErrorTypeLabel(type: "Network", count: aggregated.networkCount, color: .blue)
                    }
                    if aggregated.apiErrorCount > 0 {
                        ErrorTypeLabel(type: "API", count: aggregated.apiErrorCount, color: .purple)
                    }
                }
            }
        }
    }
}
