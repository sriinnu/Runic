import AppKit
import Foundation
import RunicCore

extension ProviderSidebarDetailView {
    struct RuntimeMetricsData {
        let lineText: String
        let hoverText: String?
    }

    var runtimeMetrics: RuntimeMetricsData? {
        let attempts = self.store.fetchAttempts(for: self.provider)
        guard !attempts.isEmpty || self.store.snapshot(for: self.provider) != nil else {
            return nil
        }

        var parts: [String] = []
        if let updatedAt = self.store.snapshot(for: self.provider)?.updatedAt {
            parts.append("success \(updatedAt.relativeDescription())")
        } else {
            parts.append("no success yet")
        }

        var hoverText: String?
        if !attempts.isEmpty {
            let retryCount = self.retryCount(from: attempts)
            if retryCount > 0 {
                parts.append("retry \(retryCount)")
            }
            if let activeAttempt = self.activeAttempt(from: attempts) {
                parts.append(Self.fetchKindLabel(activeAttempt.kind))
                if let strategyID = self.trimmed(activeAttempt.strategyID) {
                    hoverText = "Strategy: \(strategyID)"
                }
            }
        }

        return RuntimeMetricsData(
            lineText: parts.joined(separator: " · "),
            hoverText: hoverText)
    }

    func retryCount(from attempts: [ProviderFetchAttempt]) -> Int {
        guard !attempts.isEmpty else { return 0 }
        if let successIndex = attempts
            .firstIndex(where: { $0.wasAvailable && self.trimmed($0.errorDescription) == nil })
        {
            return max(0, successIndex)
        }
        return max(0, attempts.count - 1)
    }

    func activeAttempt(from attempts: [ProviderFetchAttempt]) -> ProviderFetchAttempt? {
        guard !attempts.isEmpty else { return nil }
        return attempts.first(where: { $0.wasAvailable && self.trimmed($0.errorDescription) == nil }) ??
            attempts.last(where: { $0.wasAvailable }) ??
            attempts.last
    }

    func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func fetchKindLabel(_ kind: ProviderFetchKind) -> String {
        switch kind {
        case .cli: "cli"
        case .web: "web"
        case .oauth: "oauth"
        case .apiToken: "api"
        case .api: "api"
        case .localProbe: "local"
        case .webDashboard: "web"
        }
    }

