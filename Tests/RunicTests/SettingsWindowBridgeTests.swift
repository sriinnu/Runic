import Foundation
import RunicCore
import SwiftUI
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
    func `configured bridge opens and reuses single visible settings window and routes nil selection`() throws {
        defer { SettingsWindowBridge.resetForTesting() }
        let selection = PreferencesSelection()
        SettingsWindowBridge.configure(selection: selection) { AnyView(EmptyView()) }

        let opened = SettingsWindowBridge.open(tab: .appearance, selection: nil)
        #expect(opened)
        #expect(selection.tab == .appearance)

        let window = try #require(SettingsWindowBridge.activeManagedWindowForTesting)
        #expect(window.isReleasedWhenClosed == false)
        #expect(window.frame.width >= 740)
        #expect(window.frame.height >= 600)

        SettingsWindowBridge.open(tab: .providers, selection: nil)
        #expect(selection.tab == .providers)
        #expect(SettingsWindowBridge.activeManagedWindowForTesting === window)
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
