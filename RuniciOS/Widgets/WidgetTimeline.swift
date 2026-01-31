import Foundation
import WidgetKit
import RunicCore

// MARK: - Timeline Provider

/// Timeline provider for Runic widgets
///
/// Manages widget data refresh cycles and provides timeline entries to WidgetKit.
/// Implements a smart refresh strategy to balance data freshness with battery life.
public struct RunicTimelineProvider: TimelineProvider {
    public typealias Entry = RunicWidgetEntry

    // MARK: - Configuration

    /// Refresh interval for home screen widgets (15 minutes)
    private let homeScreenRefreshInterval: TimeInterval = 15 * 60

    /// Refresh interval for lock screen widgets (1 hour)
    private let lockScreenRefreshInterval: TimeInterval = 60 * 60

    // MARK: - Initializer

    public init() {}

    // MARK: - TimelineProvider Methods

    /// Provides a placeholder entry for initial widget display
    public func placeholder(in context: Context) -> RunicWidgetEntry {
        RunicWidgetEntry.placeholder()
    }

    /// Provides a snapshot entry for widget gallery and transitions
    ///
    /// - Parameters:
    ///   - context: The widget context containing family and environment info
    ///   - completion: Completion handler receiving the snapshot entry
    public func getSnapshot(
        in context: Context,
        completion: @escaping (RunicWidgetEntry) -> Void
    ) {
        if context.isPreview {
            // Use placeholder for previews
            completion(RunicWidgetEntry.placeholder())
            return
        }

        // For real snapshots, attempt to load cached data
        Task {
            let entry = await loadWidgetEntry(for: context)
            completion(entry)
        }
    }

    /// Provides a timeline of entries for widget updates
    ///
    /// - Parameters:
    ///   - context: The widget context containing family and environment info
    ///   - completion: Completion handler receiving the timeline
    public func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<RunicWidgetEntry>) -> Void
    ) {
        Task {
            let entry = await loadWidgetEntry(for: context)
            let refreshInterval = self.refreshInterval(for: context.family)
            let nextUpdate = Date().addingTimeInterval(refreshInterval)

            let timeline = Timeline(
                entries: [entry],
                policy: .after(nextUpdate)
            )

            completion(timeline)
        }
    }

    // MARK: - Data Loading

    /// Load widget entry from cached snapshot data
    ///
    /// - Parameter context: Widget context for configuration
    /// - Returns: Widget entry with current usage data
    private func loadWidgetEntry(for context: Context) async -> RunicWidgetEntry {
        let configuration = loadConfiguration(for: context)

        // Load snapshot from shared container
        guard let snapshot = WidgetSnapshotStore.load() else {
            return RunicWidgetEntry.placeholder(configuration: configuration)
        }

        // Ensure we have recent data (within 2 hours)
        let dataAge = Date().timeIntervalSince(snapshot.generatedAt)
        if dataAge > 2 * 60 * 60 {
            return RunicWidgetEntry.placeholder(configuration: configuration)
        }

        return RunicWidgetEntry(
            date: Date(),
            snapshot: snapshot,
            configuration: configuration,
            isPlaceholder: false
        )
    }

    /// Load widget configuration
    ///
    /// - Parameter context: Widget context
    /// - Returns: Widget configuration with user preferences
    private func loadConfiguration(for context: Context) -> WidgetConfiguration {
        // Load selected provider for small widgets
        let selectedProvider = WidgetSelectionStore.loadSelectedProvider()

        // Determine configuration based on widget family
        switch context.family {
        case .systemSmall:
            return WidgetConfiguration(
                primaryProvider: selectedProvider ?? .claude,
                additionalProviders: [],
                showEnabledOnly: true,
                sortBySeverity: true
            )

        case .systemMedium:
            return WidgetConfiguration(
                primaryProvider: selectedProvider,
                additionalProviders: [],
                showEnabledOnly: true,
                sortBySeverity: true
            )

        case .systemLarge, .systemExtraLarge:
            return WidgetConfiguration(
                primaryProvider: nil,
                additionalProviders: [],
                showEnabledOnly: true,
                sortBySeverity: true
            )

        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            return WidgetConfiguration(
                primaryProvider: selectedProvider ?? .claude,
                additionalProviders: [],
                showEnabledOnly: true,
                sortBySeverity: false
            )

        @unknown default:
            return .default
        }
    }

    /// Determine refresh interval based on widget family
    ///
    /// - Parameter family: Widget family
    /// - Returns: Refresh interval in seconds
    private func refreshInterval(for family: WidgetFamily) -> TimeInterval {
        switch family {
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            // Lock screen widgets refresh less frequently
            return lockScreenRefreshInterval

        default:
            // Home screen widgets refresh more frequently
            return homeScreenRefreshInterval
        }
    }
}

// MARK: - Widget Entry Extensions

extension RunicWidgetEntry {
    /// Get providers to display based on configuration and widget family
    ///
    /// - Parameter family: Widget family
    /// - Returns: Array of provider data sorted and filtered for display
    public func providers(for family: WidgetFamily) -> [WidgetProviderData] {
        let maxCount = WidgetSizeHelper.maxProviders(for: family)

        // Convert entries to widget data
        var allProviders = snapshot.entries.map { entry in
            WidgetProviderData.from(entry: entry)
        }

        // Filter to enabled providers if configured
        if configuration.showEnabledOnly {
            allProviders = allProviders.filter { provider in
                snapshot.enabledProviders.contains(provider.id)
            }
        }

        // Sort by severity if configured
        if configuration.sortBySeverity {
            allProviders.sort { lhs, rhs in
                // Sort by severity (critical first), then by usage percentage
                if lhs.severity != rhs.severity {
                    return severityOrder(lhs.severity) < severityOrder(rhs.severity)
                }
                return lhs.usedPercent > rhs.usedPercent
            }
        }

        // For small widgets, prioritize configured provider
        if family == .systemSmall, let primaryProvider = configuration.primaryProvider {
            if let provider = allProviders.first(where: { $0.id == primaryProvider }) {
                return [provider]
            }
        }

        // Return limited set based on widget size
        return Array(allProviders.prefix(maxCount))
    }

    /// Severity ordering for sorting (lower is more urgent)
    private func severityOrder(_ severity: UsageSeverity) -> Int {
        switch severity {
        case .critical: return 0
        case .high: return 1
        case .elevated: return 2
        case .normal: return 3
        }
    }

    /// Get the most critical provider (highest usage)
    public var mostCriticalProvider: WidgetProviderData? {
        let providers = snapshot.entries.map { WidgetProviderData.from(entry: $0) }
        return providers.max { lhs, rhs in
            lhs.usedPercent < rhs.usedPercent
        }
    }

    /// Get overall system status
    public var systemStatus: SystemStatus {
        let allProviders = snapshot.entries.map { WidgetProviderData.from(entry: $0) }

        let criticalCount = allProviders.filter { $0.severity == .critical }.count
        let highCount = allProviders.filter { $0.severity == .high }.count

        if criticalCount > 0 {
            return .critical
        } else if highCount > 0 {
            return .warning
        } else {
            return .normal
        }
    }

    /// System-wide status indicator
    public enum SystemStatus {
        case normal
        case warning
        case critical

        public var displayText: String {
            switch self {
            case .normal: return "All systems normal"
            case .warning: return "Some limits approaching"
            case .critical: return "Critical usage detected"
            }
        }

        public var iconName: String {
            switch self {
            case .normal: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }
}
