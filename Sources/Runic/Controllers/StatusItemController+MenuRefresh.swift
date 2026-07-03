import AppKit
import Observation
import RunicCore
import SwiftUI

extension StatusItemController {
    func resolvedMenuProvider() -> UsageProvider? {
        let enabled = self.store.enabledProviders()
        if enabled.isEmpty { return .codex }
        if let selected = self.selectedMenuProvider, enabled.contains(selected) {
            return selected
        }
        return enabled.first
    }

    func menuNeedsRefresh(_ menu: NSMenu) -> Bool {
        let key = ObjectIdentifier(menu)
        return self.menuVersions[key] != self.menuContentVersion
    }

    func markMenuFresh(_ menu: NSMenu) {
        let key = ObjectIdentifier(menu)
        self.menuVersions[key] = self.menuContentVersion
        self.pruneStaleMenuState(keeping: key)
    }

    /// Drop bookkeeping for menus that no longer exist. `ObjectIdentifier`
    /// keys of deallocated menus both leak and — worse — can be REUSED by a
    /// newly allocated menu at the same address, which would make a brand-new
    /// menu look "fresh" and skip its first populate.
    private func pruneStaleMenuState(keeping key: ObjectIdentifier) {
        var live: Set<ObjectIdentifier> = [key]
        if let menu = self.mergedMenu { live.insert(ObjectIdentifier(menu)) }
        if let menu = self.fallbackMenu { live.insert(ObjectIdentifier(menu)) }
        for menu in self.providerMenus.values {
            live.insert(ObjectIdentifier(menu))
        }
        for menu in self.openMenus.values {
            live.insert(ObjectIdentifier(menu))
        }
        self.menuVersions = self.menuVersions.filter { live.contains($0.key) }
        self.menuProviders = self.menuProviders.filter { live.contains($0.key) }
    }

    func refreshOpenMenusIfNeeded() {
        guard !self.openMenus.isEmpty else { return }
        for (key, menu) in self.openMenus {
            guard key == ObjectIdentifier(menu) else {
                self.openMenus.removeValue(forKey: key)
                continue
            }

            if self.isHostedSubviewMenu(menu) {
                self.refreshHostedSubviewHeights(in: menu)
                continue
            }

            if self.menuNeedsRefresh(menu) {
                let provider = self.menuProvider(for: menu)
                self.populateMenu(menu, provider: provider)
                self.markMenuFresh(menu)
                self.refreshMenuCardHeights(in: menu)
            }
        }
    }

    func menuProvider(for menu: NSMenu) -> UsageProvider? {
        if self.shouldMergeIcons {
            return self.selectedMenuProvider ?? self.resolvedMenuProvider()
        }
        if let provider = self.menuProviders[ObjectIdentifier(menu)] {
            return provider
        }
        if menu === self.fallbackMenu {
            return nil
        }
        return self.store.enabledProviders().first ?? .codex
    }

    func scheduleOpenMenuPing(for menu: NSMenu) {
        guard self.settings.refreshFrequency != .manual else { return }
        let key = ObjectIdentifier(menu)
        self.menuPingTasks[key]?.cancel()
        self.menuPingTasks[key] = Task { @MainActor [weak self, weak menu] in
            guard let self, let menu else { return }
            try? await Task.sleep(for: Self.menuOpenPingDelay)
            guard !Task.isCancelled else { return }
            guard self.openMenus[ObjectIdentifier(menu)] != nil else { return }
            guard !self.store.isRefreshing else { return }
            let provider = self.menuProvider(for: menu) ?? self.resolvedMenuProvider()
            // Error-stale, missing, or simply AGED data all warrant a ping —
            // `isStale` alone is error-keyed, so old-but-successful snapshots
            // never re-pinged on menu open. (`.manual` is already excluded by
            // the guard at the top of this method.)
            guard self.store.shouldPingOnMenuOpen(provider: provider) else { return }
            await self.store.refresh(trigger: .menuOpen)
        }
    }

    func refreshMenuCardHeights(in menu: NSMenu) {
        let cardItems = menu.items.filter { item in
            (item.representedObject as? String)?.hasPrefix("menuCard") == true
        }
        for item in cardItems {
            guard let view = item.view else { continue }
            let width = self.menuCardWidth(for: self.store.enabledProviders(), menu: menu)
            let height = self.menuCardHeight(for: view, width: width)
            view.frame = NSRect(
                origin: .zero,
                size: NSSize(width: width, height: height))
        }
    }

    func isHostedSubviewMenu(_ menu: NSMenu) -> Bool {
        let ids: Set = [
            "usageBreakdownChart",
            "creditsHistoryChart",
            "costHistoryChart",
            "projectBreakdownChart",
            "modelBreakdownChart",
        ]
        return menu.items.contains { item in
            guard let id = item.representedObject as? String else { return false }
            return ids.contains(id)
        }
    }

    func refreshHostedSubviewHeights(in menu: NSMenu) {
        let enabledProviders = self.store.enabledProviders()
        let width = self.menuCardWidth(for: enabledProviders, menu: menu)

        for item in menu.items {
            guard let view = item.view else { continue }
            view.frame = NSRect(origin: .zero, size: NSSize(width: width, height: 1))
            view.layoutSubtreeIfNeeded()
            let height = view.fittingSize.height
            view.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
        }
    }
}
