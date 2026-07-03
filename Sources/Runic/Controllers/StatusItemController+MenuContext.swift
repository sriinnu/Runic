import AppKit
import Observation
import RunicCore
import SwiftUI

struct MenuPopulationContext {
    let selectedProvider: UsageProvider?
    let enabledProviders: [UsageProvider]
    let isOverviewMode: Bool
    let menuWidth: CGFloat
    let descriptor: MenuDescriptor
    let currentProvider: UsageProvider
    let webItems: StatusItemController.OpenAIWebMenuItems
    let useSidebarSwitcher: Bool
    let sidebarConfig: StatusItemController.MenuCardSidebarConfig?
    /// Entrance cascades play only on first open; refresh-driven repopulates
    /// of an already-open menu render the settled state immediately.
    let animateEntrance: Bool

    var hasOpenAIWebMenuItems: Bool {
        self.webItems.hasUsageBreakdown || self.webItems.hasCreditsHistory || self.webItems.hasCostHistory
    }
}

extension StatusItemController {
    static let menuCardBaseWidth: CGFloat = 340
    static let menuOpenPingDelay: Duration = PerformanceConstants.menuOpenPingDelay

    func menuCardWidth(for providers: [UsageProvider], menu: NSMenu? = nil) -> CGFloat {
        _ = menu
        let baseWidth = Self.menuCardBaseWidth
        guard self.usesSidebarSwitcher(for: providers) else { return baseWidth }
        return baseWidth + MenuCardSidebarMetrics.sidebarWidth(
            for: providers.count,
            iconSize: self.settings.providerSwitcherIconSize)
    }

    func usesSidebarSwitcher(for providers: [UsageProvider]) -> Bool {
        guard self.shouldMergeIcons, providers.count > 1 else { return false }
        return self.settings.providerSwitcherLayout == .sidebar
    }

    func makeMenuPopulationContext(provider: UsageProvider?, menu: NSMenu) -> MenuPopulationContext {
        let selectedProvider = provider
        let enabledProviders = self.store.enabledProviders()
        let isOverviewMode = selectedProvider == nil && enabledProviders.count > 1
        let menuWidth = self.menuCardWidth(for: enabledProviders, menu: menu)
        let descriptor = MenuDescriptor.build(
            provider: selectedProvider,
            store: self.store,
            settings: self.settings,
            account: self.account,
            updateReady: self.updater.updateStatus.isUpdateReady)
        let dashboard = self.store.openAIDashboard
        let currentProvider = selectedProvider ?? enabledProviders.first ?? .codex
        let openAIWebEligible = !isOverviewMode &&
            currentProvider == .codex &&
            self.store.openAIDashboardRequiresLogin == false &&
            dashboard != nil
        let hasCreditsHistory = openAIWebEligible && !(dashboard?.dailyBreakdown ?? []).isEmpty
        let hasUsageBreakdown = openAIWebEligible && !(dashboard?.usageBreakdown ?? []).isEmpty
        let hasCostHistory = !isOverviewMode &&
            self.settings.isCostUsageEffectivelyEnabled(for: currentProvider) &&
            (self.store.tokenSnapshot(for: currentProvider)?.daily.isEmpty == false)
        let useSidebarSwitcher = self.usesSidebarSwitcher(for: enabledProviders)
        let webItems = OpenAIWebMenuItems(
            hasUsageBreakdown: hasUsageBreakdown,
            hasCreditsHistory: hasCreditsHistory,
            hasCostHistory: hasCostHistory)
        return MenuPopulationContext(
            selectedProvider: selectedProvider,
            enabledProviders: enabledProviders,
            isOverviewMode: isOverviewMode,
            menuWidth: menuWidth,
            descriptor: descriptor,
            currentProvider: currentProvider,
            webItems: webItems,
            useSidebarSwitcher: useSidebarSwitcher,
            sidebarConfig: self.sidebarConfig(
                enabledProviders: enabledProviders,
                selectedProvider: selectedProvider,
                useSidebarSwitcher: useSidebarSwitcher,
                menu: menu),
            // The menu is only in `openMenus` while it is on screen, which is
            // exactly the repopulate-while-open case that must not replay the
            // entrance cascade.
            animateEntrance: self.openMenus[ObjectIdentifier(menu)] == nil)
    }

    func sidebarConfig(
        enabledProviders: [UsageProvider],
        selectedProvider: UsageProvider?,
        useSidebarSwitcher: Bool,
        menu: NSMenu) -> MenuCardSidebarConfig?
    {
        guard useSidebarSwitcher else { return nil }
        return MenuCardSidebarConfig(
            providers: enabledProviders,
            selected: selectedProvider,
            iconProvider: { [weak self] provider, iconSize in
                self?.switcherIcon(for: provider, size: iconSize) ?? NSImage()
            },
            weeklyRemainingProvider: { [weak self] provider in
                self?.switcherWeeklyRemaining(for: provider)
            },
            onSelect: { [weak self, weak menu] provider in
                guard let self, let menu else { return }
                self.selectedMenuProvider = provider
                self.lastMenuProvider = provider
                Task { @MainActor [weak self, weak menu] in
                    guard let self, let menu else { return }
                    self.populateMenu(menu, provider: provider)
                    self.markMenuFresh(menu)
                    self.refreshMenuCardHeights(in: menu)
                    self.applyIcon(phase: nil)
                }
            })
    }
}
