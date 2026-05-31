import Foundation
import RunicCore
import SwiftUI

extension ProviderSidebarDetailView {
    struct ProjectDisplay {
        let title: String
        let helpText: String?
    }

    func projectDisplay(_ summary: UsageLedgerProjectSummary) -> ProjectDisplay {
        let displayName = RunicProjectDisplay.name(for: summary)
        let source = summary.projectNameSource ?? .unknown
        let confidence = summary.projectNameConfidence ?? .none
        let shouldAnnotateSource = source != .projectName && source != .budgetOverride
        let shouldAnnotateConfidence = confidence != .high
        let isUnknown = RunicProjectDisplay.isUnattributed(displayName)

        var details: [String] = []
        if shouldAnnotateSource {
            details.append("source: \(self.projectSourceLabel(source))")
        }
        if shouldAnnotateConfidence {
            details.append("confidence: \(self.projectConfidenceLabel(confidence))")
        }
        if isUnknown, let fingerprint = self.projectIDFingerprint(summary.projectID) {
            details.append("id: \(fingerprint)")
        }
        if let provenance = self.trimmed(summary.projectNameProvenance) {
            details.append("via: \(provenance)")
        }
        return ProjectDisplay(
            title: displayName,
            helpText: details.isEmpty ? nil : details.joined(separator: "\n"))
    }

    func projectSourceLabel(_ source: UsageLedgerProjectNameSource) -> String {
        switch source {
        case .projectName: "project name"
        case .projectID: "project id"
        case .inferredFromPath: "path-derived"
        case .inferredFromName: "name-derived"
        case .budgetOverride: "budget override"
        case .unknown: "unknown"
        }
    }

    func projectConfidenceLabel(_ confidence: UsageLedgerProjectNameConfidence) -> String {
        switch confidence {
        case .high: "high"
        case .medium: "medium"
        case .low: "low"
        case .none: "none"
        }
    }

