import SwiftUI
import WidgetKit
import RunicCore

// MARK: - Small Widget Configuration

/// Small home screen widget showing a single provider
///
/// Displays the most critical provider or user-selected provider with:
/// - Circular progress ring
/// - Provider name and icon
/// - Remaining percentage
/// - Reset countdown
struct RunicSmallWidget: Widget {
    let kind: String = "RunicSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: RunicTimelineProvider()
        ) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Runic Usage")
        .description("Monitor AI provider usage at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Small Widget View

/// View implementation for small widget
///
/// Optimized for compact display with focus on the most important provider.
struct SmallWidgetView: View {
    let entry: RunicWidgetEntry

    var body: some View {
        if entry.isPlaceholder {
            placeholderView
        } else if let provider = primaryProvider {
            contentView(for: provider)
        } else {
            emptyStateView
        }
    }

    // MARK: - Content Views

    /// Main content view for a single provider
    private func contentView(for provider: WidgetProviderData) -> some View {
        VStack(spacing: 12) {
            // Header with provider name
            HStack {
                Circle()
                    .fill(Color(
                        red: provider.color.red,
                        green: provider.color.green,
                        blue: provider.color.blue
                    ))
                    .frame(width: 8, height: 8)

                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Status indicator
                Image(systemName: statusIcon(for: provider))
                    .font(.system(size: 12))
                    .foregroundColor(statusColor(for: provider))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            // Progress ring
            UsageProgressRing(provider: provider, size: 80)

            Spacer()

            // Reset countdown
            VStack(spacing: 2) {
                if let countdown = provider.resetCountdown {
                    Text("Resets")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    Text(countdown)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    Text("Updated")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    Text(relativeTime(from: provider.updatedAt))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.bottom, 12)
        }
    }

    /// Placeholder view for loading state
    private var placeholderView: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 8, height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 60, height: 12)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            // Placeholder ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 80, height: 80)

                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 30, height: 20)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 24, height: 10)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 40, height: 10)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 50, height: 12)
            }
            .padding(.bottom, 12)
        }
    }

    /// Empty state when no data available
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.5))

            Text("No Data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Text("Open app to refresh")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Helper Properties

    /// Get the primary provider to display
    private var primaryProvider: WidgetProviderData? {
        entry.providers(for: .systemSmall).first
    }

    // MARK: - Helper Methods

    /// Get status icon for provider severity
    private func statusIcon(for provider: WidgetProviderData) -> String {
        switch provider.severity {
        case .normal:
            return "checkmark.circle.fill"
        case .elevated:
            return "exclamationmark.circle.fill"
        case .high:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }

    /// Get status color for provider severity
    private func statusColor(for provider: WidgetProviderData) -> Color {
        switch provider.severity {
        case .normal:
            return .green
        case .elevated:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }

    /// Format relative time string
    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)

        if minutes < 1 {
            return "just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            let hours = minutes / 60
            return "\(hours)h ago"
        }
    }
}

// MARK: - Preview Provider

struct SmallWidget_Previews: PreviewProvider {
    static var previews: some View {
        let normalEntry = RunicWidgetEntry.placeholder()

        let criticalProvider = WidgetSnapshot.ProviderEntry(
            provider: .claude,
            updatedAt: Date(),
            primary: RateWindow(
                usedPercent: 95.0,
                windowMinutes: 300,
                resetsAt: Date().addingTimeInterval(1800),
                resetDescription: "in 30m"
            ),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: []
        )

        let criticalSnapshot = WidgetSnapshot(
            entries: [criticalProvider],
            enabledProviders: [.claude],
            generatedAt: Date()
        )

        let criticalEntry = RunicWidgetEntry(
            date: Date(),
            snapshot: criticalSnapshot,
            configuration: .default,
            isPlaceholder: false
        )

        Group {
            SmallWidgetView(entry: normalEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Normal Usage")

            SmallWidgetView(entry: criticalEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Critical Usage")

            SmallWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Placeholder")
        }
    }
}
