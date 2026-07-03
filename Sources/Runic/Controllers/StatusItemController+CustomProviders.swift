import AppKit
import RunicCore
import SwiftUI

// MARK: - Custom provider usage display

enum CustomProviderUsageDisplay {
    /// Display percent for used/quota, rounded (not truncated) and clamped to 0-100.
    static func percentUsed(used: Double, quota: Double) -> Int {
        guard quota > 0 else { return 0 }
        let percent = (used / quota) * 100
        return Int(min(max(percent, 0), 100).rounded())
    }
}

// MARK: - Custom providers section

extension StatusItemController {
    func addCustomProvidersSection(to menu: NSMenu) {
        let customProviders = CustomProviderStore.getEnabledProviders()
        guard !customProviders.isEmpty else { return }

        menu.addItem(.separator())

        let headerItem = NSMenuItem(title: "Custom Providers", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        let font = RunicFont.nsFont(size: NSFont.systemFontSize, weight: .semibold)
        headerItem.attributedTitle = NSAttributedString(string: "Custom Providers", attributes: [.font: font])
        menu.addItem(headerItem)

        for provider in customProviders {
            if let snapshot = self.store.customProviderSnapshots[provider.id] {
                menu.addItem(self.makeCustomProviderMenuItem(provider: provider, snapshot: snapshot))
            } else if let error = self.store.customProviderErrors[provider.id] {
                menu.addItem(self.makeCustomProviderErrorItem(provider: provider, error: error))
            } else {
                menu.addItem(self.makeCustomProviderLoadingItem(provider: provider))
            }
        }
    }

    private func makeCustomProviderMenuItem(
        provider: CustomProviderConfig,
        snapshot: CustomProviderSnapshot) -> NSMenuItem
    {
        let title: String
        if let quota = snapshot.usageData.quota, let used = snapshot.usageData.used, quota > 0 {
            let percent = CustomProviderUsageDisplay.percentUsed(used: used, quota: quota)
            title = "\(provider.name): \(percent)% used"
        } else if let remaining = snapshot.usageData.remaining {
            title = "\(provider.name): \(Int(remaining)) remaining"
        } else {
            title = provider.name
        }

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false

        if let image = NSImage(systemSymbolName: provider.icon, accessibilityDescription: nil) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            item.image = image
        }

        return item
    }

    private func makeCustomProviderErrorItem(provider: CustomProviderConfig, error: String) -> NSMenuItem {
        let item = NSMenuItem(title: "\(provider.name): Error", action: nil, keyEquivalent: "")
        item.isEnabled = false

        if let image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            item.image = image
        }

        let font = RunicFont.nsFont(size: NSFont.smallSystemFontSize)
        let subtitle = NSAttributedString(
            string: error,
            attributes: [.font: font, .foregroundColor: self.settings.theme.palette.nsWarmColor])
        let attributed = NSMutableAttributedString(string: "\(provider.name): Error\n")
        attributed.append(subtitle)
        item.attributedTitle = attributed

        return item
    }

    private func makeCustomProviderLoadingItem(provider: CustomProviderConfig) -> NSMenuItem {
        let item = NSMenuItem(title: "\(provider.name): Loading...", action: nil, keyEquivalent: "")
        item.isEnabled = false

        if let image = NSImage(systemSymbolName: provider.icon, accessibilityDescription: nil) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            item.image = image
        }

        return item
    }
}