    func projectIDFingerprint(_ projectID: String?) -> String? {
        guard let projectID = projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !projectID.isEmpty else {
            return nil
        }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in projectID.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01B3
        }
        return String(format: "%08llx", hash)
    }

    @ViewBuilder
    func fieldActions(_ actions: [ProviderSettingsActionDescriptor]) -> some View {
        let visible = actions.filter { $0.isVisible?() ?? true }
        if !visible.isEmpty {
            HStack(spacing: RunicSpacing.xs) {
                ForEach(visible) { action in
                    Button(action.title) {
                        Task { @MainActor in await action.perform() }
                    }
                    .applyProviderSettingsButtonStyle(action.style)
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    func toggleActions(_ actions: [ProviderSettingsActionDescriptor]) -> some View {
        let visible = actions.filter { $0.isVisible?() ?? true }
        if !visible.isEmpty {
            HStack(spacing: RunicSpacing.xs) {
                ForEach(visible) { action in
                    Button(action.title) {
                        Task { @MainActor in await action.perform() }
                    }
                    .applyProviderSettingsButtonStyle(action.style)
                    .controlSize(.small)
                }
            }
        }
    }

    struct QuickMetricItem: Identifiable {
        let id: String
        let title: String
        let value: String
        let helpText: String?
    }

    var quickMetrics: [QuickMetricItem] {
        var items: [QuickMetricItem] = []
        let snapshot = self.store.snapshot(for: self.provider)
        let tokenSnapshot = self.store.tokenSnapshot(for: self.provider)
        let hasModelBreakdown = self.hasModelBreakdown
        let hasProjectAttribution = self.hasProjectAttribution

        if let today = self
            .tokenWindowValue(tokens: tokenSnapshot?.sessionTokens, cost: tokenSnapshot?.sessionCostUSD)
        {
            items.append(QuickMetricItem(
                id: "today",
                title: "Today",
                value: today,
                helpText: "Session cost and tokens."))
        }
        if let last30 = self.tokenWindowValue(
            tokens: tokenSnapshot?.last30DaysTokens,
            cost: tokenSnapshot?.last30DaysCostUSD)
        {
            items.append(QuickMetricItem(
                id: "30d",
                title: "30d",
                value: last30,
                helpText: "Last 30 days cost and tokens."))
        }
        if let spend = self.providerSpendValue(snapshot?.providerCost) {
            items.append(QuickMetricItem(
                id: "spend",
                title: "Spend",
                value: spend,
                helpText: "Provider billing usage."))
        }
        if hasModelBreakdown, let topModel = self.store.ledgerTopModel(for: self.provider) {
            let modelName = UsageFormatter.modelDisplayName(topModel.model)
            var value = self.modelLineValue(
                title: modelName,
                totals: topModel.totals,
                requests: topModel.entryCount)
            if let context = UsageFormatter.modelContextLabel(for: topModel.model) {
                value += " · \(context)"
            }
            items.append(QuickMetricItem(
                id: "top-model",
                title: "Top model",
                value: value,
                helpText: "Highest token usage model in the active insights window."))
        } else if !hasModelBreakdown, let windowModel = self.topWindowModel {
            let modelName = UsageFormatter.modelDisplayName(windowModel.label)
            let used = Int(windowModel.window.usedPercent.rounded())
            items.append(QuickMetricItem(
                id: "top-model-window",
                title: hasModelBreakdown ? "Top model" : "Top window",
                value: "\(modelName) · \(used)% used",
                helpText: hasModelBreakdown ?
                    "Most constrained model/category from live quota windows."
                    : "Top quota window from live fetch response."))
        }
        if hasProjectAttribution, let topProject = self.store.ledgerTopProject(for: self.provider) {
            let project = self.projectDisplay(topProject)
            let value = self.topProjectSummaryValue(topProject)
            items.append(QuickMetricItem(
                id: "top-project",
                title: "Top project",
                value: "\(project.title) · \(value)",
                helpText: "Highest token usage project in the active insights window."))
        }
        if let coverage = ProviderInsightsComposer.coverageSummaryLabel(for: self.provider, store: self.store) {
            let value = coverage.replacingOccurrences(of: "usage: ", with: "")
            items.append(QuickMetricItem(
                id: "coverage",
                title: "Data",
                value: value,
                helpText: "Provider coverage for model-level usage, token metrics, and project attribution."))
        }
        return items
    }

    func tokenWindowValue(tokens: Int?, cost: Double?) -> String? {
        var parts: [String] = []
        if let cost, cost.isFinite, cost >= 0 {
            parts.append(UsageFormatter.usdString(cost))
        }
        if let tokens, tokens >= 0 {
            parts.append("\(UsageFormatter.tokenCountString(tokens)) tok")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    func providerSpendValue(_ providerCost: ProviderCostSnapshot?) -> String? {
        guard let providerCost else { return nil }
        let used = UsageFormatter.currencyString(providerCost.used, currencyCode: providerCost.currencyCode)
        if providerCost.limit > 0 {
            let limitText = UsageFormatter.currencyString(providerCost.limit, currencyCode: providerCost.currencyCode)
            return "\(used) / \(limitText)"
        }
        return used
    }

    var topModelLines: [String] {
        let ranked = self.store.ledgerModelBreakdown(for: self.provider).sorted { lhs, rhs in
            if lhs.totals.totalTokens == rhs.totals.totalTokens {
                return UsageFormatter.modelDisplayName(lhs.model) < UsageFormatter.modelDisplayName(rhs.model)
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        if !ranked.isEmpty {
            guard self.hasModelBreakdown else {
                return []
            }
            return ranked.prefix(3).map { summary in
                let name = UsageFormatter.modelDisplayName(summary.model)
                return self.usageLine(
                    title: name,
                    totals: summary.totals,
                    requests: summary.entryCount,
                    model: summary.model)
            }
        }
        guard !self.hasModelBreakdown else {
            return []
        }
        return self.windowModelLines
    }

    var modelSectionTitle: String {
        self.hasModelBreakdown ? "Models" : "Quota windows"
    }

    var effectiveUsageCoverage: ProviderUsageCoverage {
        ProviderInsightsComposer.effectiveCoverage(for: self.provider, store: self.store)
    }

    var hasModelBreakdown: Bool {
        self.effectiveUsageCoverage.supportsModelBreakdown
    }

    var hasProjectAttribution: Bool {
        self.effectiveUsageCoverage.supportsProjectAttribution
    }

    var topProjectLines: [String] {
        guard self.hasProjectAttribution else {
            return []
        }
        let ranked = self.store.ledgerProjectBreakdown(for: self.provider).sorted { lhs, rhs in
            if lhs.totals.totalTokens == rhs.totals.totalTokens {
                return RunicProjectDisplay.name(for: lhs) < RunicProjectDisplay.name(for: rhs)
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        return ranked.prefix(3).map { summary in
            let project = RunicProjectDisplay.name(for: summary)
            return self.usageLine(title: project, totals: summary.totals, requests: summary.entryCount)
        }
    }

    func usageLine(
        title: String,
        totals: UsageLedgerTotals,
        requests: Int,
        model: String? = nil) -> String
    {
        let tokens = UsageFormatter.tokenSummaryString(totals)
        var parts = ["\(title)", "\(tokens)", "\(requests) req"]
        if let cost = totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: totals.totalTokens) {
                parts.append("~\(per1K)")
            }
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: requests) {
                parts.append("~\(perReq)")
            }
        }
        if let model, let context = UsageFormatter.modelContextLabel(for: model) {
            parts.append(context)
        }
        return parts.joined(separator: " · ")
    }

    func topProjectSummaryValue(_ summary: UsageLedgerProjectSummary) -> String {
        var parts: [String] = []
        parts.append(UsageFormatter.tokenSummaryString(summary.totals))
        parts.append("\(summary.entryCount) req")
        if let cost = summary.totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: summary.entryCount) {
                parts.append("~\(perReq)")
            }
        }
        return parts.joined(separator: " · ")
    }

    func modelLineValue(title: String, totals: UsageLedgerTotals, requests: Int) -> String {
        var parts: [String] = [title]
        parts.append(UsageFormatter.tokenSummaryString(totals))
        parts.append("\(requests) req")
        if let cost = totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: totals.totalTokens) {
                parts.append("~\(per1K)")
            }
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: requests) {
                parts.append("~\(perReq)")
            }
        }
        return parts.joined(separator: " · ")
    }

    var windowModelLines: [String] {
        self.labeledQuotaWindows(from: self.store.snapshot(for: self.provider)).prefix(3).map { item in
            let modelName = UsageFormatter.modelDisplayName(item.label)
            let used = Int(item.window.usedPercent.rounded())
            let remaining = Int(item.window.remainingPercent.rounded())
            var parts = [modelName, "\(used)% used", "\(remaining)% left"]
            if let resetsAt = item.window.resetsAt {
                parts.append("reset \(UsageFormatter.resetCountdownDescription(from: resetsAt))")
            } else if let resetDescription = item.window.resetDescription?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !resetDescription.isEmpty
            {
                parts.append(resetDescription)
            }
            return parts.joined(separator: " · ")
        }
    }

    var topWindowModel: (label: String, window: RateWindow)? {
        self.labeledQuotaWindows(from: self.store.snapshot(for: self.provider)).first
    }

    func labeledQuotaWindows(from snapshot: UsageSnapshot?) -> [(label: String, window: RateWindow)] {
        guard let snapshot else { return [] }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self)
        var seen: Set<String> = []
        var labeled: [(label: String, window: RateWindow)] = []

        for window in windows {
            guard let label = window.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty
            else {
                continue
            }
            let normalized = label.lowercased()
            guard seen.insert(normalized).inserted else { continue }
            labeled.append((label, window))
        }

        return labeled.sorted { lhs, rhs in
            if lhs.window.usedPercent == rhs.window.usedPercent {
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
            return lhs.window.usedPercent > rhs.window.usedPercent
        }
    }

    func decimalString(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }


}
