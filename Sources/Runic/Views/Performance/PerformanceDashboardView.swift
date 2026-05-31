import RunicCore
import SwiftUI

/// Performance monitoring dashboard with quality metrics, latency charts, and error tracking
@MainActor
struct PerformanceDashboardView: View {
    @Environment(\.runicFonts) var fonts
    @Environment(\.runicTheme) var runicTheme

    // MARK: - Types

    enum TimeRange: String, CaseIterable, Identifiable {
        case day24h = "24h"
        case days7 = "7d"
        case days30 = "30d"

        var id: String {
            self.rawValue
        }

        var displayName: String {
            self.rawValue
        }

        var days: Int {
            switch self {
            case .day24h: 1
            case .days7: 7
            case .days30: 30
            }
        }
    }

    struct FilterSelection {
        var timeRange: TimeRange = .days7
        var provider: UsageProvider?
        var model: String?
    }

    // MARK: - State

    @State var selection = FilterSelection()
    @State var stats: [DailyPerformanceStats] = []
    @State var isLoading = false
    @State var errorMessage: String?

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
}
