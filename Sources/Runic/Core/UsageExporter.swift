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

    // MARK: - CSV

    private static func exportCSV(store: UsageStore, provider: UsageProvider, scope: Scope) -> String {
        switch scope {
        case .all:
            return self.exportDailyCSV(store: store, provider: provider)
        case .timeline:
            return self.exportLedgerDailyCSV(store: store, provider: provider, days: nil)
        case .hourly:
            return self.exportHourlyCSV(store: store, provider: provider)
        case .weekly:
            return self.exportLedgerDailyCSV(store: store, provider: provider, days: 7)
        case .utilization:
            return self.exportUtilizationCSV(store: store, provider: provider)
        case .windows:
            return self.exportWindowsCSV(store: store, provider: provider)
        case .projects:
            return self.exportProjectsCSV(store: store, provider: provider)
        case .models:
            return self.exportModelsCSV(store: store, provider: provider)
        }
    }

    private static func exportDailyCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines: [String] = []

        // Header
        lines
            .append(
                "date,input_tokens,output_tokens,cache_creation_tokens,cache_read_tokens,total_tokens,cost_usd,models_used")

        // Daily summaries from token snapshot
        let daily = store.tokenSnapshot(for: provider)?.daily ?? []

        for day in daily {
            let costStr = day.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let modelsStr = Self.csvEscape((day.modelsUsed ?? []).joined(separator: "; "))
            let input = day.inputTokens ?? 0
            let output = day.outputTokens ?? 0
            let cacheCreate = day.cacheCreationTokens ?? 0
            let cacheRead = day.cacheReadTokens ?? 0
            let total = day.totalTokens ?? (input + output + cacheCreate + cacheRead)
            lines.append("\(day.date),\(input),\(output),\(cacheCreate),\(cacheRead),\(total),\(costStr),\(modelsStr)")
        }

        // If no token snapshot daily data, fall back to ledger daily summary
        if daily.isEmpty, let summary = store.ledgerDailySummary(for: provider) {
            let costStr = summary.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let modelsStr = Self.csvEscape(summary.modelsUsed.joined(separator: "; "))
            lines
                .append(
                    "\(summary.dayKey),\(summary.totals.inputTokens),\(summary.totals.outputTokens),\(summary.totals.cacheCreationTokens),\(summary.totals.cacheReadTokens),\(summary.totals.totalTokens),\(costStr),\(modelsStr)")
        }

        return lines.joined(separator: "\n")
    }

    private static func exportLedgerDailyCSV(store: UsageStore, provider: UsageProvider, days: Int?) -> String {
        var lines = [
            "date,input_tokens,output_tokens,cache_creation_tokens,cache_read_tokens,total_tokens,cost_usd,models_used",
        ]
        let calendar = Calendar.current
        let cutoff = days.flatMap { calendar.date(byAdding: .day, value: -($0 - 1), to: calendar.startOfDay(for: Date())) }
        let summaries = store.ledgerAllDailySummary(for: provider)
            .filter { summary in
                guard let cutoff else { return true }
                return summary.dayStart >= cutoff
            }
            .sorted { $0.dayStart < $1.dayStart }
        for summary in summaries {
            let costStr = summary.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let modelsStr = Self.csvEscape(summary.modelsUsed.joined(separator: "; "))
            lines.append(
                "\(summary.dayKey),\(summary.totals.inputTokens),\(summary.totals.outputTokens),\(summary.totals.cacheCreationTokens),\(summary.totals.cacheReadTokens),\(summary.totals.totalTokens),\(costStr),\(modelsStr)")
        }
        return lines.joined(separator: "\n")
    }

    private static func exportHourlyCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines = [
            "hour,input_tokens,output_tokens,cache_creation_tokens,cache_read_tokens,total_tokens,cost_usd,requests",
        ]
        let summaries = store.ledgerHourlySummary(for: provider).sorted { $0.hourStart < $1.hourStart }
        for summary in summaries {
            let costStr = summary.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            lines.append(
                "\(summary.hourKey),\(summary.totals.inputTokens),\(summary.totals.outputTokens),\(summary.totals.cacheCreationTokens),\(summary.totals.cacheReadTokens),\(summary.totals.totalTokens),\(costStr),\(summary.requestCount)")
        }
        return lines.joined(separator: "\n")
    }

    private static func exportProjectsCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines = [
            "project_name,project_id,input_tokens,output_tokens,cache_creation_tokens,cache_read_tokens,total_tokens,cost_usd,requests,models_used",
        ]
        for project in store.ledgerProjectBreakdown(for: provider) {
            let costStr = project.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let name = Self.csvEscape(RunicProjectDisplay.name(for: project))
            let id = Self.csvEscape(project.projectID ?? "")
            let models = Self.csvEscape(project.modelsUsed.joined(separator: "; "))
            lines.append(
                "\(name),\(id),\(project.totals.inputTokens),\(project.totals.outputTokens),\(project.totals.cacheCreationTokens),\(project.totals.cacheReadTokens),\(project.totals.totalTokens),\(costStr),\(project.entryCount),\(models)")
        }
        return lines.joined(separator: "\n")
    }

    private static func exportModelsCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines = [
            "model,project_name,project_id,input_tokens,output_tokens,cache_creation_tokens,cache_read_tokens,total_tokens,cost_usd,requests",
        ]
        for model in store.ledgerModelBreakdown(for: provider) {
            let costStr = model.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let projectName = Self.csvEscape(RunicProjectDisplay.name(for: model))
            let projectID = Self.csvEscape(model.projectID ?? "")
            lines.append(
                "\(Self.csvEscape(model.model)),\(projectName),\(projectID),\(model.totals.inputTokens),\(model.totals.outputTokens),\(model.totals.cacheCreationTokens),\(model.totals.cacheReadTokens),\(model.totals.totalTokens),\(costStr),\(model.entryCount)")
        }
        return lines.joined(separator: "\n")
    }

    private static func exportUtilizationCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines = ["date,total_tokens,current_used_percent,estimated_used_percent"]
        let currentUsedPercent = store.snapshot(for: provider)?.primary.usedPercent ?? 0
        let todayTokens = store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0
        let scaleFactor = todayTokens > 0 ? currentUsedPercent / Double(todayTokens) : 0
        for summary in store.ledgerAllDailySummary(for: provider).sorted(by: { $0.dayStart < $1.dayStart }) {
            let estimated = min(100, Double(summary.totals.totalTokens) * scaleFactor)
            lines.append("\(summary.dayKey),\(summary.totals.totalTokens),\(String(format: "%.2f", currentUsedPercent)),\(String(format: "%.2f", estimated))")
        }
        return lines.joined(separator: "\n")
    }

    private static func exportWindowsCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines = ["window_label,used_percent,reset_description,resets_at"]
        guard let snapshot = store.snapshot(for: provider) else { return lines.joined(separator: "\n") }
        for window in [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self) {
            let label = Self.csvEscape(window.label ?? "Usage window")
            let reset = Self.csvEscape(window.resetDescription ?? "")
            let resetsAt = window.resetsAt.map(\.description) ?? ""
            lines.append("\(label),\(String(format: "%.2f", window.usedPercent)),\(reset),\(resetsAt)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - JSON

    private static func exportJSON(store: UsageStore, provider: UsageProvider, scope: Scope) -> String {
        let metadata = store.metadata(for: provider)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let nowStr = dateFormatter.string(from: Date())

        var root: [String: Any] = [
            "provider": provider.rawValue,
            "providerDisplayName": metadata.displayName,
            "exportedAt": nowStr,
            "scope": scope.rawValue,
            "scopeDisplayName": scope.displayName,
        ]

        // Daily summaries from token snapshot
        var dailyArray: [[String: Any]] = []
        let daily = store.tokenSnapshot(for: provider)?.daily ?? []

        for day in daily {
            let input = day.inputTokens ?? 0
            let output = day.outputTokens ?? 0
            let cacheCreate = day.cacheCreationTokens ?? 0
            let cacheRead = day.cacheReadTokens ?? 0
            let total = day.totalTokens ?? (input + output + cacheCreate + cacheRead)
            var entry: [String: Any] = [
                "date": day.date,
                "inputTokens": input,
                "outputTokens": output,
                "cacheCreationTokens": cacheCreate,
                "cacheReadTokens": cacheRead,
                "totalTokens": total,
                "models": day.modelsUsed ?? [],
            ]
            if let cost = day.costUSD {
                entry["costUSD"] = cost
            }
            dailyArray.append(entry)
        }

        // Fallback to ledger summary if no token snapshot data
        if dailyArray.isEmpty, let summary = store.ledgerDailySummary(for: provider) {
            var entry: [String: Any] = [
                "date": summary.dayKey,
                "inputTokens": summary.totals.inputTokens,
                "outputTokens": summary.totals.outputTokens,
                "cacheCreationTokens": summary.totals.cacheCreationTokens,
                "cacheReadTokens": summary.totals.cacheReadTokens,
                "totalTokens": summary.totals.totalTokens,
                "models": summary.modelsUsed,
            ]
            if let cost = summary.totals.costUSD {
                entry["costUSD"] = cost
            }
            dailyArray.append(entry)
        }

        if scope == .all || scope == .timeline || scope == .weekly || scope == .utilization {
            root["dailySummaries"] = dailyArray
        }

        if scope == .all || scope == .hourly {
            let hourly = store.ledgerHourlySummary(for: provider).sorted { $0.hourStart < $1.hourStart }
            root["hourlySummaries"] = hourly.map { summary -> [String: Any] in
                var entry: [String: Any] = [
                    "hour": summary.hourKey,
                    "inputTokens": summary.totals.inputTokens,
                    "outputTokens": summary.totals.outputTokens,
                    "cacheCreationTokens": summary.totals.cacheCreationTokens,
                    "cacheReadTokens": summary.totals.cacheReadTokens,
                    "totalTokens": summary.totals.totalTokens,
                    "requestCount": summary.requestCount,
                ]
                if let cost = summary.totals.costUSD {
                    entry["costUSD"] = cost
                }
                return entry
            }
        }

        // Model breakdowns
        let modelBreakdowns = store.ledgerModelBreakdown(for: provider)
        if !modelBreakdowns.isEmpty, scope == .all || scope == .models {
            root["modelBreakdowns"] = modelBreakdowns.map { model -> [String: Any] in
                var entry: [String: Any] = [
                    "model": model.model,
                    "requestCount": model.entryCount,
                    "inputTokens": model.totals.inputTokens,
                    "outputTokens": model.totals.outputTokens,
                    "totalTokens": model.totals.totalTokens,
                ]
                if let cost = model.totals.costUSD {
                    entry["costUSD"] = cost
                }
                entry["projectName"] = RunicProjectDisplay.name(for: model)
                if let projectID = model.projectID {
                    entry["projectID"] = projectID
                }
                return entry
            }
        }

        // Project breakdowns
        let projectBreakdowns = store.ledgerProjectBreakdown(for: provider)
        if !projectBreakdowns.isEmpty, scope == .all || scope == .projects {
            root["projectBreakdowns"] = projectBreakdowns.map { project -> [String: Any] in
                var entry: [String: Any] = [
                    "projectName": RunicProjectDisplay.name(for: project),
                    "requestCount": project.entryCount,
                    "inputTokens": project.totals.inputTokens,
                    "outputTokens": project.totals.outputTokens,
                    "totalTokens": project.totals.totalTokens,
                    "models": project.modelsUsed,
                ]
                if let cost = project.totals.costUSD {
                    entry["costUSD"] = cost
                }
                if let projectID = project.projectID {
                    entry["projectID"] = projectID
                }
                return entry
            }
        }

        if scope == .all || scope == .windows {
            if let snapshot = store.snapshot(for: provider) {
                root["usageWindows"] = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self)
                    .map { window -> [String: Any] in
                        var entry: [String: Any] = [
                            "label": window.label ?? "Usage window",
                            "usedPercent": window.usedPercent,
                        ]
                        if let reset = window.resetDescription {
                            entry["resetDescription"] = reset
                        }
                        if let resetsAt = window.resetsAt {
                            entry["resetsAt"] = dateFormatter.string(from: resetsAt)
                        }
                        return entry
                    }
            }
        }

        // Spend forecast
        if let forecast = store.ledgerSpendForecast(for: provider) {
            root["spendForecast"] = [
                "observedDays": forecast.observedDays,
                "observedCostUSD": forecast.observedCostUSD,
                "averageDailyCostUSD": forecast.averageDailyCostUSD,
                "projected30DayCostUSD": forecast.projected30DayCostUSD,
                "budgetWillBreach": forecast.budgetWillBreach,
            ] as [String: Any]
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]),
            let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    // MARK: - Helpers

    /// Escape a value for CSV, quoting if it contains commas, quotes, or newlines.
    private static func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
