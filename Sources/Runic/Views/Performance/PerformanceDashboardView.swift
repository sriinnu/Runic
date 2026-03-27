import Charts
import RunicCore
import SwiftUI

/// Performance monitoring dashboard with quality metrics, latency charts, and error tracking
@MainActor
struct PerformanceDashboardView: View {

    // MARK: - Types

    enum TimeRange: String, CaseIterable, Identifiable {
        case day24h = "24h"
        case days7 = "7d"
        case days30 = "30d"

        var id: String { self.rawValue }

        var displayName: String { self.rawValue }

        var days: Int {
            switch self {
            case .day24h: return 1
            case .days7: return 7
            case .days30: return 30
            }
        }
    }

    struct FilterSelection {
        var timeRange: TimeRange = .days7
        var provider: UsageProvider?
        var model: String?
    }

    // MARK: - State

    @State private var selection = FilterSelection()
    @State private var stats: [DailyPerformanceStats] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let width: CGFloat

    // MARK: - Initialization

    init(width: CGFloat = 480) {
        self.width = width
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RunicSpacing.md) {
                self.headerSection

                if self.isLoading {
                    self.loadingView
                } else if let error = self.errorMessage {
                    self.errorView(error)
                } else if self.stats.isEmpty {
                    self.emptyStateView
                } else {
                    self.metricsSection
                    Divider()
                    self.latencyChartSection
                    Divider()
                    self.errorRateChartSection
                    Divider()
                    self.qualityRatingSection
                }
            }
            .padding(RunicSpacing.md)
        }
        .runicTypography()
        .frame(width: self.width)
        .task {
            await self.loadData()
        }
        .onChange(of: self.selection.timeRange) { _, _ in
            Task { await self.loadData() }
        }
        .onChange(of: self.selection.provider) { _, _ in
            Task { await self.loadData() }
        }
        .onChange(of: self.selection.model) { _, _ in
            Task { await self.loadData() }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Performance Dashboard")
                .font(RunicFont.title2)
                .fontWeight(.bold)

            HStack(spacing: RunicSpacing.sm) {
                self.timeRangePicker
                self.providerPicker
                if self.selection.provider != nil {
                    self.modelPicker
                }
            }
        }
    }

    private var timeRangePicker: some View {
        Picker("Time Range", selection: self.$selection.timeRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
    }

    private var providerPicker: some View {
        Picker("Provider", selection: self.$selection.provider) {
            Text("All Providers").tag(nil as UsageProvider?)
            ForEach(UsageProvider.allCases, id: \.self) { provider in
                Text(provider.rawValue).tag(provider as UsageProvider?)
            }
        }
        .frame(width: 140)
    }

    private var modelPicker: some View {
        Picker("Model", selection: self.$selection.model) {
            Text("All Models").tag(nil as String?)
            ForEach(self.availableModels, id: \.self) { model in
                Text(model).tag(model as String?)
            }
        }
        .frame(width: 140)
    }

    private var availableModels: [String] {
        let models = self.stats.compactMap { $0.model }.filter { !$0.isEmpty }
        return Array(Set(models)).sorted()
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Key Metrics")
                .font(RunicFont.headline)
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

    // MARK: - Latency Chart Section

    private var latencyChartSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Latency Over Time")
                .font(RunicFont.headline)
                .fontWeight(.semibold)

            if self.stats.isEmpty {
                Text("No latency data available")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.secondary)
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
                            .font(RunicFont.caption2)
                        AxisGridLine()
                    }
                }
                .frame(height: 150)
                .padding(.top, RunicSpacing.xxs)
            }

            if self.hasPercentileData {
                HStack(spacing: RunicSpacing.sm) {
                    Text("Line: Avg")
                        .font(RunicFont.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(RunicFont.caption)
                        .foregroundStyle(.secondary)
                    Text("Area: P95")
                        .font(RunicFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Error Rate Chart Section

    private var errorRateChartSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Error Rate Over Time")
                .font(RunicFont.headline)
                .fontWeight(.semibold)

            if self.stats.isEmpty {
                Text("No error data available")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.secondary)
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
                            .font(RunicFont.caption2)
                        AxisGridLine()
                    }
                }
                .frame(height: 150)
                .padding(.top, RunicSpacing.xxs)
            }

            self.errorBreakdown
        }
    }

    private var errorBreakdown: some View {
        let aggregated = self.aggregateStats()
        let hasErrors = aggregated.errorCount > 0

        return VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            if hasErrors {
                Text("Error Breakdown")
                    .font(RunicFont.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

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

    // MARK: - Quality Rating Section

    private var qualityRatingSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Quality Ratings")
                .font(RunicFont.headline)
                .fontWeight(.semibold)

            let aggregated = self.aggregateStats()

            if aggregated.totalRatings == 0 {
                Text("No quality ratings yet")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            } else {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    HStack {
                        Text("Average Rating:")
                            .font(RunicFont.subheadline)
                            .foregroundStyle(.secondary)

                        if let avg = aggregated.avgQualityRating {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(avg.rounded()) ? "star.fill" : "star")
                                        .font(RunicFont.caption)
                                        .foregroundStyle(.yellow)
                                }
                                Text(String(format: "%.1f", avg))
                                    .font(RunicFont.subheadline)
                                    .fontWeight(.medium)
                            }
                        }

                        Spacer()

                        Text("\(aggregated.totalRatings) ratings")
                            .font(RunicFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    self.ratingDistribution(aggregated)
                }
            }
        }
    }

    private func ratingDistribution(_ aggregated: AggregatedStats) -> some View {
        VStack(spacing: RunicSpacing.xxs) {
            ForEach([5, 4, 3, 2, 1], id: \.self) { rating in
                let count = self.ratingCount(rating, from: aggregated)
                let percent = aggregated.totalRatings > 0
                    ? Double(count) / Double(aggregated.totalRatings) * 100
                    : 0

                HStack(spacing: RunicSpacing.xs) {
                    Text("\(rating)")
                        .font(RunicFont.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: "star.fill")
                        .font(RunicFont.caption2)
                        .foregroundStyle(.yellow)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(nsColor: .tertiaryLabelColor).opacity(0.2))

                            Capsule()
                                .fill(Color.yellow)
                                .frame(width: geo.size.width * (percent / 100))
                        }
                    }
                    .frame(height: 6)

                    Text("\(count)")
                        .font(RunicFont.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }

    private func ratingCount(_ rating: Int, from aggregated: AggregatedStats) -> Int {
        switch rating {
        case 1: return aggregated.rating1Count
        case 2: return aggregated.rating2Count
        case 3: return aggregated.rating3Count
        case 4: return aggregated.rating4Count
        case 5: return aggregated.rating5Count
        default: return 0
        }
    }

    // MARK: - Loading & Error States

    private var loadingView: some View {
        VStack(spacing: RunicSpacing.sm) {
            ProgressView()
                .controlSize(.regular)
            Text("Loading performance data...")
                .font(RunicFont.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: RunicSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(RunicFont.largeTitle)
                .foregroundStyle(.red)
            Text("Error Loading Data")
                .font(RunicFont.headline)
            Text(message)
                .font(RunicFont.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await self.loadData() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyStateView: some View {
        VStack(spacing: RunicSpacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(RunicFont.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Data Available")
                .font(RunicFont.headline)
            Text("Performance data will appear here once you start using AI providers")
                .font(RunicFont.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Data Loading

    private func loadData() async {
        self.isLoading = true
        self.errorMessage = nil

        do {
            let storage = PerformanceStorageImpl()
            self.stats = try await storage.fetchDailyStats(
                timeRange: self.selection.timeRange.days,
                provider: self.selection.provider,
                model: self.selection.model
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
    }

    // MARK: - Helpers

    private var hasPercentileData: Bool {
        self.stats.contains { $0.p95LatencyMs > 0 }
    }

    private func dateFromKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    private var providerColor: Color {
        guard let provider = self.selection.provider else {
            return Color(nsColor: .controlAccentColor)
        }
        let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
        let color = descriptor.branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private func errorRateColor(_ rate: Double) -> Color {
        let percent = rate * 100
        if percent < 2.0 { return .green }
        if percent < 5.0 { return .yellow }
        if percent < 10.0 { return .orange }
        return .red
    }

    // MARK: - Aggregation

    private struct AggregatedStats {
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

    private func aggregateStats() -> AggregatedStats {
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

// MARK: - Supporting Views

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            HStack {
                Image(systemName: self.icon)
                    .font(RunicFont.caption)
                    .foregroundStyle(self.color)
                Text(self.title)
                    .font(RunicFont.caption)
                    .foregroundStyle(.secondary)
            }
            Text(self.value)
                .font(RunicFont.title3)
                .fontWeight(.semibold)
                .foregroundStyle(self.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RunicSpacing.xs)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ErrorTypeLabel: View {
    let type: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(self.color)
                .frame(width: 8, height: 8)
            Text("\(self.type): \(self.count)")
                .font(RunicFont.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
