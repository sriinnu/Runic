import AppKit
import RunicCore
import SwiftUI

extension StatusItemController {
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
}
