import AppKit
import RunicCore
import SwiftUI

// Chart submenu builders. Data availability is checked eagerly (it decides
// whether the submenu row exists at all), but the SwiftUI chart hierarchy is
// built lazily via `addDeferredChartSubmenu` when the submenu actually opens —
// building all ~15-20 chart hierarchies on every menu open was the dominant
// menu-open cost.

extension StatusItemController {
    @discardableResult
    func addUsageTimelineSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let dailySummaries = self.store.ledgerAllDailySummary(for: provider)
        let hourlySummaries = self.store.ledgerHourlySummary(for: provider)
        guard !dailySummaries.isEmpty || !hourlySummaries.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let chartStyle = self.settings.chartStyle
        let numberStyle = self.settings.numberFormat.formatterStyle
        self.addDeferredChartSubmenu(
            title: "Usage timeline",
            id: "usageTimelineChart",
            to: menu,
            width: width)
        { [weak self] in
            UsageTimelineChartMenuView(
                dailySummaries: dailySummaries,
                hourlySummaries: hourlySummaries,
                width: width,
                chartStyle: chartStyle,
                numberStyle: numberStyle,
                onRangeChange: { range in
                    self?.store.ensureLedgerHistoryCovers(days: range.days)
                })
        }
        return true
    }

    @discardableResult
    func addHourlyActivitySubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let hourlySummaries = self.store.ledgerHourlySummary(for: provider)
        guard !hourlySummaries.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let numberStyle = self.settings.numberFormat.formatterStyle
        self.addDeferredChartSubmenu(
            title: "Today by hour",
            id: "hourlyActivityChart",
            to: menu,
            width: width)
        {
            HourlyActivityChartMenuView(
                hourlySummaries: hourlySummaries,
                width: width,
                numberStyle: numberStyle)
        }
        return true
    }

    @discardableResult
    func addWeeklyActivitySubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let dailySummaries = self.store.ledgerAllDailySummary(for: provider)
        guard !dailySummaries.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let numberStyle = self.settings.numberFormat.formatterStyle
        self.addDeferredChartSubmenu(
            title: "Last 7 days",
            id: "weeklyActivityChart",
            to: menu,
            width: width)
        {
            WeeklyActivityChartMenuView(
                dailySummaries: dailySummaries,
                width: width,
                numberStyle: numberStyle)
        }
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
        self.addDeferredChartSubmenu(
            title: "Subscription utilization",
            id: "subscriptionUtilizationChart",
            to: menu,
            width: width)
        {
            SubscriptionUtilizationChartMenuView(
                dailySummaries: dailySummaries,
                currentUsedPercent: currentUsedPercent,
                todayTokens: todayTokens,
                width: width)
        }
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
        self.addDeferredChartSubmenu(
            title: "Usage windows",
            id: "usageWindowComparisonChart",
            to: menu,
            width: width)
        {
            UsageWindowComparisonChartMenuView(
                dailySummaries: dailySummaries,
                primaryLabel: primaryLabel,
                secondaryLabel: secondaryLabel,
                primaryPercent: primaryPercent,
                secondaryPercent: secondaryPercent,
                width: width)
        }
        return true
    }

    @discardableResult
    func addUsageHeatmapSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let hourlySummaries = self.store.ledgerHourlySummary(for: provider)
        guard !hourlySummaries.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let numberStyle = self.settings.numberFormat.formatterStyle
        self.addDeferredChartSubmenu(
            title: "Usage heatmap",
            id: "usageHeatmapChart",
            to: menu,
            width: width)
        {
            UsageHeatmapMenuView(
                hourlySummaries: hourlySummaries,
                width: width,
                numberStyle: numberStyle)
        }
        return true
    }

    @discardableResult
    func addEfficiencyMetricsSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let modelSummaries = self.store.ledgerModelBreakdown(for: provider)
        guard !modelSummaries.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let numberStyle = self.settings.numberFormat.formatterStyle
        self.addDeferredChartSubmenu(
            title: "Efficiency metrics",
            id: "efficiencyMetricsTable",
            to: menu,
            width: width)
        {
            EfficiencyMetricsMenuView(
                modelSummaries: modelSummaries,
                width: width,
                numberStyle: numberStyle)
        }
        return true
    }

    @discardableResult
    func addProjectBudgetsSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let projectSummaries = self.store.ledgerProjectBreakdown(for: provider)
        let hasBudgets = !ProjectBudgetStore.getAllBudgets().isEmpty
        // Show when budgets are configured, or when project data exists so the
        // empty state can point users at budget setup.
        guard hasBudgets || !projectSummaries.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        self.addDeferredChartSubmenu(
            title: "Project budgets",
            id: "projectBudgetsPanel",
            to: menu,
            width: width)
        { [weak self] in
            ProjectBudgetMenuView(
                projectSummaries: projectSummaries,
                width: width,
                onOpenPreferences: {
                    self?.openSettings(tab: .analytics)
                })
        }
        return true
    }

    @discardableResult
    func addAlertsSubmenu(to menu: NSMenu) -> Bool {
        guard !AlertRuleStore.getRecentHistory(limit: 1).isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let dateStyle = self.settings.dateFormat.formatterStyle
        self.addDeferredChartSubmenu(
            title: "Alerts",
            id: "alertsPanel",
            to: menu,
            width: width)
        {
            AlertsMenuView(width: width, dateStyle: dateStyle)
        }
        return true
    }
}
