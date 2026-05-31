import Foundation
import RunicCore
import SwiftUI

extension PerformanceDashboardView {
    var loadingView: some View {
        VStack(spacing: RunicSpacing.sm) {
            ProgressView()
                .controlSize(.regular)
            Text("Loading performance data...")
                .font(self.fonts.subheadline)
                .foregroundStyle(self.runicTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    func errorView(_ message: String) -> some View {
        VStack(spacing: RunicSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(self.fonts.largeTitle)
                .foregroundStyle(.red)
            Text("Error Loading Data")
                .font(self.fonts.headline)
            Text(message)
                .font(self.fonts.subheadline)
                .foregroundStyle(self.runicTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await self.loadData() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    var emptyStateView: some View {
        VStack(spacing: RunicSpacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(self.fonts.largeTitle)
                .foregroundStyle(self.runicTheme.secondaryText)
            Text("No Data Available")
                .font(self.fonts.headline)
            Text("Performance data will appear here once you start using AI providers")
                .font(self.fonts.subheadline)
                .foregroundStyle(self.runicTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    func loadData() async {
        self.isLoading = true
        self.errorMessage = nil

        do {
            let storage = PerformanceStorageImpl()
            self.stats = try await storage.fetchDailyStats(
                timeRange: self.selection.timeRange.days,
                provider: self.selection.provider,
                model: self.selection.model)
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
    }

    var hasPercentileData: Bool {
        self.stats.contains { $0.p95LatencyMs > 0 }
    }

    func dateFromKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    var providerColor: Color {
        guard let provider = self.selection.provider else {
            return Color(nsColor: .controlAccentColor)
        }
        let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
        let color = descriptor.branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    func errorRateColor(_ rate: Double) -> Color {
        let percent = rate * 100
        if percent < 2.0 { return .green }
        if percent < 5.0 { return .yellow }
        if percent < 10.0 { return .orange }
        return .red
    }
}
