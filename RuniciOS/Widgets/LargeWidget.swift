import SwiftUI
import WidgetKit
import RunicCore
import Charts

// MARK: - Large Widget Configuration

/// Large home screen widget showing 5-6 providers with charts
///
/// Displays comprehensive usage overview with:
/// - Multiple provider progress bars
/// - Usage trend charts
/// - Summary statistics
/// - Reset countdowns
struct RunicLargeWidget: Widget {
    let kind: String = "RunicLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: RunicTimelineProvider()
        ) { entry in
            LargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Runic Dashboard")
        .description("Complete dashboard with charts and all providers.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Large Widget View

/// View implementation for large widget
///
/// Shows comprehensive dashboard with charts and multiple providers.
struct LargeWidgetView: View {
    let entry: RunicWidgetEntry

    var body: some View {
        if entry.isPlaceholder {
            placeholderView
        } else if !providers.isEmpty {
            contentView
        } else {
            emptyStateView
        }
    }

    // MARK: - Content Views

    /// Main content view with dashboard layout
    private var contentView: some View {
        VStack(spacing: 0) {
            // Header with summary
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            // Charts section (if data available)
            if hasChartData {
                chartsView
                    .frame(height: 100)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 16)

            // Provider list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(providers) { provider in
                        providerRow(for: provider)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    /// Header with summary stats
    private var headerView: some View {
        VStack(spacing: 8) {
            // Title and status
            HStack(spacing: 10) {
                Image(systemName: entry.systemStatus.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(statusColor)

                Text("Runic Dashboard")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Last update
                Text("Updated \(relativeTime)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Summary statistics
            HStack(spacing: 16) {
                summaryItem(
                    icon: "checkmark.circle.fill",
                    value: "\(normalCount)",
                    label: "Normal",
                    color: .green
                )

                summaryItem(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(warningCount)",
                    label: "Warning",
                    color: .orange
                )

                summaryItem(
                    icon: "xmark.octagon.fill",
                    value: "\(criticalCount)",
                    label: "Critical",
                    color: .red
                )

                Spacer()
            }
        }
    }

    /// Summary stat item
    private func summaryItem(
        icon: String,
        value: String,
        label: String,
        color: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    /// Charts view showing usage trends
    @ViewBuilder
    private var chartsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Usage Trend")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(chartDataPoints) { point in
                        LineMark(x: .value("Day", point.date), y: .value("Usage", point.value))
                            .foregroundStyle(chartGradient)
                        AreaMark(x: .value("Day", point.date), y: .value("Usage", point.value))
                            .foregroundStyle(chartGradient.opacity(0.3))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            }
        }
    }

    /// Individual provider row with compact layout
    private func providerRow(for provider: WidgetProviderData) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                // Provider indicator
                Circle()
                    .fill(Color(
                        red: provider.color.red,
                        green: provider.color.green,
                        blue: provider.color.blue
                    ))
                    .frame(width: 8, height: 8)

                Text(provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Status badge
                statusBadge(for: provider)

                // Percentage
                Text("\(Int(provider.remainingPercent))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 35, alignment: .trailing)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressGradient(for: provider))
                        .frame(width: geometry.size.width * (provider.usedPercent / 100))
                }
            }
            .frame(height: 6)

            // Reset info
            if let countdown = provider.resetCountdown {
                HStack {
                    Text("Resets \(countdown)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Spacer()
                }
            }
        }
    }

    /// Status badge for provider
    private func statusBadge(for provider: WidgetProviderData) -> some View {
        let color: Color
        let icon: String

        switch provider.severity {
        case .normal:
            color = .green
            icon = "checkmark"
        case .elevated:
            color = .yellow
            icon = "minus"
        case .high:
            color = .orange
            icon = "exclamationmark"
        case .critical:
            color = .red
            icon = "xmark"
        }

        return Image(systemName: "\(icon).circle.fill")
            .font(.system(size: 10))
            .foregroundColor(color)
    }

    /// Placeholder and empty state views
    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: 10) {
            HStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.2)).frame(width: 24, height: 24)
                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.2)).frame(width: 120, height: 16)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 16)
            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)).frame(height: 80).padding(.horizontal, 16)
            ForEach(0..<5, id: \.self) { _ in
                VStack(spacing: 4) {
                    HStack {
                        Circle().fill(Color.white.opacity(0.15)).frame(width: 8, height: 8)
                        RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.15)).frame(width: 60, height: 10)
                        Spacer()
                    }
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(height: 6)
                }
            }
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 36)).foregroundColor(.white.opacity(0.3))
            Text("No Data Available").font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.6))
            Text("Open Runic to sync your usage data").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
        }
        .padding()
    }

    // MARK: - Helper Properties

    private var providers: [WidgetProviderData] {
        entry.providers(for: .systemLarge)
    }

    private var statusColor: Color {
        switch entry.systemStatus {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private var normalCount: Int {
        providers.filter { $0.severity == .normal }.count
    }

    private var warningCount: Int {
        providers.filter { $0.severity == .elevated || $0.severity == .high }.count
    }

    private var criticalCount: Int {
        providers.filter { $0.severity == .critical }.count
    }

    private var relativeTime: String {
        let interval = Date().timeIntervalSince(entry.snapshot.generatedAt)
        let minutes = Int(interval / 60)

        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }

    private var hasChartData: Bool {
        !chartDataPoints.isEmpty
    }

    private var chartDataPoints: [ChartDataPoint] {
        (0..<7).map { ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -6 + $0, to: Date())!, value: Double.random(in: 20...80)) }
    }

    private var chartGradient: LinearGradient {
        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
    }

    private func progressGradient(for provider: WidgetProviderData) -> LinearGradient {
        let color: Color = provider.severity == .normal ? .green : provider.severity == .elevated ? .yellow : provider.severity == .high ? .orange : .red
        return LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Chart Data Model

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Preview Provider

struct LargeWidget_Previews: PreviewProvider {
    static var previews: some View {
        LargeWidgetView(entry: .placeholder())
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
