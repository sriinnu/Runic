import SwiftUI

extension PerformanceDashboardView {
    var metricsSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Key Metrics")
                .font(self.fonts.headline)
                .fontWeight(.semibold)

            let aggregated = self.aggregateStats()

            HStack(spacing: RunicSpacing.sm) {
                MetricCard(
                    title: "Total Requests",
                    value: "\(aggregated.totalRequests)",
                    icon: "arrow.up.arrow.down.circle")

                MetricCard(
                    title: "Avg Latency",
                    value: "\(aggregated.avgLatencyMs)ms",
                    icon: "timer")

                MetricCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", aggregated.successRate),
                    icon: "checkmark.circle",
                    color: aggregated.successRate >= 95 ? .green : (aggregated.successRate >= 90 ? .orange : .red))

                MetricCard(
                    title: "Avg Quality",
                    value: aggregated.avgQualityRating.map { String(format: "%.1f", $0) } ?? "—",
                    icon: "star.fill",
                    color: .yellow)
            }
        }
    }

    struct AggregatedStats {
        var totalRequests: Int = 0
        var avgLatencyMs: Int = 0
        var successRate: Double = 100.0
        var avgQualityRating: Double?
        var totalRatings: Int = 0
        var rating1Count: Int = 0
        var rating2Count: Int = 0
        var rating3Count: Int = 0
        var rating4Count: Int = 0
        var rating5Count: Int = 0
        var errorCount: Int = 0
        var timeoutCount: Int = 0
        var quotaCount: Int = 0
        var networkCount: Int = 0
        var apiErrorCount: Int = 0
    }

    func aggregateStats() -> AggregatedStats {
        guard !self.stats.isEmpty else { return AggregatedStats() }

        var result = AggregatedStats()
        var totalLatency = 0
        var totalErrorRate = 0.0
        var totalQuality = 0.0
        var qualityCount = 0

        for stat in self.stats {
            result.totalRequests += stat.totalRequests
            totalLatency += stat.avgLatencyMs * stat.totalRequests
            totalErrorRate += stat.errorRate

            if stat.avgQualityRating > 0 {
                totalQuality += stat.avgQualityRating * Double(stat.totalRatings)
                qualityCount += stat.totalRatings
            }

            result.totalRatings += stat.totalRatings
            result.rating1Count += stat.rating1Count
            result.rating2Count += stat.rating2Count
            result.rating3Count += stat.rating3Count
            result.rating4Count += stat.rating4Count
            result.rating5Count += stat.rating5Count
            result.errorCount += stat.errorCount
            result.timeoutCount += stat.timeoutCount
            result.quotaCount += stat.quotaCount
            result.networkCount += stat.networkCount
            result.apiErrorCount += stat.apiErrorCount
        }

        if result.totalRequests > 0 {
            result.avgLatencyMs = totalLatency / result.totalRequests
            result.successRate = (1.0 - (totalErrorRate / Double(self.stats.count))) * 100.0
        }

        if qualityCount > 0 {
            result.avgQualityRating = totalQuality / Double(qualityCount)
        }

        return result
    }
}
