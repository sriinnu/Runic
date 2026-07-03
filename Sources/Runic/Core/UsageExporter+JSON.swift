import Foundation
import RunicCore

extension UsageExporter {
    static func exportJSON(store: UsageStore, provider: UsageProvider, scope: Scope) -> String {
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
        if let days = scope.timelineDays {
            root["timeRangeDays"] = days
        }

        let dailyArray = self.dailySummariesJSON(store: store, provider: provider, scope: scope)

        if scope.includesDailySummaries {
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
                Self.addProvenance(to: &entry, totals: summary.totals)
                return entry
            }
        }

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
                Self.addProvenance(to: &entry, totals: model.totals)
                entry["projectName"] = RunicProjectDisplay.name(for: model)
                if let projectID = model.projectID {
                    entry["projectID"] = projectID
                }
                return entry
            }
        }

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
                Self.addProvenance(to: &entry, totals: project.totals)
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
                        // Windows without a real limit export a null percent so
                        // consumers can't mistake the placeholder for 0% used.
                        var entry: [String: Any] = [
                            "label": window.label ?? "Usage window",
                            "usedPercent": window.hasKnownLimit == false ? NSNull() : window.usedPercent,
                        ]
                        if let hasKnownLimit = window.hasKnownLimit {
                            entry["hasKnownLimit"] = hasKnownLimit
                        }
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

        if let compaction = store.ledgerCompactionSummary(for: provider), scope == .all {
            var entry: [String: Any] = [
                "eventCount": compaction.eventCount,
                "inputTokens": compaction.totals.inputTokens,
                "outputTokens": compaction.totals.outputTokens,
                "cacheCreationTokens": compaction.totals.cacheCreationTokens,
                "cacheReadTokens": compaction.totals.cacheReadTokens,
                "totalTokens": compaction.totals.totalTokens,
                "lastEventAt": dateFormatter.string(from: compaction.lastEventAt),
            ]
            if let cost = compaction.totals.costUSD {
                entry["costUSD"] = cost
            }
            Self.addProvenance(to: &entry, totals: compaction.totals)
            root["compactionTax"] = entry
        }

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

    private static func dailySummariesJSON(
        store: UsageStore,
        provider: UsageProvider,
        scope: Scope) -> [[String: Any]]
    {
        let ledgerSummaries = self.filteredLedgerDailySummaries(
            store: store,
            provider: provider,
            days: scope.timelineDays)
        if !ledgerSummaries.isEmpty {
            return ledgerSummaries.map { summary -> [String: Any] in
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
                Self.addProvenance(to: &entry, totals: summary.totals)
                return entry
            }
        }

        guard scope.timelineDays == nil else { return [] }

        let daily = store.tokenSnapshot(for: provider)?.daily ?? []
        var dailyArray: [[String: Any]] = []
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
            Self.addProvenance(to: &entry, totals: summary.totals)
            dailyArray.append(entry)
        }

        return dailyArray
    }

    private static func addProvenance(to entry: inout [String: Any], totals: UsageLedgerTotals) {
        if let tokenProvenance = totals.tokenProvenance {
            entry["tokenProvenance"] = self.provenanceJSON(tokenProvenance)
        }
        if let costProvenance = totals.costProvenance {
            entry["costProvenance"] = Self.provenanceJSON(costProvenance)
        }
    }

    private static func provenanceJSON(_ provenance: MetricProvenance) -> [String: String] {
        var object: [String: String] = [
            "confidence": provenance.confidence.rawValue,
            "source": provenance.source.rawValue,
            "display": provenance.displayText,
        ]
        if let detail = provenance.detail {
            object["detail"] = detail
        }
        return object
    }
}

extension UsageExporter.Scope {
    fileprivate var timelineDays: Int? {
        switch self {
        case .timeline3d: 3
        case .timeline7d, .weekly: 7
        case .timeline30d: 30
        case .timeline90d: 90
        case .timeline1y: 365
        default: nil
        }
    }

    fileprivate var includesDailySummaries: Bool {
        switch self {
        case .all, .timeline, .timeline3d, .timeline7d, .timeline30d, .timeline90d, .timeline1y, .weekly,
             .utilization:
            true
        case .hourly, .windows, .projects, .models:
            false
        }
    }
}
