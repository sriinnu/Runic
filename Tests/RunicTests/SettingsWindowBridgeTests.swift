import Foundation
import RunicCore
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

    @Test
    func `preferences redesign exposes appearance tab wide shell and openProvider deep link`() {
        #expect(PreferencesTab.allCases.contains(.appearance))
        #expect(PreferencesTab.windowWidth == 820)

        let selection = PreferencesSelection()
        selection.openProvider(.codex)
        #expect(selection.tab == .providers)
        #expect(selection.provider == .codex)
    }

    @Test
    func `overview add region labels distinguish china variants`() {
        #expect(OverviewMenuView.addRegionLabel(for: .zaiCN) == "Add z.ai (China)")
        #expect(OverviewMenuView.addRegionLabel(for: .minimaxCN) == "Add MiniMax (China)")
    }

    @Test
    func `font choices cache returns non empty stable list`() {
        let first = RunicFontChoice.availableChoices()
        let second = RunicFontChoice.availableChoices()

        #expect(!first.isEmpty)
        #expect(first == second)
    }
}
