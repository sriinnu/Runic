import Foundation
import RunicCore

extension UsageExporter {
    static func exportCSV(store: UsageStore, provider: UsageProvider, scope: Scope) -> String {
        switch scope {
        case .all:
            self.exportDailyCSV(store: store, provider: provider)
        case .timeline:
            self.exportLedgerDailyCSV(store: store, provider: provider, days: nil)
        case .timeline3d:
            self.exportLedgerDailyCSV(store: store, provider: provider, days: 3)
        case .timeline7d:
            self.exportLedgerDailyCSV(store: store, provider: provider, days: 7)
        case .timeline30d:
            self.exportLedgerDailyCSV(store: store, provider: provider, days: 30)
        case .timeline90d:
            self.exportLedgerDailyCSV(store: store, provider: provider, days: 90)
        case .timeline1y:
            self.exportLedgerDailyCSV(store: store, provider: provider, days: 365)
        case .hourly:
            self.exportHourlyCSV(store: store, provider: provider)
        case .weekly:
            self.exportLedgerDailyCSV(store: store, provider: provider, days: 7)
        case .utilization:
            self.exportUtilizationCSV(store: store, provider: provider)
        case .windows:
            self.exportWindowsCSV(store: store, provider: provider)
        case .projects:
            self.exportProjectsCSV(store: store, provider: provider)
        case .models:
            self.exportModelsCSV(store: store, provider: provider)
        }
    }

    private static func exportDailyCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines: [String] = []

        lines.append(Self.csvRow([
            "date",
            "input_tokens",
            "output_tokens",
            "cache_creation_tokens",
            "cache_read_tokens",
            "total_tokens",
            "cost_usd",
            "models_used",
            "token_provenance",
            "cost_provenance",
        ]))

        let daily = store.tokenSnapshot(for: provider)?.daily ?? []

        for day in daily {
            let costStr = day.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let modelsStr = Self.csvEscape((day.modelsUsed ?? []).joined(separator: "; "))
            let input = day.inputTokens ?? 0
            let output = day.outputTokens ?? 0
            let cacheCreate = day.cacheCreationTokens ?? 0
            let cacheRead = day.cacheReadTokens ?? 0
            let total = day.totalTokens ?? (input + output + cacheCreate + cacheRead)
            lines.append(Self.csvRow([
                day.date,
                "\(input)",
                "\(output)",
                "\(cacheCreate)",
                "\(cacheRead)",
                "\(total)",
                costStr,
                modelsStr,
                "",
                "",
            ]))
        }

        if daily.isEmpty, let summary = store.ledgerDailySummary(for: provider) {
            let costStr = summary.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let modelsStr = Self.csvEscape(summary.modelsUsed.joined(separator: "; "))
            lines.append(Self.dailySummaryCSVRow(summary, costStr: costStr, modelsStr: modelsStr))
        }

