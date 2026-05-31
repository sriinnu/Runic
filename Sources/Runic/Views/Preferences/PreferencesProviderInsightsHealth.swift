import Foundation
import RunicCore

extension ProviderInsightsComposer {
    static func reliabilityValue(_ reliability: UsageLedgerReliabilityScore?) -> String? {
        guard let reliability else { return nil }
        return "\(reliability.grade) · \(reliability.score)/100"
    }

    static func reliabilityHelpText(_ reliability: UsageLedgerReliabilityScore?) -> String? {
        guard let reliability else { return nil }
        var lines = [reliability.summary]
        if let primary = self.trimmed(reliability.primarySignal), !primary.isEmpty {
            lines.append(primary)
        }
        for signal in reliability.signals {
            let trimmed = self.trimmed(signal) ?? ""
            guard !trimmed.isEmpty else { continue }
            if lines.contains(trimmed) { continue }
            lines.append(trimmed)
            if lines.count >= 5 { break }
        }
        return lines.joined(separator: "\n")
    }

    static func costAnomalyValue(_ anomaly: UsageLedgerAnomalySummary?) -> String? {
        guard let spend = anomaly?.spendAnomaly else { return nil }
        let percent = Int((spend.percentIncrease * 100).rounded())
        return "\(spend.severity.label) spend +\(percent)%"
    }

    static func costAnomalyHelpText(_ anomaly: UsageLedgerAnomalySummary?) -> String? {
        guard let anomaly, let spend = anomaly.spendAnomaly else { return nil }
        let percent = Int((spend.percentIncrease * 100).rounded())
        var lines = [
            "Spend today: \(UsageFormatter.usdString(spend.todayValue))",
            "Baseline (\(anomaly.baselineDays)d avg): \(UsageFormatter.usdString(spend.baselineAverage))",
            "Increase: +\(percent)%",
            "Severity: \(spend.severity.label)",
        ]
        if let explanation = anomaly.explanation {
            lines.append(contentsOf: explanation.details.prefix(2))
        }
        return lines.joined(separator: "\n")
    }

    static func fetchHealthValue(_ attempts: [ProviderFetchAttempt]) -> String? {
        guard !attempts.isEmpty else { return nil }
        let rendered = attempts.prefix(3).map { attempt in
            let status = if !attempt.wasAvailable {
                "unavailable"
            } else if self.trimmed(attempt.errorDescription) != nil {
                "failed"
            } else {
                "ok"
            }
            return "\(self.fetchStrategyLabel(attempt)) \(status)"
        }
        var value = rendered.joined(separator: " · ")
        if attempts.count > 3 {
            value += " +\(attempts.count - 3) more"
        }
        return value
    }

    static func fetchErrorValue(_ attempts: [ProviderFetchAttempt]) -> String? {
        guard let latestError = attempts.reversed().compactMap({ self.trimmed($0.errorDescription) }).first else {
            return nil
        }
        return self.truncated(latestError, maxLength: 88)
    }

    static func fetchAttemptsHelp(_ attempts: [ProviderFetchAttempt]) -> String? {
        guard !attempts.isEmpty else { return nil }
        return attempts.map { attempt in
            let status: String
            if !attempt.wasAvailable {
                status = "unavailable"
            } else if let error = self.trimmed(attempt.errorDescription) {
                return "\(attempt.strategyID) (\(self.fetchKindLabel(attempt.kind))) failed: \(error)"
            } else {
                status = "ok"
            }
            return "\(attempt.strategyID) (\(self.fetchKindLabel(attempt.kind))) \(status)"
        }.joined(separator: "\n")
    }

    static func fetchStrategyLabel(_ attempt: ProviderFetchAttempt) -> String {
        let raw = attempt.strategyID
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let cleaned = UsageFormatter.cleanPlanName(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            return cleaned
        }
        return self.fetchKindLabel(attempt.kind)
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

    static func truncated(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return "\(text[..<index])…"
    }

    static func windowModelsValue(_ snapshot: UsageSnapshot?) -> String? {
        guard let snapshot else { return nil }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self)
        guard !windows.isEmpty else { return nil }

        var seen: Set<String> = []
        var items: [String] = []
        for window in windows {
            guard let rawLabel = self.trimmed(window.label) else { continue }
            let normalized = rawLabel.lowercased()
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)

            let label = UsageFormatter.modelDisplayName(rawLabel)
            let used = Int(window.usedPercent.rounded())
            items.append("\(label) \(used)%")
        }
        guard !items.isEmpty else { return nil }
        if items.count > 3 {
            let visible = items.prefix(3).joined(separator: " · ")
            return "\(visible) +\(items.count - 3) more"
        }
        return items.joined(separator: " · ")
    }
}
