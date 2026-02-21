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
        let modelBreakdown = self.store.ledgerModelBreakdown(for: provider)
            .filter { $0.provider == provider }
        let projectBreakdown = self.store.ledgerProjectBreakdown(for: provider)
            .filter { $0.provider == provider }
        let reliability = self.store.ledgerReliabilityScore(for: provider)
        let routing = self.store.ledgerRoutingRecommendation(for: provider)
        guard !modelBreakdown.isEmpty || !projectBreakdown.isEmpty || reliability != nil || routing != nil else { return nil }

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let limit = max(1, self.settings.insightsMenuMaxItems)
        let reportDays = max(1, self.settings.insightsReportDays)
        let hasOverflow = modelBreakdown.count > limit || projectBreakdown.count > limit

        let titleItem = NSMenuItem(title: "Local insights (today)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        submenu.addItem(titleItem)

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
                    confidence: summary.projectNameConfidence)
                let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
                let costText = summary.totals.costUSD.map { UsageFormatter.usdString($0) }
                var title = "\(project) · \(summary.model): \(tokens) tokens"
                if let costText { title += " · \(costText)" }
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
                    confidence: summary.projectNameConfidence)
                let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
                let costText = summary.totals.costUSD.map { UsageFormatter.usdString($0) }
                let modelsText = summary.modelsUsed.isEmpty
                    ? nil
                    : (summary.modelsUsed.count <= 3
                        ? summary.modelsUsed.joined(separator: ", ")
                        : "\(summary.modelsUsed.count) models")
                var title = "\(project): \(tokens) tokens"
                if let costText { title += " · \(costText)" }
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
        confidence: UsageLedgerProjectNameConfidence? = nil) -> String
    {
        let trimmedProjectName = projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedProjectName, !trimmedProjectName.isEmpty {
            return trimmedProjectName
        }
        guard let projectID, !projectID.isEmpty else {
            return "Unknown project"
        }
        if let budgetName = ProjectBudgetStore.getBudget(projectID: projectID)?.projectName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !budgetName.isEmpty
        {
            return budgetName
        }
        if confidence == .some(.none) || confidence == .some(.low) {
            return "Unknown project"
        }
        return projectID
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
        guard !breakdown.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let submenu = NSMenu()
        submenu.delegate = self
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

        let item = NSMenuItem(title: "Models", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    // MARK: - Private helpers

    private func makeZaiUsageDetailsSubmenu(snapshot: UsageSnapshot?) -> NSMenu? {
        guard let timeLimit = snapshot?.zaiUsage?.timeLimit else { return nil }
        guard !timeLimit.usageDetails.isEmpty else { return nil }

        let submenu = NSMenu()
        submenu.delegate = self
        let titleItem = NSMenuItem(title: "MCP details", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        submenu.addItem(titleItem)

        if let window = timeLimit.windowLabel {
            let item = NSMenuItem(title: "Window: \(window)", action: nil, keyEquivalent: "")
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
        return submenu
    }
}