    func copyDiagnostics() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(self.diagnosticsReport, forType: .string)
        self.diagnosticsCopyStatus = "Copied"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.diagnosticsCopyStatus = nil
        }
    }

    var diagnosticsReport: String {
        let metadata = self.store.metadata(for: self.provider)
        let attempts = self.store.fetchAttempts(for: self.provider)
        let snapshot = self.store.snapshot(for: self.provider)
        let forecast = self.store.ledgerSpendForecast(for: self.provider)
        let topProjectForecast = self.store.ledgerTopProjectSpendForecast(for: self.provider)
        let reliability = self.store.ledgerReliabilityScore(for: self.provider)
        let anomaly = self.store.ledgerAnomalySummary(for: self.provider)
        let iso = ISO8601DateFormatter()

        var lines: [String] = []
        lines.append("# \(metadata.displayName) Diagnostics")
        lines.append("provider: \(self.provider.rawValue)")
        lines.append("generated_at: \(iso.string(from: Date()))")
        lines.append("enabled: \(self.isEnabled ? "true" : "false")")
        lines.append("source: \(self.sourceLabel)")
        lines.append("updated: \(self.statusLabel)")
        if let runtime = self.runtimeMetrics?.lineText {
            lines.append("runtime: \(runtime)")
        }

        if let snapshot {
            lines.append("")
            lines.append("usage_snapshot:")
            lines.append("- updated_at: \(iso.string(from: snapshot.updatedAt))")
            lines.append("- primary_used_percent: \(Int(snapshot.primary.usedPercent.rounded()))")
            if let minutes = snapshot.primary.windowMinutes, minutes > 0 {
                lines.append("- primary_window_minutes: \(minutes)")
            }
            if let reset = snapshot.primary.resetsAt {
                lines.append("- primary_resets_at: \(iso.string(from: reset))")
            }
            if let cost = snapshot.providerCost {
                let used = UsageFormatter.currencyString(cost.used, currencyCode: cost.currencyCode)
                lines.append("- provider_spend_used: \(used)")
                if cost.limit > 0 {
                    let limit = UsageFormatter.currencyString(cost.limit, currencyCode: cost.currencyCode)
                    lines.append("- provider_spend_limit: \(limit)")
                }
                if let period = self.trimmed(cost.period) {
                    lines.append("- provider_spend_period: \(period)")
                }
            }
        }

        lines.append("")
        lines.append("fetch_path:")
        if attempts.isEmpty {
            lines.append("- none")
        } else {
            for attempt in attempts {
                let state = if !attempt.wasAvailable {
                    "unavailable"
                } else if let error = self.trimmed(attempt.errorDescription) {
                    "failed: \(error)"
                } else {
                    "ok"
                }
                lines.append("- \(attempt.strategyID) [\(Self.fetchKindLabel(attempt.kind))] \(state)")
            }
        }

        if let forecast {
            lines.append("")
            lines.append("provider_forecast:")
            lines.append("- projected_30d: \(UsageFormatter.usdString(forecast.projected30DayCostUSD))")
            lines.append("- average_daily: \(UsageFormatter.usdString(forecast.averageDailyCostUSD))")
            if let p50 = forecast.projectedCostP50USD {
                lines.append("- p50: \(UsageFormatter.usdString(p50))")
            }
            if let p80 = forecast.projectedCostP80USD {
                lines.append("- p80: \(UsageFormatter.usdString(p80))")
            }
            if let p95 = forecast.projectedCostP95USD {
                lines.append("- p95: \(UsageFormatter.usdString(p95))")
            }
            if let limit = forecast.budgetLimitUSD, limit > 0 {
                lines.append("- budget_limit: \(UsageFormatter.usdString(limit))")
                lines.append("- budget_status: \(self.budgetStatusText(forecast))")
            }
        }

        if let topProjectForecast {
            lines.append("")
            lines.append("top_project_forecast:")
            if let name = self.trimmed(topProjectForecast.projectName) {
                lines.append("- project: \(name)")
            }
            lines.append("- projected_30d: \(UsageFormatter.usdString(topProjectForecast.projected30DayCostUSD))")
            if let limit = topProjectForecast.budgetLimitUSD, limit > 0 {
                lines.append("- budget_limit: \(UsageFormatter.usdString(limit))")
                lines.append("- budget_status: \(self.budgetStatusText(topProjectForecast))")
            }
        }

        if let reliability {
            lines.append("")
            lines.append("reliability:")
            lines.append("- score: \(reliability.score)/100")
            lines.append("- grade: \(reliability.grade)")
            lines.append("- summary: \(reliability.summary)")
            if let signal = self.trimmed(reliability.primarySignal) {
                lines.append("- signal: \(signal)")
            }
        }

        if let anomaly {
            lines.append("")
            lines.append("anomaly:")
            if let spend = anomaly.spendAnomaly {
                lines.append("- spend: \(spend.severity.label) +\(Int((spend.percentIncrease * 100).rounded()))%")
            }
            if let token = anomaly.tokenAnomaly {
                lines.append("- tokens: \(token.severity.label) +\(Int((token.percentIncrease * 100).rounded()))%")
            }
            if let explanation = anomaly.explanation {
                lines.append("- headline: \(explanation.headline)")
                for detail in explanation.details {
                    lines.append("- detail: \(detail)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    func budgetStatusText(_ forecast: UsageLedgerSpendForecast) -> String {
        if let eta = forecast.budgetETAInDays {
            return self.budgetBreachETAText(days: eta)
        }
        if forecast.budgetWillBreach {
            return "Breach risk"
        }
        return "On track"
    }

    func budgetBreachETAText(days: Double) -> String {
        guard days.isFinite else { return "Breach ETA unavailable" }
        if days <= 0 { return "Breach now" }
        let now = Date()
        let etaDate = now.addingTimeInterval(days * 24 * 60 * 60)
        let countdown = UsageFormatter.resetCountdownDescription(from: etaDate, now: now)
        if countdown == "now" { return "Breach now" }
        return "Breach \(countdown)"
    }
}
