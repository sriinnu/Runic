import AppKit
import SwiftUI

@MainActor
enum SettingsWindowBridge {
    static let tabUserInfoKey = "tab"
    private static let autosaveName = "RunicSettingsWindow"

    private static var rootViewFactory: (@MainActor () -> AnyView)?
    private static var defaultSelection: PreferencesSelection?
    private static var managedWindow: NSWindow?

    static var activeManagedWindowForTesting: NSWindow? {
        self.managedWindow
    }

    static func configure(selection: PreferencesSelection, makeRootView: @escaping @MainActor () -> AnyView) {
        self.defaultSelection = selection
        self.rootViewFactory = makeRootView
        self.managedWindow?.close()
        self.managedWindow = nil
    }

    static func resetForTesting() {
        self.managedWindow?.close()
        self.managedWindow = nil
        self.rootViewFactory = nil
        self.defaultSelection = nil
    }

    static func tab(from notification: Notification) -> PreferencesTab? {
        guard let raw = notification.userInfo?[tabUserInfoKey] as? String else { return nil }
        return PreferencesTab(rawValue: raw)
    }

    static func select(_ tab: PreferencesTab, in selection: PreferencesSelection?) {
        selection?.tab = tab
    }

    @discardableResult
    static func open(tab: PreferencesTab, selection: PreferencesSelection?) -> Bool {
        let activeSelection = selection ?? self.defaultSelection
        self.select(tab, in: activeSelection)

        if let factory = self.rootViewFactory {
            let window = self.resolveManagedWindow(makeRootView: factory)
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            NSApp?.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            return true
        }

        NSApp?.activate(ignoringOtherApps: true)
        let opened = NSApp?.openRunicSettingsWindow() ?? false
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

    private static func resolveManagedWindow(makeRootView: @MainActor () -> AnyView) -> NSWindow {
        if let existing = self.managedWindow {
            return existing
        }

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: PreferencesTab.windowWidth,
                height: PreferencesTab.windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Runic Settings"
        window.identifier = NSUserInterfaceItemIdentifier("com.sriinnu.athena.runic.settings")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 740, height: 600)
        window.maxSize = NSSize(width: 1120, height: CGFloat.greatestFiniteMagnitude)
        window.collectionBehavior.insert(.moveToActiveSpace)

        let hosting = NSHostingController(rootView: makeRootView())
        hosting.sizingOptions = []
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: PreferencesTab.windowWidth, height: PreferencesTab.windowHeight))

        if !window.setFrameUsingName(Self.autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.autosaveName)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) {
            window.center()
        }

        self.managedWindow = window
        return window
    }

    private static func foregroundSettingsWindow(attemptsRemaining: Int) {
        NSApp?.activate(ignoringOtherApps: true)
        if let window = settingsWindow() {
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard attemptsRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.foregroundSettingsWindow(attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private static func settingsWindow() -> NSWindow? {
        let normalVisible = (NSApp?.windows ?? []).filter { $0.level == .normal && $0.isVisible }
        if let exact = normalVisible.first(where: {
            let identifier = $0.identifier?.rawValue.lowercased() ?? ""
            let title = $0.title.lowercased()
            return identifier.contains("settings")
                || title.contains("settings")
                || title.contains("preferences")
        }) {
            return exact
        }
        return normalVisible.first { window in
            let title = window.title.lowercased()
            return !title.contains("sign in") && !title.contains("keepalive")
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
