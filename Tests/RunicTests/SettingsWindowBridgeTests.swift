import Foundation
import Testing
@testable import Runic

@MainActor
struct SettingsWindowBridgeTests {
    @Test
    func `reads tab from settings notification payload`() {
        let notification = Notification(
            name: .runicOpenSettings,
            userInfo: [SettingsWindowBridge.tabUserInfoKey: PreferencesTab.about.rawValue])

        #expect(SettingsWindowBridge.tab(from: notification) == .about)
    }

    @Test
    func `ignores missing or invalid settings notification payload`() {
        let missing = Notification(name: .runicOpenSettings)
        let invalid = Notification(
            name: .runicOpenSettings,
            userInfo: [SettingsWindowBridge.tabUserInfoKey: "not-a-tab"])

        #expect(SettingsWindowBridge.tab(from: missing) == nil)
        #expect(SettingsWindowBridge.tab(from: invalid) == nil)
    }

    @Test
    func `selects requested preferences tab`() {
        let selection = PreferencesSelection()

        SettingsWindowBridge.select(.about, in: selection)
        #expect(selection.tab == .about)

        SettingsWindowBridge.select(.general, in: selection)
        #expect(selection.tab == .general)
    }
}
