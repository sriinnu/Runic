import SwiftUI
import WidgetKit
import RunicCore

// MARK: - Medium Widget Configuration

/// Medium home screen widget showing 2-3 providers
///
/// Displays multiple providers with:
/// - Horizontal progress bars
/// - Provider names and icons
/// - Remaining percentages
/// - Summary status indicator
struct RunicMediumWidget: Widget {
    let kind: String = "RunicMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: RunicTimelineProvider()
        ) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Runic Multi-Provider")
        .description("Monitor multiple AI providers simultaneously.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Medium Widget View

/// View implementation for medium widget
///
/// Shows up to 3 providers with compact horizontal bars.
struct MediumWidgetView: View {
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

    /// Main content view with multiple providers
    private var contentView: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 16)

            // Provider list
            VStack(spacing: 12) {
                ForEach(providers) { provider in
                    providerRow(for: provider)
                }

                if providers.count < 3 {
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// Header with status summary
    private var headerView: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: entry.systemStatus.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(statusColor)

            Text("Runic")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Provider count
            Text("\(providers.count) active")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    /// Individual provider row
    private func providerRow(for provider: WidgetProviderData) -> some View {
        VStack(spacing: 6) {
            // Provider info
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(
                        red: provider.color.red,
                        green: provider.color.green,
                        blue: provider.color.blue
                    ))
                    .frame(width: 10, height: 10)

                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Remaining percentage
                Text("\(Int(provider.remainingPercent))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressGradient(for: provider))
                        .frame(width: geometry.size.width * (provider.usedPercent / 100))
                }
            }
            .frame(height: 8)

            // Reset countdown
            if let countdown = provider.resetCountdown {
                HStack {
                    Text("Resets \(countdown)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Spacer()
                }
            }
        }
    }

    /// Placeholder view for loading state
    private var placeholderView: some View {
        VStack(spacing: 0) {
            // Header placeholder
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 20, height: 20)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 60, height: 14)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 50, height: 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 16)

            // Provider placeholders
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    placeholderRow
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// Placeholder for a single provider row
    private var placeholderRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 10, height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 70, height: 12)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 14)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(height: 8)

            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 10)

                Spacer()
            }
        }
    }

    /// Empty state when no data available
    private var emptyStateView: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 4) {
                Text("No Providers Active")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                Text("Open Runic to enable providers")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Helper Properties

    /// Get providers to display
    private var providers: [WidgetProviderData] {
        entry.providers(for: .systemMedium)
    }

    /// Status color based on system status
    private var statusColor: Color {
        switch entry.systemStatus {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    // MARK: - Helper Methods

    /// Get progress gradient for provider severity
    private func progressGradient(for provider: WidgetProviderData) -> LinearGradient {
        let color: Color
        switch provider.severity {
        case .normal:
            color = .green
        case .elevated:
            color = .yellow
        case .high:
            color = .orange
        case .critical:
            color = .red
        }

        return LinearGradient(
            colors: [color, color.opacity(0.6)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Preview Provider

struct MediumWidget_Previews: PreviewProvider {
    static var previews: some View {
        let providers = [
            WidgetSnapshot.ProviderEntry(
                provider: .claude,
                updatedAt: Date(),
                primary: RateWindow(
                    usedPercent: 75.0,
                    windowMinutes: 300,
                    resetsAt: Date().addingTimeInterval(3600),
                    resetDescription: "in 1h"
                ),
                secondary: nil,
                tertiary: nil,
                creditsRemaining: nil,
                codeReviewRemainingPercent: nil,
                tokenUsage: nil,
                dailyUsage: []
            ),
            WidgetSnapshot.ProviderEntry(
                provider: .codex,
                updatedAt: Date(),
                primary: RateWindow(
                    usedPercent: 45.0,
                    windowMinutes: 300,
                    resetsAt: Date().addingTimeInterval(7200),
                    resetDescription: "in 2h"
                ),
                secondary: nil,
                tertiary: nil,
                creditsRemaining: nil,
                codeReviewRemainingPercent: nil,
                tokenUsage: nil,
                dailyUsage: []
            ),
            WidgetSnapshot.ProviderEntry(
                provider: .gemini,
                updatedAt: Date(),
                primary: RateWindow(
                    usedPercent: 20.0,
                    windowMinutes: 300,
                    resetsAt: Date().addingTimeInterval(5400),
                    resetDescription: "in 1h 30m"
                ),
                secondary: nil,
                tertiary: nil,
                creditsRemaining: nil,
                codeReviewRemainingPercent: nil,
                tokenUsage: nil,
                dailyUsage: []
            )
        ]

        let snapshot = WidgetSnapshot(
            entries: providers,
            enabledProviders: [.claude, .codex, .gemini],
            generatedAt: Date()
        )

        let entry = RunicWidgetEntry(
            date: Date(),
            snapshot: snapshot,
            configuration: .default,
            isPlaceholder: false
        )

        Group {
            MediumWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Normal")

            MediumWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Placeholder")
        }
    }
}
