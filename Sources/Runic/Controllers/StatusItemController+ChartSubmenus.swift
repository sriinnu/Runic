import AppKit
import RunicCore
import SwiftUI

// MARK: - Chart submenu builders

extension StatusItemController {
    @discardableResult
    func addCreditsHistorySubmenu(to menu: NSMenu) -> Bool {
        guard let submenu = self.makeCreditsHistorySubmenu() else { return false }
        let item = NSMenuItem(title: "Credits history", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    @discardableResult
    func addUsageBreakdownSubmenu(to menu: NSMenu) -> Bool {
        guard let submenu = self.makeUsageBreakdownSubmenu() else { return false }
        let item = NSMenuItem(title: "Usage breakdown", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    @discardableResult
    func addCostHistorySubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        guard let submenu = self.makeCostHistorySubmenu(provider: provider) else { return false }
        let item = NSMenuItem(title: "Usage history (30 days)", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    func makeUsageSubmenu(
        provider: UsageProvider,
        snapshot: UsageSnapshot?,
        webItems: OpenAIWebMenuItems) -> NSMenu?
    {
        if provider == .codex, webItems.hasUsageBreakdown {
            return self.makeUsageBreakdownSubmenu()
        }
        if provider == .zai {
            return self.makeZaiUsageDetailsSubmenu(snapshot: snapshot)
        }
        return nil
    }

    func makeInsightsSubmenu(provider: UsageProvider) -> NSMenu? {
        let daily = self.store.ledgerDailySummary(for: provider)
        let activeBlock = self.store.ledgerActiveBlock(for: provider)
        let modelBreakdown = self.store.ledgerModelBreakdown(for: provider)
            .filter { $0.provider == provider }
        let projectBreakdown = self.store.ledgerProjectBreakdown(for: provider)
            .filter { $0.provider == provider }
        let reliability = self.store.ledgerReliabilityScore(for: provider)
        let routing = self.store.ledgerRoutingRecommendation(for: provider)
        let hasActiveBlock = activeBlock?.isActive == true
        guard daily != nil || hasActiveBlock || !modelBreakdown.isEmpty || !projectBreakdown.isEmpty || reliability != nil || routing != nil else {
            return nil
        }

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let limit = max(1, self.settings.insightsMenuMaxItems)
        let reportDays = max(1, self.settings.insightsReportDays)
        let hasOverflow = modelBreakdown.count > limit || projectBreakdown.count > limit

        let titleItem = NSMenuItem(title: "Local insights (today)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        submenu.addItem(titleItem)

        if let daily {
            let totalTokens = UsageFormatter.tokenCountString(daily.totals.totalTokens)
            let inputTokens = UsageFormatter.tokenCountString(daily.totals.inputTokens)
            let outputTokens = UsageFormatter.tokenCountString(daily.totals.outputTokens)
            var line = "Today: \(totalTokens) tokens · in \(inputTokens) · out \(outputTokens)"
            if let cost = daily.totals.costUSD {
                line += " · \(UsageFormatter.usdString(cost))"
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: cost,
                    tokenCount: daily.totals.totalTokens)
                {
                    line += " · \(per1K)"
                }
            }
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        }

        if let activeBlock, activeBlock.isActive {
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

        if let reliability {
            let item = NSMenuItem(
                title: "Reliability: \(reliability.score)/100 · \(reliability.grade)",
                action: nil,
                keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        }
        if let routing {
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

        if !modelBreakdown.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let header = NSMenuItem(title: "Models by project", action: nil, keyEquivalent: "")
            header.isEnabled = false
            submenu.addItem(header)

            let limited = modelBreakdown.prefix(limit)
            for summary in limited {
                let project = self.displayProjectName(
                    projectID: summary.projectID,
                    projectName: summary.projectName,
                    confidence: summary.projectNameConfidence,
                    source: summary.projectNameSource,
                    provenance: summary.projectNameProvenance,
                    includeAttribution: true)
                let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
                let costText = summary.totals.costUSD.map { UsageFormatter.usdString($0) }
                let modelName = UsageFormatter.modelDisplayName(summary.model)
                var title = "\(project) · \(modelName): \(tokens) tokens · \(summary.entryCount) req"
                if let context = UsageFormatter.modelContextLabel(for: summary.model) {
                    title += " · \(context)"
                }
                if let costText { title += " · \(costText)" }
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: summary.totals.costUSD,
                    tokenCount: summary.totals.totalTokens)
                {
                    title += " · \(per1K)"
                }
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
        }

        if !projectBreakdown.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let header = NSMenuItem(title: "Projects", action: nil, keyEquivalent: "")
            header.isEnabled = false
            submenu.addItem(header)

            let limited = projectBreakdown.prefix(limit)
            for summary in limited {
                let project = self.displayProjectName(
                    projectID: summary.projectID,
                    projectName: summary.projectName,
                    confidence: summary.projectNameConfidence,
                    source: summary.projectNameSource,
                    provenance: summary.projectNameProvenance,
                    includeAttribution: true)
                let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
                let costText = summary.totals.costUSD.map { UsageFormatter.usdString($0) }
                let modelsText = summary.modelsUsed.isEmpty
                    ? nil
                    : Self.renderedModelsLine(for: summary.modelsUsed)
                var title = "\(project): \(tokens) tokens · \(summary.entryCount) req"
                if let costText { title += " · \(costText)" }
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: summary.totals.costUSD,
                    tokenCount: summary.totals.totalTokens)
                {
                    title += " · \(per1K)"
                }
                if let modelsText { title += " · \(modelsText)" }
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
        }

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

        return submenu
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
        let displayName: String
        if let trimmedProjectName, !trimmedProjectName.isEmpty {
            displayName = trimmedProjectName
        } else if let projectID, !projectID.isEmpty {
            if let budgetName = ProjectBudgetStore.getBudget(projectID: projectID)?.projectName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !budgetName.isEmpty
            {
                displayName = budgetName
            } else if let fallback = UsageLedgerProjectIdentityResolver.fallbackDisplayName(projectID: projectID) {
                displayName = fallback
            } else {
                displayName = "Unknown project"
            }
        } else {
            displayName = "Unknown project"
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
        let isUnknown = displayName == "Unknown project"
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

        var hash: UInt64 = 0xcbf29ce484222325
        for byte in projectID.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%08llx", hash)
    }

    // MARK: - Private chart builders

    func makeUsageBreakdownSubmenu() -> NSMenu? {
        let breakdown = self.store.openAIDashboard?.usageBreakdown ?? []
        let width = Self.menuCardBaseWidth
        guard !breakdown.isEmpty else { return nil }

        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = UsageBreakdownChartMenuView(breakdown: breakdown, width: width)
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "usageBreakdownChart"
        submenu.addItem(chartItem)
        return submenu
    }

    func makeCreditsHistorySubmenu() -> NSMenu? {
        let breakdown = self.store.openAIDashboard?.dailyBreakdown ?? []
        let width = Self.menuCardBaseWidth
        guard !breakdown.isEmpty else { return nil }

        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = CreditsHistoryChartMenuView(breakdown: breakdown, width: width)
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "creditsHistoryChart"
        submenu.addItem(chartItem)
        return submenu
    }

    func makeCostHistorySubmenu(provider: UsageProvider) -> NSMenu? {
        guard provider == .codex || provider == .claude else { return nil }
        let width = Self.menuCardBaseWidth
        guard let tokenSnapshot = self.store.tokenSnapshot(for: provider) else { return nil }
        guard !tokenSnapshot.daily.isEmpty else { return nil }

        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = CostHistoryChartMenuView(
            provider: provider,
            daily: tokenSnapshot.daily,
            totalCostUSD: tokenSnapshot.last30DaysCostUSD,
            width: width)
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "costHistoryChart"
        submenu.addItem(chartItem)
        return submenu
    }

    // MARK: - Timeline & Activity submenus

    @discardableResult
    func addUsageTimelineSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let dailySummaries = self.store.ledgerAllDailySummary(for: provider)
        let hourlySummaries = self.store.ledgerHourlySummary(for: provider)
        guard !dailySummaries.isEmpty || !hourlySummaries.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = UsageTimelineChartMenuView(
            dailySummaries: dailySummaries,
            hourlySummaries: hourlySummaries,
            width: width)
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "usageTimelineChart"
        submenu.addItem(chartItem)

        let item = NSMenuItem(title: "Usage timeline", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    @discardableResult
    func addHourlyActivitySubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let hourlySummaries = self.store.ledgerHourlySummary(for: provider)
        guard !hourlySummaries.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = HourlyActivityChartMenuView(hourlySummaries: hourlySummaries, width: width)
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "hourlyActivityChart"
        submenu.addItem(chartItem)

        let item = NSMenuItem(title: "Today by hour", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    @discardableResult
    func addWeeklyActivitySubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let dailySummaries = self.store.ledgerAllDailySummary(for: provider)
        guard !dailySummaries.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = WeeklyActivityChartMenuView(dailySummaries: dailySummaries, width: width)
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "weeklyActivityChart"
        submenu.addItem(chartItem)

        let item = NSMenuItem(title: "Last 7 days", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    // MARK: - Subscription Utilization & Window Comparison

    @discardableResult
    func addSubscriptionUtilizationSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let dailySummaries = self.store.ledgerAllDailySummary(for: provider)
        guard !dailySummaries.isEmpty else { return false }
        let snapshot = self.store.snapshot(for: provider)
        let currentUsedPercent = snapshot?.primary.usedPercent ?? 0
        let todayTokens = self.store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0
        guard todayTokens > 0 else { return false }

        let width = Self.menuCardBaseWidth
        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = SubscriptionUtilizationChartMenuView(
            dailySummaries: dailySummaries,
            currentUsedPercent: currentUsedPercent,
            todayTokens: todayTokens,
            width: width)
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "subscriptionUtilizationChart"
        submenu.addItem(chartItem)

        let item = NSMenuItem(title: "Subscription utilization", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    @discardableResult
    func addUsageWindowComparisonSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let dailySummaries = self.store.ledgerAllDailySummary(for: provider)
        let snapshot = self.store.snapshot(for: provider)
        guard !dailySummaries.isEmpty, let snapshot else { return false }
        let todayTokens = self.store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0
        guard todayTokens > 0 else { return false }

        let primaryLabel = snapshot.primary.label ?? snapshot.primary.resetDescription ?? "Session"
        let secondaryLabel = snapshot.secondary?.label ?? snapshot.secondary?.resetDescription
        let primaryPercent = snapshot.primary.usedPercent
        let secondaryPercent = snapshot.secondary?.usedPercent
        guard primaryPercent > 0 || (secondaryPercent ?? 0) > 0 else { return false }

        let width = Self.menuCardBaseWidth
        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = UsageWindowComparisonChartMenuView(
            dailySummaries: dailySummaries,
            primaryLabel: primaryLabel,
            secondaryLabel: secondaryLabel,
            primaryPercent: primaryPercent,
            secondaryPercent: secondaryPercent,
            width: width)
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "usageWindowComparisonChart"
        submenu.addItem(chartItem)

        let item = NSMenuItem(title: "Usage windows", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    // MARK: - Project & Model submenus (Phase 4)

    func addProjectBreakdownSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let breakdown = self.store.ledgerProjectBreakdown(for: provider)
        guard !breakdown.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = ProjectBreakdownMenuView(breakdown: breakdown, width: width)
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "projectBreakdownChart"
        submenu.addItem(chartItem)

        let item = NSMenuItem(title: "Projects", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    func addModelBreakdownSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let breakdown = self.store.ledgerModelBreakdown(for: provider)
        let submenu = NSMenu()
        submenu.delegate = self

        if !breakdown.isEmpty {
            let width = Self.menuCardBaseWidth
            let chartView = ModelBreakdownMenuView(breakdown: breakdown, width: width)
            let hosting = MenuHostingView(rootView: chartView)
            let controller = NSHostingController(rootView: chartView)
            let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

            let chartItem = NSMenuItem()
            chartItem.view = hosting
            chartItem.isEnabled = false
            chartItem.representedObject = "modelBreakdownChart"
            submenu.addItem(chartItem)
        } else {
            let quotaWindows = self.modelQuotaWindows(for: provider)
            guard !quotaWindows.isEmpty else { return false }

            let titleItem = NSMenuItem(title: "Quota windows", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            submenu.addItem(titleItem)

            for window in quotaWindows {
                let rawLabel = window.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Model"
                let label = UsageFormatter.modelDisplayName(rawLabel)
                let used = Int(window.usedPercent.rounded())
                let remaining = Int(window.remainingPercent.rounded())
                var line = "\(label): \(used)% used · \(remaining)% left"
                if let resetsAt = window.resetsAt {
                    line += " · reset \(UsageFormatter.resetCountdownDescription(from: resetsAt))"
                } else if let resetDescription = window.resetDescription?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !resetDescription.isEmpty
                {
                    line += " · \(resetDescription)"
                }
                let detailItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
                detailItem.isEnabled = false
                submenu.addItem(detailItem)
            }
        }

        let item = NSMenuItem(title: "Models", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    // MARK: - Private helpers

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

    private func modelQuotaWindows(for provider: UsageProvider) -> [RateWindow] {
        guard let snapshot = self.store.snapshot(for: provider) else { return [] }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap { $0 }
        var seen: Set<String> = []
        var result: [RateWindow] = []

        for window in windows {
            guard let label = window.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty
            else {
                continue
            }
            let normalized = label.lowercased()
            guard seen.insert(normalized).inserted else { continue }
            result.append(window)
        }
        return result
    }

    private func makeZaiUsageDetailsSubmenu(snapshot: UsageSnapshot?) -> NSMenu? {
        guard let zai = snapshot?.zaiUsage else { return nil }
        let hasMCPDetails = zai.timeLimit.map { !$0.usageDetails.isEmpty } ?? false
        let hasModelUsage = zai.modelUsage.map { !$0.entries.isEmpty } ?? false
        let hasToolUsage = zai.toolUsage.map { !$0.entries.isEmpty } ?? false
        guard hasMCPDetails || hasModelUsage || hasToolUsage else { return nil }

        let submenu = NSMenu()
        submenu.delegate = self

        // MARK: Model usage (24h) — tokens, prompts, estimated cost per model
        if let modelUsage = zai.modelUsage, !modelUsage.entries.isEmpty {
            let headerFont = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            let header = NSMenuItem(title: "Models (24h)", action: nil, keyEquivalent: "")
            header.attributedTitle = NSAttributedString(string: "Models (24h)", attributes: [.font: headerFont])
            header.isEnabled = false
            submenu.addItem(header)

            let totalTokensStr = UsageFormatter.tokenCountString(modelUsage.totalTokens)
            let totalPromptsStr = "\(modelUsage.totalPrompts) prompts"
            let totalCostStr = modelUsage.totalEstimatedCostUSD > 0
                ? String(format: " · ~$%.2f", modelUsage.totalEstimatedCostUSD) : ""
            let summaryItem = NSMenuItem(
                title: "\(totalTokensStr) tokens · \(totalPromptsStr)\(totalCostStr)",
                action: nil, keyEquivalent: "")
            summaryItem.isEnabled = false
            let summaryFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            summaryItem.attributedTitle = NSAttributedString(
                string: summaryItem.title,
                attributes: [.font: summaryFont, .foregroundColor: NSColor.secondaryLabelColor])
            submenu.addItem(summaryItem)
            submenu.addItem(.separator())

            for entry in modelUsage.entries {
                let tokens = UsageFormatter.tokenCountString(entry.tokens)
                var title = "\(entry.modelCode): \(tokens)"
                if entry.prompts > 0 {
                    title += " · \(entry.prompts)p"
                }
                if let cost = entry.estimatedCostUSD, cost > 0.001 {
                    title += String(format: " · ~$%.3f", cost)
                }
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                submenu.addItem(item)
            }

            if hasToolUsage || hasMCPDetails {
                submenu.addItem(.separator())
            }
        }

        // MARK: Tool usage (24h) — MCP tool call counts
        if let toolUsage = zai.toolUsage, !toolUsage.entries.isEmpty {
            let headerFont = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            let header = NSMenuItem(title: "MCP Tools (24h)", action: nil, keyEquivalent: "")
            header.attributedTitle = NSAttributedString(string: "MCP Tools (24h)", attributes: [.font: headerFont])
            header.isEnabled = false
            submenu.addItem(header)

            let totalItem = NSMenuItem(
                title: "\(toolUsage.totalCalls) total calls",
                action: nil, keyEquivalent: "")
            totalItem.isEnabled = false
            let totalFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            totalItem.attributedTitle = NSAttributedString(
                string: totalItem.title,
                attributes: [.font: totalFont, .foregroundColor: NSColor.secondaryLabelColor])
            submenu.addItem(totalItem)
            submenu.addItem(.separator())

            for entry in toolUsage.entries {
                let displayName = self.displayToolName(entry.toolName)
                let item = NSMenuItem(
                    title: "\(displayName): \(entry.count) calls",
                    action: nil, keyEquivalent: "")
                submenu.addItem(item)
            }

            if hasMCPDetails {
                submenu.addItem(.separator())
            }
        }

        // MARK: Quota MCP details (existing — from timeLimit.usageDetails)
        if let timeLimit = zai.timeLimit, !timeLimit.usageDetails.isEmpty {
            let headerFont = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            let header = NSMenuItem(title: "Quota Window", action: nil, keyEquivalent: "")
            header.attributedTitle = NSAttributedString(string: "Quota Window", attributes: [.font: headerFont])
            header.isEnabled = false
            submenu.addItem(header)

            if let window = timeLimit.windowLabel {
                let item = NSMenuItem(title: window, action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
            if let resetTime = timeLimit.nextResetTime {
                let reset = UsageFormatter.resetDescription(from: resetTime)
                let item = NSMenuItem(title: "Resets: \(reset)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
            submenu.addItem(.separator())

            let sortedDetails = timeLimit.usageDetails.sorted {
                $0.modelCode.localizedCaseInsensitiveCompare($1.modelCode) == .orderedAscending
            }
            for detail in sortedDetails {
                let usage = UsageFormatter.tokenCountString(detail.usage)
                let item = NSMenuItem(title: "\(detail.modelCode): \(usage)", action: nil, keyEquivalent: "")
                submenu.addItem(item)
            }
        }

        return submenu
    }

    private func displayToolName(_ raw: String) -> String {
        let mapping: [String: String] = [
            "web_search": "Web Search",
            "web_reader": "Web Reader",
            "zread": "ZRead",
            "web-search": "Web Search",
            "web-reader": "Web Reader",
        ]
        return mapping[raw.lowercased()] ?? raw
    }
}
