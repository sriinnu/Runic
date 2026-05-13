import AppKit
import RunicCore
import SwiftUI

// MARK: - Custom providers section

extension StatusItemController {
    func addCustomProvidersSection(to menu: NSMenu) {
        let customProviders = CustomProviderStore.getEnabledProviders()
        guard !customProviders.isEmpty else { return }

        let rowWidth = self.menuCardWidth(for: self.store.enabledProviders(), menu: menu)
        self.addMenuSeparator(to: menu, width: rowWidth, id: "customProviders.separator")

        menu.addItem(self.makeMenuActionRowItem(
            id: "customProviders.header",
            title: "Custom Providers",
            width: rowWidth,
            isEnabled: false))

        for provider in customProviders {
            if let snapshot = self.store.customProviderSnapshots[provider.id] {
                menu.addItem(self.makeCustomProviderMenuItem(
                    provider: provider,
                    snapshot: snapshot,
                    width: rowWidth))
            } else if let error = self.store.customProviderErrors[provider.id] {
                menu.addItem(self.makeCustomProviderErrorItem(
                    provider: provider,
                    error: error,
                    width: rowWidth))
            } else {
                menu.addItem(self.makeCustomProviderLoadingItem(provider: provider, width: rowWidth))
            }
        }
    }

    private func makeCustomProviderMenuItem(
        provider: CustomProviderConfig,
        snapshot: CustomProviderSnapshot,
        width: CGFloat) -> NSMenuItem
    {
        let subtitle: String?
        if let quota = snapshot.usageData.quota, let used = snapshot.usageData.used, quota > 0 {
            let percent = Int((used / quota) * 100)
            subtitle = "\(percent)% used"
        } else if let remaining = snapshot.usageData.remaining {
            subtitle = "\(Int(remaining)) remaining"
        } else {
            subtitle = nil
        }

        return self.makeMenuActionRowItem(
            id: "customProviders.\(provider.id)",
            title: provider.name,
            icon: provider.icon,
            subtitle: subtitle,
            width: width,
            isEnabled: false)
    }

    private func makeCustomProviderErrorItem(
        provider: CustomProviderConfig,
        error: String,
        width: CGFloat) -> NSMenuItem
    {
        self.makeMenuActionRowItem(
            id: "customProviders.error.\(provider.id)",
            title: "\(provider.name): Error",
            icon: "exclamationmark.triangle",
            subtitle: error,
            width: width,
            isEnabled: false)
    }

    private func makeCustomProviderLoadingItem(provider: CustomProviderConfig, width: CGFloat) -> NSMenuItem {
        self.makeMenuActionRowItem(
            id: "customProviders.loading.\(provider.id)",
            title: provider.name,
            icon: provider.icon,
            subtitle: "Loading...",
            width: width,
            isEnabled: false)
    }
}
