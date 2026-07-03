import AppKit
import Observation
import RunicCore
import SwiftUI

// MARK: - NSMenu construction

extension StatusItemController {
    func makeMenu() -> NSMenu {
        guard self.shouldMergeIcons else {
            return self.makeMenu(for: nil)
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        self.applyRunicAppearance(to: menu)
        return menu
    }

    func makeMenu(for provider: UsageProvider?) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        self.applyRunicAppearance(to: menu)
        if let provider {
            self.menuProviders[ObjectIdentifier(menu)] = provider
        }
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Lazy chart submenus: build the hosted view only when the submenu is
        // actually about to open, not on every populateMenu.
        self.materializeDeferredSubmenuContent(in: menu)
        if self.isHostedSubviewMenu(menu) {
            self.refreshHostedSubviewHeights(in: menu)
            self.openMenus[ObjectIdentifier(menu)] = menu
            return
        }
        if menu.supermenu != nil {
            return
        }

        var provider: UsageProvider?
        if self.shouldMergeIcons {
            self.selectedMenuProvider = self.resolvedMenuProvider()
            // No codex fallback: when the merged menu shows the Overview tab
            // there is no specific provider, and nil keeps provider-targeted
            // actions (Ping now, dashboards) on their own fallback chains.
            self.lastMenuProvider = self.selectedMenuProvider
            provider = self.selectedMenuProvider
        } else {
            if let menuProvider = self.menuProviders[ObjectIdentifier(menu)] {
                self.lastMenuProvider = menuProvider
                provider = menuProvider
            } else if menu === self.fallbackMenu {
                self.lastMenuProvider = self.store.enabledProviders().first ?? .codex
                provider = nil
            } else {
                let resolved = self.store.enabledProviders().first ?? .codex
                self.lastMenuProvider = resolved
                provider = resolved
            }
        }

        if self.menuNeedsRefresh(menu) {
            self.populateMenu(menu, provider: provider)
            self.markMenuFresh(menu)
        }
        self.refreshMenuCardHeights(in: menu)
        self.openMenus[ObjectIdentifier(menu)] = menu
        self.scheduleOpenMenuPing(for: menu)
    }

    func menuDidClose(_ menu: NSMenu) {
        self.openMenus.removeValue(forKey: ObjectIdentifier(menu))
        self.menuPingTasks.removeValue(forKey: ObjectIdentifier(menu))?.cancel()
        for menuItem in menu.items {
            (menuItem.view as? MenuCardHighlighting)?.setHighlighted(false)
        }
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for menuItem in menu.items {
            let highlighted = menuItem == item && menuItem.isEnabled
            (menuItem.view as? MenuCardHighlighting)?.setHighlighted(highlighted)
        }
    }

    func populateMenu(_ menu: NSMenu, provider: UsageProvider?) {
        menu.removeAllItems()
        self.applyRunicAppearance(to: menu)

        let context = self.makeMenuPopulationContext(provider: provider, menu: menu)
        self.addProviderSwitcherIfNeeded(to: menu, context: context)
        self.addOverviewCardIfNeeded(to: menu, context: context)
        let addedOpenAIWebItems = self.addUsageCardIfNeeded(to: menu, context: context)
        self.addOpenAIWebSubmenusIfNeeded(to: menu, context: context, cardAlreadyAdded: addedOpenAIWebItems)
        self.addActivityChartSubmenusIfNeeded(to: menu, context: context)
        self.addExportUsageSubmenu(to: menu)
        self.addCustomProvidersSection(to: menu)
        self.addActionableSections(to: menu, context: context)
        self.applyRunicFont(to: menu)
    }
}
