import AppKit
import RunicCore

// MARK: - Ledger insights submenu

private struct LedgerInsightsSubmenuData {
    let daily: UsageLedgerDailySummary?
    let activeBlock: UsageLedgerBlockSummary?
    let modelBreakdown: [UsageLedgerModelSummary]
    let projectBreakdown: [UsageLedgerProjectSummary]
    let reliability: UsageLedgerReliabilityScore?
    let routing: UsageLedgerRoutingRecommendation?

    var hasContent: Bool {
        self.daily != nil ||
            self.activeBlock?.isActive == true ||
            !self.modelBreakdown.isEmpty ||
            !self.projectBreakdown.isEmpty ||
            self.reliability != nil ||
            self.routing != nil
    }

    func hasOverflow(limit: Int) -> Bool {
        self.modelBreakdown.count > limit || self.projectBreakdown.count > limit
    }
}

extension StatusItemController {
    func makeInsightsSubmenu(provider: UsageProvider) -> NSMenu? {
        let data = self.ledgerInsightsSubmenuData(for: provider)
        guard data.hasContent else { return nil }
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let limit = max(1, self.settings.insightsMenuMaxItems)
        let reportDays = max(1, self.settings.insightsReportDays)

        self.addInsightsTitle(to: submenu)
        self.addDailyInsightsItem(data.daily, to: submenu)
        self.addActiveBlockInsightsItem(data.activeBlock, to: submenu)
        self.addReliabilityInsightsItem(data.reliability, to: submenu)
        self.addRoutingInsightsItem(data.routing, to: submenu)
        self.addModelBreakdownItems(data.modelBreakdown, limit: limit, to: submenu)
        self.addProjectBreakdownItems(data.projectBreakdown, limit: limit, to: submenu)
        self.addOpenInsightsReportItem(
            provider: provider,
            hasOverflow: data.hasOverflow(limit: limit),
            reportDays: reportDays,
            to: submenu)
        return submenu
    }

    private func ledgerInsightsSubmenuData(for provider: UsageProvider) -> LedgerInsightsSubmenuData {
        LedgerInsightsSubmenuData(
            daily: self.store.ledgerDailySummary(for: provider),
            activeBlock: self.store.ledgerActiveBlock(for: provider),
            modelBreakdown: self.store.ledgerModelBreakdown(for: provider)
                .filter { $0.provider == provider },
            projectBreakdown: self.store.ledgerProjectBreakdown(for: provider)
                .filter { $0.provider == provider },
            reliability: self.store.ledgerReliabilityScore(for: provider),
            routing: self.store.ledgerRoutingRecommendation(for: provider))
    }

