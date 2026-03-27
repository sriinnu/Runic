import Foundation
import RunicCore

/// Exports usage data from the ledger as CSV or JSON.
@MainActor
enum UsageExporter {
    enum Format: String {
        case csv
        case json
    }

    /// Build an export string for the given provider in the requested format.
    static func export(store: UsageStore, provider: UsageProvider, format: Format) -> String {
        switch format {
        case .csv:
            self.exportCSV(store: store, provider: provider)
        case .json:
            self.exportJSON(store: store, provider: provider)
        }
    }

    // MARK: - CSV

    private static func exportCSV(store: UsageStore, provider: UsageProvider) -> String {
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

    // MARK: - JSON

    private static func exportJSON(store: UsageStore, provider: UsageProvider) -> String {
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

        root["dailySummaries"] = dailyArray

        // Model breakdowns
        let modelBreakdowns = store.ledgerModelBreakdown(for: provider)
        if !modelBreakdowns.isEmpty {
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
                if let projectName = model.projectName {
                    entry["projectName"] = projectName
                }
                if let projectID = model.projectID {
                    entry["projectID"] = projectID
                }
                return entry
            }
        }

        // Project breakdowns
        let projectBreakdowns = store.ledgerProjectBreakdown(for: provider)
        if !projectBreakdowns.isEmpty {
            root["projectBreakdowns"] = projectBreakdowns.map { project -> [String: Any] in
                var entry: [String: Any] = [
                    "projectName": project.displayProjectName,
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
