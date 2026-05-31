import Foundation
import RunicCore

/// Exports usage data from the ledger as CSV or JSON.
@MainActor
enum UsageExporter {
    enum Format: String {
        case csv
        case json
    }

    enum Scope: String {
        case all
        case timeline
        case timeline3d
        case timeline7d
        case timeline30d
        case timeline90d
        case timeline1y
        case hourly
        case weekly
        case utilization
        case windows
        case projects
        case models

        var displayName: String {
            switch self {
            case .all: "all usage"
            case .timeline: "timeline"
            case .timeline3d: "timeline, 3 days"
            case .timeline7d: "timeline, 7 days"
            case .timeline30d: "timeline, 30 days"
            case .timeline90d: "timeline, 90 days"
            case .timeline1y: "timeline, 1 year"
            case .hourly: "today by hour"
            case .weekly: "last 7 days"
            case .utilization: "utilization"
            case .windows: "usage windows"
            case .projects: "projects"
            case .models: "models"
            }
        }

        var fileSuffix: String {
            switch self {
            case .all: "usage"
            case .timeline: "timeline"
            case .timeline3d: "timeline-3-days"
            case .timeline7d: "timeline-7-days"
            case .timeline30d: "timeline-30-days"
            case .timeline90d: "timeline-90-days"
            case .timeline1y: "timeline-1-year"
            case .hourly: "hourly"
            case .weekly: "7-days"
            case .utilization: "utilization"
            case .windows: "windows"
            case .projects: "projects"
            case .models: "models"
            }
        }
    }

    /// Build an export string for the given provider in the requested format.
    static func export(
        store: UsageStore,
        provider: UsageProvider,
        format: Format,
        scope: Scope = .all) -> String
    {
        switch format {
        case .csv:
            self.exportCSV(store: store, provider: provider, scope: scope)
        case .json:
            self.exportJSON(store: store, provider: provider, scope: scope)
        }
    }
}
