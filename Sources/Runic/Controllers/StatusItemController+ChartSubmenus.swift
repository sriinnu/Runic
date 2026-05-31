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

    // MARK: - Private chart builders

    func makeUsageBreakdownSubmenu() -> NSMenu? {
        let breakdown = self.store.openAIDashboard?.usageBreakdown ?? []
        let width = Self.menuCardBaseWidth
        guard !breakdown.isEmpty else { return nil }

        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = self.themedHostedMenuRoot(UsageBreakdownChartMenuView(breakdown: breakdown, width: width))
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
        let chartView = self.themedHostedMenuRoot(CreditsHistoryChartMenuView(breakdown: breakdown, width: width))
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
        let chartView = self.themedHostedMenuRoot(CostHistoryChartMenuView(
            provider: provider,
            daily: tokenSnapshot.daily,
            totalCostUSD: tokenSnapshot.last30DaysCostUSD,
            width: width))
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
        let chartView = self.themedHostedMenuRoot(UsageTimelineChartMenuView(
            dailySummaries: dailySummaries,
            hourlySummaries: hourlySummaries,
            width: width,
            chartStyle: self.settings.chartStyle,
            onRangeChange: { [weak self] range in
                self?.store.ensureLedgerHistoryCovers(days: range.days)
            }))
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
        let chartView = self.themedHostedMenuRoot(HourlyActivityChartMenuView(
            hourlySummaries: hourlySummaries,
            width: width))
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
        let chartView = self.themedHostedMenuRoot(WeeklyActivityChartMenuView(
            dailySummaries: dailySummaries,
            width: width))
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
        let chartView = self.themedHostedMenuRoot(SubscriptionUtilizationChartMenuView(
            dailySummaries: dailySummaries,
            currentUsedPercent: currentUsedPercent,
            todayTokens: todayTokens,
            width: width))
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
        let chartView = self.themedHostedMenuRoot(UsageWindowComparisonChartMenuView(
            dailySummaries: dailySummaries,
            primaryLabel: primaryLabel,
            secondaryLabel: secondaryLabel,
            primaryPercent: primaryPercent,
            secondaryPercent: secondaryPercent,
            width: width))
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
        let chartView = self.themedHostedMenuRoot(ProjectBreakdownMenuView(breakdown: breakdown, width: width))
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
            let chartView = self.themedHostedMenuRoot(ModelBreakdownMenuView(breakdown: breakdown, width: width))
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

    private func modelQuotaWindows(for provider: UsageProvider) -> [RateWindow] {
        guard let snapshot = self.store.snapshot(for: provider) else { return [] }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self)
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
            let headerFont = RunicFont.nsFont(size: NSFont.systemFontSize, weight: .semibold)
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
                action: nil,
                keyEquivalent: "")
            summaryItem.isEnabled = false
            let summaryFont = RunicFont.nsFont(size: NSFont.smallSystemFontSize)
            summaryItem.attributedTitle = NSAttributedString(
                string: summaryItem.title,
                attributes: [.font: summaryFont, .foregroundColor: self.settings.theme.palette.nsSecondaryTextColor])
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
            let headerFont = RunicFont.nsFont(size: NSFont.systemFontSize, weight: .semibold)
            let header = NSMenuItem(title: "MCP Tools (24h)", action: nil, keyEquivalent: "")
            header.attributedTitle = NSAttributedString(string: "MCP Tools (24h)", attributes: [.font: headerFont])
            header.isEnabled = false
            submenu.addItem(header)

            let totalItem = NSMenuItem(
                title: "\(toolUsage.totalCalls) total calls",
                action: nil,
                keyEquivalent: "")
            totalItem.isEnabled = false
            let totalFont = RunicFont.nsFont(size: NSFont.smallSystemFontSize)
            totalItem.attributedTitle = NSAttributedString(
                string: totalItem.title,
                attributes: [.font: totalFont, .foregroundColor: self.settings.theme.palette.nsSecondaryTextColor])
            submenu.addItem(totalItem)
            submenu.addItem(.separator())

            for entry in toolUsage.entries {
                let displayName = self.displayToolName(entry.toolName)
                let item = NSMenuItem(
                    title: "\(displayName): \(entry.count) calls",
                    action: nil,
                    keyEquivalent: "")
                submenu.addItem(item)
            }

            if hasMCPDetails {
                submenu.addItem(.separator())
            }
        }

        // MARK: Quota MCP details (existing — from timeLimit.usageDetails)

        if let timeLimit = zai.timeLimit, !timeLimit.usageDetails.isEmpty {
            let headerFont = RunicFont.nsFont(size: NSFont.systemFontSize, weight: .semibold)
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
