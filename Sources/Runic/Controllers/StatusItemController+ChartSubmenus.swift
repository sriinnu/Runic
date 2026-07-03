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

        return self.makeDeferredHostedSubmenu(id: "usageBreakdownChart") { [weak self] in
            guard let self else { return NSView() }
            return self.makeSizedHostedView(
                self.themedHostedMenuRoot(UsageBreakdownChartMenuView(breakdown: breakdown, width: width)),
                width: width)
        }
    }

    func makeCreditsHistorySubmenu() -> NSMenu? {
        let breakdown = self.store.openAIDashboard?.dailyBreakdown ?? []
        let width = Self.menuCardBaseWidth
        guard !breakdown.isEmpty else { return nil }

        return self.makeDeferredHostedSubmenu(id: "creditsHistoryChart") { [weak self] in
            guard let self else { return NSView() }
            return self.makeSizedHostedView(
                self.themedHostedMenuRoot(CreditsHistoryChartMenuView(breakdown: breakdown, width: width)),
                width: width)
        }
    }

    func makeCostHistorySubmenu(provider: UsageProvider) -> NSMenu? {
        guard provider == .codex || provider == .claude else { return nil }
        let width = Self.menuCardBaseWidth
        guard let tokenSnapshot = self.store.tokenSnapshot(for: provider) else { return nil }
        guard !tokenSnapshot.daily.isEmpty else { return nil }

        return self.makeDeferredHostedSubmenu(id: "costHistoryChart") { [weak self] in
            guard let self else { return NSView() }
            return self.makeSizedHostedView(
                self.themedHostedMenuRoot(CostHistoryChartMenuView(
                    provider: provider,
                    daily: tokenSnapshot.daily,
                    totalCostUSD: tokenSnapshot.last30DaysCostUSD,
                    width: width)),
                width: width)
        }
    }
}