    private func addInsightsTitle(to submenu: NSMenu) {
        let titleItem = NSMenuItem(title: "Local insights (today)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        submenu.addItem(titleItem)
    }

    private func addDailyInsightsItem(_ daily: UsageLedgerDailySummary?, to submenu: NSMenu) {
        guard let daily else { return }
        let totalTokens = UsageFormatter.tokenCountString(daily.totals.totalTokens)
        let inputTokens = UsageFormatter.tokenCountString(daily.totals.inputTokens)
        let outputTokens = UsageFormatter.tokenCountString(daily.totals.outputTokens)
        var line = "Today: \(totalTokens) tokens · in \(inputTokens) · out \(outputTokens)"
        if let costText = self.costDetailText(for: daily.totals) {
            line += costText
        }
        let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
        item.isEnabled = false
        submenu.addItem(item)
    }

    private func addActiveBlockInsightsItem(_ activeBlock: UsageLedgerBlockSummary?, to submenu: NSMenu) {
        guard let activeBlock, activeBlock.isActive else { return }
        let tokens = UsageFormatter.tokenCountString(activeBlock.totals.totalTokens)
        var line = "Block: \(tokens) tokens · \(activeBlock.entryCount) req"
        if let cost = activeBlock.totals.costUSD {
            line += " · \(UsageFormatter.usdString(cost))"
            if let perRequest = UsageFormatter.usdPerRequestString(
                costUSD: cost,
                requestCount: activeBlock.entryCount)
            {
                line += " · \(perRequest)"
            }
        }
        if let burn = UsageFormatter.usdPerHourFromTokensString(
            costUSD: activeBlock.totals.costUSD,
            tokenCount: activeBlock.totals.totalTokens,
            tokensPerMinute: activeBlock.tokensPerMinute)
        {
            line += " · burn \(burn)"
        }
        let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
        item.isEnabled = false
        submenu.addItem(item)
    }

    private func addReliabilityInsightsItem(
        _ reliability: UsageLedgerReliabilityScore?,
        to submenu: NSMenu)
    {
        guard let reliability else { return }
        let item = NSMenuItem(
            title: "Reliability: \(reliability.score)/100 · \(reliability.grade)",
            action: nil,
            keyEquivalent: "")
        item.isEnabled = false
        submenu.addItem(item)
    }

    private func addRoutingInsightsItem(
        _ routing: UsageLedgerRoutingRecommendation?,
        to submenu: NSMenu)
    {
        guard let routing else { return }
        let from = UsageFormatter.modelDisplayName(routing.fromModel)
        let to = UsageFormatter.modelDisplayName(routing.toModel)
        let savings = UsageFormatter.usdString(routing.estimatedSavingsUSD)
        let item = NSMenuItem(
            title: "Routing: shift \(routing.shiftPercent)% \(from) -> \(to) · save \(savings)",
            action: nil,
            keyEquivalent: "")
        item.isEnabled = false
        submenu.addItem(item)
    }

    private func addModelBreakdownItems(
        _ modelBreakdown: [UsageLedgerModelSummary],
        limit: Int,
        to submenu: NSMenu)
    {
        guard !modelBreakdown.isEmpty else { return }
        self.addDisabledHeader("Models by project", to: submenu)
        for summary in modelBreakdown.prefix(limit) {
            let item = NSMenuItem(title: self.modelBreakdownTitle(summary), action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        }
    }

    private func addProjectBreakdownItems(
        _ projectBreakdown: [UsageLedgerProjectSummary],
        limit: Int,
        to submenu: NSMenu)
    {
        guard !projectBreakdown.isEmpty else { return }
        self.addDisabledHeader("Projects", to: submenu)
        for summary in projectBreakdown.prefix(limit) {
            let item = NSMenuItem(title: self.projectBreakdownTitle(summary), action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        }
    }

    private func addDisabledHeader(_ title: String, to submenu: NSMenu) {
        submenu.addItem(NSMenuItem.separator())
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        submenu.addItem(header)
    }

    private func addOpenInsightsReportItem(
        provider: UsageProvider,
        hasOverflow: Bool,
        reportDays: Int,
        to submenu: NSMenu)
    {
        submenu.addItem(NSMenuItem.separator())
        let reportTitle = hasOverflow
            ? "More… (last \(reportDays) days)"
            : "Open insights report (last \(reportDays) days)…"
        let openItem = NSMenuItem(
            title: reportTitle,
            action: #selector(self.openInsightsReport(_:)),
            keyEquivalent: "")
        openItem.target = self
        openItem.representedObject = provider.rawValue
        submenu.addItem(openItem)
    }

    private func modelBreakdownTitle(_ summary: UsageLedgerModelSummary) -> String {
        let project = self.displayProjectName(
            projectID: summary.projectID,
            projectName: summary.projectName,
            confidence: summary.projectNameConfidence,
            source: summary.projectNameSource,
            provenance: summary.projectNameProvenance,
            includeAttribution: true)
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        let modelName = UsageFormatter.modelDisplayName(summary.model)
        var title = "\(project) · \(modelName): \(tokens) tokens · \(summary.entryCount) req"
        if let context = UsageFormatter.modelContextLabel(for: summary.model) {
            title += " · \(context)"
        }
        if let costDetail = self.costDetailText(for: summary.totals) {
            title += costDetail
        }
        return title
    }

    private func projectBreakdownTitle(_ summary: UsageLedgerProjectSummary) -> String {
        let project = self.displayProjectName(
            projectID: summary.projectID,
            projectName: summary.projectName,
            confidence: summary.projectNameConfidence,
            source: summary.projectNameSource,
            provenance: summary.projectNameProvenance,
            includeAttribution: true)
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        let modelsText = summary.modelsUsed.isEmpty
            ? nil
            : Self.renderedModelsLine(for: summary.modelsUsed)
        var title = "\(project): \(tokens) tokens · \(summary.entryCount) req"
        if let costDetail = self.costDetailText(for: summary.totals) {
            title += costDetail
        }
        if let modelsText { title += " · \(modelsText)" }
        return title
    }

    private func costDetailText(for totals: UsageLedgerTotals) -> String? {
        guard let cost = totals.costUSD else { return nil }
        var text = " · \(UsageFormatter.usdString(cost))"
        if let per1K = UsageFormatter.usdPer1KTokensString(
            costUSD: cost,
            tokenCount: totals.totalTokens)
        {
            text += " · \(per1K)"
        }
        return text
    }

    func displayProjectName(
        projectID: String?,
        projectName: String?,
        confidence: UsageLedgerProjectNameConfidence? = nil,
        source: UsageLedgerProjectNameSource? = nil,
        provenance: String? = nil,
        includeAttribution: Bool = false) -> String
    {
        let trimmedProjectName = projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName: String = if let trimmedProjectName, !trimmedProjectName.isEmpty {
            trimmedProjectName
        } else if let projectID, !projectID.isEmpty {
            if let budgetName = ProjectBudgetStore.getBudget(projectID: projectID)?.projectName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !budgetName.isEmpty
            {
                budgetName
            } else if let fallback = UsageLedgerProjectIdentityResolver.fallbackDisplayName(projectID: projectID) {
                fallback
            } else {
                RunicProjectDisplay.unattributedName
            }
        } else {
            RunicProjectDisplay.unattributedName
        }
        guard includeAttribution else { return displayName }
        guard let annotation = self.projectNameAnnotation(
            displayName: displayName,
            projectID: projectID,
            confidence: confidence,
            source: source,
            provenance: provenance)
        else {
            return displayName
        }
        return "\(displayName) [\(annotation)]"
    }

    private func projectNameAnnotation(
        displayName: String,
        projectID: String?,
        confidence: UsageLedgerProjectNameConfidence?,
        source: UsageLedgerProjectNameSource?,
        provenance: String?) -> String?
    {
        let normalizedSource = source ?? .unknown
        let normalizedConfidence = confidence ?? .none

        let shouldAnnotateSource = normalizedSource != .projectName && normalizedSource != .budgetOverride
        let shouldAnnotateConfidence = normalizedConfidence != .high
        let isUnknown = RunicProjectDisplay.isUnattributed(displayName)
        guard shouldAnnotateSource || shouldAnnotateConfidence || isUnknown else { return nil }

        var parts: [String] = []
        if shouldAnnotateSource {
            parts.append("source \(self.projectSourceLabel(normalizedSource))")
        }
        if shouldAnnotateConfidence {
            parts.append("confidence \(self.projectConfidenceLabel(normalizedConfidence))")
        }
        if isUnknown, let fingerprint = self.projectIDFingerprint(projectID) {
            parts.append("id \(fingerprint)")
        }
        if let provenance = provenance?.trimmingCharacters(in: .whitespacesAndNewlines),
           !provenance.isEmpty
        {
            parts.append("via \(provenance)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func projectSourceLabel(_ source: UsageLedgerProjectNameSource) -> String {
        switch source {
        case .projectName: "project name"
        case .projectID: "project id"
        case .inferredFromPath: "path-derived"
        case .inferredFromName: "name-derived"
        case .budgetOverride: "budget override"
        case .unknown: "unknown"
        }
    }

    private func projectConfidenceLabel(_ confidence: UsageLedgerProjectNameConfidence) -> String {
        switch confidence {
        case .high: "high"
        case .medium: "medium"
        case .low: "low"
        case .none: "none"
        }
    }

    private func projectIDFingerprint(_ projectID: String?) -> String? {
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

    private static func renderedModelsLine(for modelsUsed: [String]) -> String {
        var seen: Set<String> = []
        var rendered: [String] = []
        for model in modelsUsed {
            let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            var text = UsageFormatter.modelDisplayName(trimmed)
            if let context = UsageFormatter.modelContextLabel(for: trimmed) {
                text += " \(context)"
            }
            rendered.append(text)
            if rendered.count >= 3 { break }
        }
        return rendered.joined(separator: ", ")
    }
}
