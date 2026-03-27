import SwiftUI
import WidgetKit
import RunicCore

// MARK: - Lock Screen Widget Configuration

/// Lock screen widget bundle
///
/// Provides circular, rectangular, and inline widgets for the iOS lock screen.
/// These widgets are optimized for minimal battery impact and quick glanceability.
struct RunicLockScreenWidget: Widget {
    let kind: String = "RunicLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: RunicTimelineProvider()
        ) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Runic Lock Screen")
        .description("Quick glance at usage on your lock screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Lock Screen Widget Router

/// Routes to appropriate lock screen widget view based on family
struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: RunicWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)

        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)

        case .accessoryInline:
            LockScreenInlineView(entry: entry)

        default:
            EmptyView()
        }
    }
}

// MARK: - Circular Lock Screen Widget

/// Circular lock screen widget showing single provider progress
///
/// Displays a compact circular gauge with usage percentage.
struct LockScreenCircularView: View {
    let entry: RunicWidgetEntry

    var body: some View {
        if let provider = primaryProvider {
            ZStack {
                // Progress ring
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: provider.usedPercent / 100)
                    .stroke(
                        severityColor(for: provider),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 1) {
                    Text("\(Int(provider.remainingPercent))")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))

                    Text("%")
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(0.8)
                }
            }
            .widgetAccentable()
        } else {
            // Placeholder
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16))
                    .opacity(0.5)
            }
        }
    }

    private var primaryProvider: WidgetProviderData? {
        entry.providers(for: .accessoryCircular).first
    }

    private func severityColor(for provider: WidgetProviderData) -> Color {
        switch provider.severity {
        case .normal: return .green
        case .elevated: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Rectangular Lock Screen Widget

/// Rectangular lock screen widget showing provider details
///
/// Displays provider name, usage bar, and reset countdown.
struct LockScreenRectangularView: View {
    let entry: RunicWidgetEntry

    var body: some View {
        if let provider = primaryProvider {
            VStack(alignment: .leading, spacing: 4) {
                // Provider name and percentage
                HStack {
                    Text(provider.displayName)
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Text("\(Int(provider.remainingPercent))%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))

                        RoundedRectangle(cornerRadius: 2)
                            .fill(severityColor(for: provider))
                            .frame(width: geometry.size.width * (provider.usedPercent / 100))
                    }
                }
                .frame(height: 6)

                // Reset countdown
                if let countdown = provider.resetCountdown {
                    Text("Resets \(countdown)")
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.7)
                } else {
                    Text("Updated \(relativeTime(from: provider.updatedAt))")
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.7)
                }
            }
            .widgetAccentable()
        } else {
            // Placeholder
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))

                    Text("No Data")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Open Runic to sync")
                    .font(.system(size: 11))
                    .opacity(0.6)
            }
        }
    }

    private var primaryProvider: WidgetProviderData? {
        entry.providers(for: .accessoryRectangular).first
    }

    private func severityColor(for provider: WidgetProviderData) -> Color {
        switch provider.severity {
        case .normal: return .green
        case .elevated: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)

        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }
}

// MARK: - Inline Lock Screen Widget

/// Inline lock screen widget showing compact usage summary
///
/// Displays a single line of text with provider name and percentage.
struct LockScreenInlineView: View {
    let entry: RunicWidgetEntry

    var body: some View {
        if let provider = primaryProvider {
            HStack(spacing: 4) {
                Image(systemName: statusIcon(for: provider))
                    .font(.system(size: 12))

                Text("\(provider.displayName):")
                    .font(.system(size: 12, weight: .medium))

                Text("\(Int(provider.remainingPercent))% left")
                    .font(.system(size: 12, weight: .semibold))
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12))

                Text("Runic: No data")
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private var primaryProvider: WidgetProviderData? {
        entry.providers(for: .accessoryInline).first
    }

    private func statusIcon(for provider: WidgetProviderData) -> String {
        switch provider.severity {
        case .normal: return "checkmark.circle.fill"
        case .elevated: return "minus.circle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}

// MARK: - Preview Provider

struct LockScreenWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = RunicWidgetEntry.placeholder()

        Group {
            // Circular preview
            LockScreenCircularView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular")

            // Rectangular preview
            LockScreenRectangularView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular")

            // Inline preview
            LockScreenInlineView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("Inline")
        }
    }
}
