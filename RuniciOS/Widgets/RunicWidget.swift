import SwiftUI
import WidgetKit
import RunicCore

// MARK: - Widget Bundle

/// Main widget bundle containing all Runic widgets
///
/// Provides the entry point for WidgetKit and bundles all widget types together.
@main
struct RunicWidgets: WidgetBundle {
    var body: some Widget {
        RunicSmallWidget()
        RunicMediumWidget()
        RunicLargeWidget()
        RunicLockScreenWidget()
    }
}

// MARK: - Shared Widget View

/// Base widget view that routes to appropriate size-specific view
///
/// Provides consistent styling and handles deep linking for all widget sizes.
struct RunicWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: RunicWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)

            case .systemMedium:
                MediumWidgetView(entry: entry)

            case .systemLarge, .systemExtraLarge:
                LargeWidgetView(entry: entry)

            case .accessoryCircular:
                LockScreenCircularView(entry: entry)

            case .accessoryRectangular:
                LockScreenRectangularView(entry: entry)

            case .accessoryInline:
                LockScreenInlineView(entry: entry)

            @unknown default:
                SmallWidgetView(entry: entry)
            }
        }
        .widgetURL(deepLink)
        .containerBackground(backgroundGradient, for: .widget)
    }

    /// Deep link URL to open the app
    private var deepLink: URL {
        // Open to main usage view
        URL(string: "runic://usage")!
    }

    /// Background gradient based on overall usage
    private var backgroundGradient: some View {
        Group {
            if entry.isPlaceholder {
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                let status = entry.systemStatus
                switch status {
                case .normal:
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.15, blue: 0.1),
                            Color(red: 0.02, green: 0.08, blue: 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .warning:
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.15, blue: 0.05),
                            Color(red: 0.1, green: 0.08, blue: 0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .critical:
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.05, blue: 0.05),
                            Color(red: 0.1, green: 0.02, blue: 0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }
}

// MARK: - Shared Components

/// Progress ring component for usage display
///
/// Shows circular progress with color-coded severity.
struct UsageProgressRing: View {
    let provider: WidgetProviderData
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    Color.white.opacity(0.1),
                    lineWidth: size * 0.08
                )

            // Progress circle
            Circle()
                .trim(from: 0, to: provider.usedPercent / 100)
                .stroke(
                    severityColor,
                    style: StrokeStyle(
                        lineWidth: size * 0.08,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: size * 0.05) {
                Text("\(Int(provider.remainingPercent))%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text("left")
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
    }

    private var severityColor: Color {
        switch provider.severity {
        case .normal:
            return Color.green
        case .elevated:
            return Color.yellow
        case .high:
            return Color.orange
        case .critical:
            return Color.red
        }
    }
}

/// Provider header with icon and name
struct ProviderHeader: View {
    let provider: WidgetProviderData
    let iconSize: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            // Provider color indicator
            Circle()
                .fill(Color(
                    red: provider.color.red,
                    green: provider.color.green,
                    blue: provider.color.blue
                ))
                .frame(width: iconSize, height: iconSize)

            Text(provider.displayName)
                .font(.system(size: iconSize * 0.8, weight: .semibold))
                .foregroundColor(.white)

            Spacer()
        }
    }
}

/// Compact usage bar for list displays
struct CompactUsageBar: View {
    let provider: WidgetProviderData
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Text("\(Int(provider.remainingPercent))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.white.opacity(0.1))

                    // Progress
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(severityGradient)
                        .frame(width: geometry.size.width * (provider.usedPercent / 100))
                }
            }
            .frame(height: height)
        }
    }

    private var severityGradient: LinearGradient {
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
            colors: [color, color.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Preview Provider

struct RunicWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = RunicWidgetEntry.placeholder()

        Group {
            // Small widget preview
            RunicWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")

            // Medium widget preview
            RunicWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")

            // Large widget preview
            RunicWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
        }
    }
}
