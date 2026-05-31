import AppKit

@MainActor
enum SettingsWindowBridge {
    static let tabUserInfoKey = "tab"

    static func tab(from notification: Notification) -> PreferencesTab? {
        guard let raw = notification.userInfo?[tabUserInfoKey] as? String else { return nil }
        return PreferencesTab(rawValue: raw)
    }

    static func select(_ tab: PreferencesTab, in selection: PreferencesSelection?) {
        selection?.tab = tab
    }

    @discardableResult
    static func open(tab: PreferencesTab, selection: PreferencesSelection?) -> Bool {
        self.select(tab, in: selection)
        NSApp.activate(ignoringOtherApps: true)

        let opened = NSApp.openRunicSettingsWindow()
        NotificationCenter.default.post(
            name: .runicOpenSettings,
            object: nil,
            userInfo: [Self.tabUserInfoKey: tab.rawValue])
        return opened
    }
}

@MainActor
extension NSApplication {
    @discardableResult
    fileprivate func openRunicSettingsWindow() -> Bool {
        let selectors = [
            Selector(("showSettingsWindow:")),
            Selector(("showPreferencesWindow:")),
        ]

        for selector in selectors where self.sendAction(selector, to: nil, from: nil) {
            return true
        }
        return false
    }
}
