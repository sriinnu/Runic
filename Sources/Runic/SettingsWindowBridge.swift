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

        let opened = NSApp.openRunicSettingsWindow()
        NotificationCenter.default.post(
            name: .runicOpenSettings,
            object: nil,
            userInfo: [Self.tabUserInfoKey: tab.rawValue])

        // SwiftUI creates the Settings window asynchronously in response to the
        // action above, so activating/foregrounding here (before it exists) is a
        // no-op. Retry for a few ticks until it materializes, then force it front —
        // accessory (LSUIElement) apps don't auto-raise newly created windows.
        Self.foregroundSettingsWindow(attemptsRemaining: 20)
        return opened
    }

    private static func foregroundSettingsWindow(attemptsRemaining: Int) {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.level == .normal && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard attemptsRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.foregroundSettingsWindow(attemptsRemaining: attemptsRemaining - 1)
        }
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