        return lines.joined(separator: "\n")
    }

    private static func exportLedgerDailyCSV(store: UsageStore, provider: UsageProvider, days: Int?) -> String {
        var lines = [Self.csvRow([
            "date",
            "input_tokens",
            "output_tokens",
            "cache_creation_tokens",
            "cache_read_tokens",
            "total_tokens",
            "cost_usd",
            "models_used",
            "token_provenance",
            "cost_provenance",
        ])]
        let summaries = self.filteredLedgerDailySummaries(store: store, provider: provider, days: days)
        for summary in summaries {
            let costStr = summary.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let modelsStr = Self.csvEscape(summary.modelsUsed.joined(separator: "; "))
            lines.append(Self.dailySummaryCSVRow(summary, costStr: costStr, modelsStr: modelsStr))
        }
        return lines.joined(separator: "\n")
    }

    private static func exportHourlyCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines = [Self.csvRow([
            "hour",
            "input_tokens",
            "output_tokens",
            "cache_creation_tokens",
            "cache_read_tokens",
            "total_tokens",
            "cost_usd",
            "requests",
            "token_provenance",
            "cost_provenance",
        ])]
        let summaries = store.ledgerHourlySummary(for: provider).sorted { $0.hourStart < $1.hourStart }
        for summary in summaries {
            let costStr = summary.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            lines.append(Self.csvRow([
                summary.hourKey,
                "\(summary.totals.inputTokens)",
                "\(summary.totals.outputTokens)",
                "\(summary.totals.cacheCreationTokens)",
                "\(summary.totals.cacheReadTokens)",
                "\(summary.totals.totalTokens)",
                costStr,
                "\(summary.requestCount)",
                Self.provenanceText(summary.totals.tokenProvenance),
                Self.provenanceText(summary.totals.costProvenance),
            ]))
        }
        return lines.joined(separator: "\n")
    }

    private static func exportProjectsCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines = [Self.csvRow([
            "project_name",
            "project_id",
            "input_tokens",
            "output_tokens",
            "cache_creation_tokens",
            "cache_read_tokens",
            "total_tokens",
            "cost_usd",
            "requests",
            "models_used",
            "token_provenance",
            "cost_provenance",
        ])]
        for project in store.ledgerProjectBreakdown(for: provider) {
            let costStr = project.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let name = Self.csvEscape(RunicProjectDisplay.name(for: project))
            let id = Self.csvEscape(project.projectID ?? "")
            let models = Self.csvEscape(project.modelsUsed.joined(separator: "; "))
            lines.append(Self.csvRow([
                name,
                id,
                "\(project.totals.inputTokens)",
                "\(project.totals.outputTokens)",
                "\(project.totals.cacheCreationTokens)",
                "\(project.totals.cacheReadTokens)",
                "\(project.totals.totalTokens)",
                costStr,
                "\(project.entryCount)",
                models,
                Self.provenanceText(project.totals.tokenProvenance),
                Self.provenanceText(project.totals.costProvenance),
            ]))
        }
        return lines.joined(separator: "\n")
    }

    private static func exportModelsCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines = [Self.csvRow([
            "model",
            "project_name",
            "project_id",
            "input_tokens",
            "output_tokens",
            "cache_creation_tokens",
            "cache_read_tokens",
            "total_tokens",
            "cost_usd",
            "requests",
            "token_provenance",
            "cost_provenance",
        ])]
        for model in store.ledgerModelBreakdown(for: provider) {
            let costStr = model.totals.costUSD.map { String(format: "%.4f", $0) } ?? ""
            let projectName = Self.csvEscape(RunicProjectDisplay.name(for: model))
            let projectID = Self.csvEscape(model.projectID ?? "")
            lines.append(Self.csvRow([
                Self.csvEscape(model.model),
                projectName,
                projectID,
                "\(model.totals.inputTokens)",
                "\(model.totals.outputTokens)",
                "\(model.totals.cacheCreationTokens)",
                "\(model.totals.cacheReadTokens)",
                "\(model.totals.totalTokens)",
                costStr,
                "\(model.entryCount)",
                Self.provenanceText(model.totals.tokenProvenance),
                Self.provenanceText(model.totals.costProvenance),
            ]))
        }
        return lines.joined(separator: "\n")
    }

    private static func exportUtilizationCSV(store: UsageStore, provider: UsageProvider) -> String {
        var lines = ["date,total_tokens,current_used_percent,estimated_used_percent"]
        // Windows without a real limit have placeholder percents; export empty
        // cells instead of a fake 0.00.
        let primary = store.snapshot(for: provider)?.primary
        let currentUsedPercent: Double? = primary?.hasKnownLimit == false ? nil : primary?.usedPercent ?? 0
        let todayTokens = store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0
        let scaleFactor = todayTokens > 0 ? (currentUsedPercent ?? 0) / Double(todayTokens) : 0
        for summary in store.ledgerAllDailySummary(for: provider).sorted(by: { $0.dayStart < $1.dayStart }) {
            let estimated = min(100, Double(summary.totals.totalTokens) * scaleFactor)
            lines.append(Self.csvRow([
                summary.dayKey,
                "\(summary.totals.totalTokens)",
                currentUsedPercent.map { String(format: "%.2f", $0) } ?? "",
                currentUsedPercent != nil ? String(format: "%.2f", estimated) : "",
            ]))
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
            // Empty percent cell for windows without a real limit.
            let percent = window.hasKnownLimit == false ? "" : String(format: "%.2f", window.usedPercent)
            lines.append("\(label),\(percent),\(reset),\(resetsAt)")
        }
        return lines.joined(separator: "\n")
    }

    /// Escape a value for CSV, quoting if it contains commas, quotes, or newlines.
    private static func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    private static func csvRow(_ values: [String]) -> String {
        values.joined(separator: ",")
    }

    private static func dailySummaryCSVRow(
        _ summary: UsageLedgerDailySummary,
        costStr: String,
        modelsStr: String) -> String
    {
        self.csvRow([
            summary.dayKey,
            "\(summary.totals.inputTokens)",
            "\(summary.totals.outputTokens)",
            "\(summary.totals.cacheCreationTokens)",
            "\(summary.totals.cacheReadTokens)",
            "\(summary.totals.totalTokens)",
            costStr,
            modelsStr,
            self.provenanceText(summary.totals.tokenProvenance),
            self.provenanceText(summary.totals.costProvenance),
        ])
    }

    private static func provenanceText(_ provenance: MetricProvenance?) -> String {
        self.csvEscape(provenance?.displayText ?? "")
    }
}
