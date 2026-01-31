import Foundation
import WidgetKit
import RunicCore

// MARK: - Widget Entry

/// Timeline entry for Runic widgets
///
/// Contains the snapshot data needed to render widget UI. Each entry represents
/// a point in time with provider usage information.
public struct RunicWidgetEntry: TimelineEntry {
    /// The date for this timeline entry
    public let date: Date

    /// Widget snapshot containing usage data for all providers
    public let snapshot: WidgetSnapshot

    /// Widget configuration determining which providers to display
    public let configuration: WidgetConfiguration

    /// Whether the data is a placeholder (loading state)
    public let isPlaceholder: Bool

    public init(
        date: Date,
        snapshot: WidgetSnapshot,
        configuration: WidgetConfiguration,
        isPlaceholder: Bool = false
    ) {
        self.date = date
        self.snapshot = snapshot
        self.configuration = configuration
        self.isPlaceholder = isPlaceholder
    }
}

// MARK: - Widget Configuration

/// Configuration for widget display preferences
///
/// Controls which providers are shown and how the widget should behave.
public struct WidgetConfiguration: Codable, Hashable {
    /// Primary provider to display (for small widgets)
    public let primaryProvider: UsageProvider?

    /// Additional providers to show (for medium/large widgets)
    public let additionalProviders: [UsageProvider]

    /// Show only enabled providers
    public let showEnabledOnly: Bool

    /// Sort providers by usage severity
    public let sortBySeverity: Bool

    public init(
        primaryProvider: UsageProvider? = nil,
        additionalProviders: [UsageProvider] = [],
        showEnabledOnly: Bool = true,
        sortBySeverity: Bool = true
    ) {
        self.primaryProvider = primaryProvider
        self.additionalProviders = additionalProviders
        self.showEnabledOnly = showEnabledOnly
        self.sortBySeverity = sortBySeverity
    }

    /// Default configuration showing enabled providers
    public static var `default`: WidgetConfiguration {
        WidgetConfiguration()
    }
}

// MARK: - Widget Display Data

/// Processed provider data ready for widget display
///
/// Simplifies the provider entry data into a form optimized for widget rendering.
public struct WidgetProviderData: Identifiable, Hashable {
    public let id: UsageProvider
    public let displayName: String
    public let usedPercent: Double
    public let remainingPercent: Double
    public let resetCountdown: String?
    public let severity: UsageSeverity
    public let color: ProviderColorData
    public let updatedAt: Date

    public init(
        id: UsageProvider,
        displayName: String,
        usedPercent: Double,
        remainingPercent: Double,
        resetCountdown: String?,
        severity: UsageSeverity,
        color: ProviderColorData,
        updatedAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.resetCountdown = resetCountdown
        self.severity = severity
        self.color = color
        self.updatedAt = updatedAt
    }

    /// Create widget data from a provider entry
    public static func from(entry: WidgetSnapshot.ProviderEntry) -> WidgetProviderData {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: entry.provider)
        let metadata = descriptor.metadata
        let branding = descriptor.branding

        let usedPercent = entry.primary?.usedPercent ?? 0
        let remainingPercent = entry.primary?.remainingPercent ?? 100

        let severity = UsageSeverity.from(usedPercent: usedPercent)

        let resetCountdown: String?
        if let resetsAt = entry.primary?.resetsAt {
            resetCountdown = UsageFormatter.resetCountdownDescription(from: resetsAt)
        } else {
            resetCountdown = nil
        }

        return WidgetProviderData(
            id: entry.provider,
            displayName: metadata.displayName,
            usedPercent: usedPercent,
            remainingPercent: remainingPercent,
            resetCountdown: resetCountdown,
            severity: severity,
            color: ProviderColorData.from(branding.color),
            updatedAt: entry.updatedAt
        )
    }
}

// MARK: - Usage Severity

/// Usage severity levels for visual indicators
///
/// Determines the color and urgency of usage display.
public enum UsageSeverity: String, Codable, Hashable {
    case normal      // 0-60% used
    case elevated    // 60-80% used
    case high        // 80-95% used
    case critical    // 95-100% used

    /// Determine severity from usage percentage
    public static func from(usedPercent: Double) -> UsageSeverity {
        switch usedPercent {
        case 0..<60:
            return .normal
        case 60..<80:
            return .elevated
        case 80..<95:
            return .high
        default:
            return .critical
        }
    }

    /// System color name for this severity
    public var systemColorName: String {
        switch self {
        case .normal:
            return "green"
        case .elevated:
            return "yellow"
        case .high:
            return "orange"
        case .critical:
            return "red"
        }
    }
}

// MARK: - Provider Color Data

/// Color information for provider branding
///
/// SwiftUI-compatible color data extracted from ProviderColor.
public struct ProviderColorData: Hashable, Codable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static func from(_ color: ProviderColor) -> ProviderColorData {
        ProviderColorData(
            red: color.red,
            green: color.green,
            blue: color.blue
        )
    }
}

// MARK: - Widget Size Helpers

/// Helper for widget family-specific content selection
public enum WidgetSizeHelper {
    /// Maximum number of providers for a widget family
    public static func maxProviders(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemMedium:
            return 3
        case .systemLarge, .systemExtraLarge:
            return 6
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            return 1
        @unknown default:
            return 1
        }
    }

    /// Whether to show charts for this widget family
    public static func showsCharts(for family: WidgetFamily) -> Bool {
        switch family {
        case .systemLarge, .systemExtraLarge:
            return true
        default:
            return false
        }
    }

    /// Whether to show reset countdown for this widget family
    public static func showsResetCountdown(for family: WidgetFamily) -> Bool {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            return true
        default:
            return false
        }
    }
}

// MARK: - Placeholder Data

extension RunicWidgetEntry {
    /// Create a placeholder entry for loading states
    public static func placeholder(configuration: WidgetConfiguration = .default) -> RunicWidgetEntry {
        let placeholderProvider = WidgetSnapshot.ProviderEntry(
            provider: .claude,
            updatedAt: Date(),
            primary: RateWindow(
                usedPercent: 45.0,
                windowMinutes: 300,
                resetsAt: Date().addingTimeInterval(3600),
                resetDescription: "in 1h"
            ),
            secondary: RateWindow(
                usedPercent: 23.0,
                windowMinutes: 10080,
                resetsAt: Date().addingTimeInterval(86400),
                resetDescription: "in 1d"
            ),
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: []
        )

        let snapshot = WidgetSnapshot(
            entries: [placeholderProvider],
            enabledProviders: [.claude],
            generatedAt: Date()
        )

        return RunicWidgetEntry(
            date: Date(),
            snapshot: snapshot,
            configuration: configuration,
            isPlaceholder: true
        )
    }
}
