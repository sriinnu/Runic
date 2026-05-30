import SwiftUI

struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings
    let selection: PreferencesSelection?

    var body: some View {
        Color.clear
            .frame(width: 20, height: 20)
            .onReceive(NotificationCenter.default.publisher(for: .runicOpenSettings)) { notification in
                Task { @MainActor in
                    if let tab = SettingsWindowBridge.tab(from: notification) {
                        SettingsWindowBridge.select(tab, in: self.selection)
                    }
                    self.openSettings()
                }
            }
            .onAppear {
                if let window = NSApp.windows.first(where: { $0.title == "RunicLifecycleKeepalive" }) {
                    // Make the keepalive window truly invisible and non-interactive.
                    window.styleMask = [.borderless]
                    window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
                    window.isExcludedFromWindowsMenu = true
                    window.level = .floating
                    window.isOpaque = false
                    window.alphaValue = 0
                    window.backgroundColor = .clear
                    window.hasShadow = false
                    window.ignoresMouseEvents = true
                    window.canHide = false
                    window.setContentSize(NSSize(width: 1, height: 1))
                    window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
                }
            }
    }
}
