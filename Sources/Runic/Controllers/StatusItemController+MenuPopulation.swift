import AppKit
import Observation
import RunicCore
import SwiftUI

extension StatusItemController {
    func addProviderSwitcherIfNeeded(to menu: NSMenu, context: MenuPopulationContext) {
        guard self.shouldMergeIcons,
              context.enabledProviders.count > 1,
              !context.useSidebarSwitcher
        else {
            return
        }

        let tabBarView = self.makeProviderTabBar(
            providers: context.enabledProviders,
            selected: context.selectedProvider,
            width: context.menuWidth,
            menu: menu)
        if let tabBarView {
            self.addHostedMenuItem(
                self.themedHostedMenuRoot(tabBarView),
                id: "providerTabBar",
                width: context.menuWidth,
                to: menu)
        } else {
            let switcherItem = self.makeProviderSwitcherItem(
                providers: context.enabledProviders,
                selected: context.selectedProvider,
                menu: menu)
            menu.addItem(switcherItem)
        }
        menu.addItem(.separator())
    }

    func addOverviewCardIfNeeded(to menu: NSMenu, context: MenuPopulationContext) {
        guard context.isOverviewMode else { return }
        let overviewView = self.makeOverviewView(
            providers: context.enabledProviders,
            width: context.menuWidth)
        self.addHostedMenuItem(
            self.themedHostedMenuRoot(overviewView),
            id: "overviewCard",
            width: context.menuWidth,
            to: menu)
        menu.addItem(.separator())
    }

    func addUsageCardIfNeeded(to menu: NSMenu, context: MenuPopulationContext) -> Bool {
        guard !context.isOverviewMode,
              let model = self.menuCardModel(for: context.selectedProvider)
        else {
            return false
        }

        if context.hasOpenAIWebMenuItems, !context.useSidebarSwitcher {
            self.addMenuCardSections(
                to: menu,
                request: .init(
                    model: model,
                    provider: context.currentProvider,
                    width: context.menuWidth,
                    sidebar: context.sidebarConfig,
                    webItems: context.webItems))
            return true
        }

        let cardView = self.menuCardContent(
            width: context.menuWidth,
            sidebar: context.sidebarConfig,
            showIcons: true)
        {
            UsageMenuCardView(model: model, width: $0)
        }
        menu.addItem(self.makeMenuCardItem(cardView, id: "menuCard", width: context.menuWidth))
        if context.currentProvider == .codex, model.creditsText != nil {
            menu.addItem(self.makeBuyCreditsItem())
        }
        menu.addItem(.separator())
        return false
    }

    func addOpenAIWebSubmenusIfNeeded(
        to menu: NSMenu,
        context: MenuPopulationContext,
        cardAlreadyAdded: Bool)
    {
        guard !context.isOverviewMode, context.hasOpenAIWebMenuItems else { return }
        if !cardAlreadyAdded {
            if context.webItems.hasUsageBreakdown {
                _ = self.addUsageBreakdownSubmenu(to: menu)
            }
            if context.webItems.hasCreditsHistory {
                _ = self.addCreditsHistorySubmenu(to: menu)
            }
            if context.webItems.hasCostHistory {
                _ = self.addCostHistorySubmenu(to: menu, provider: context.currentProvider)
            }
        }
        menu.addItem(.separator())
    }

    func addActivityChartSubmenusIfNeeded(to menu: NSMenu, context: MenuPopulationContext) {
        guard !context.isOverviewMode else { return }
        let hasTimeline = self.addUsageTimelineSubmenu(to: menu, provider: context.currentProvider)
        let hasHourly = self.addHourlyActivitySubmenu(to: menu, provider: context.currentProvider)
        let hasWeekly = self.addWeeklyActivitySubmenu(to: menu, provider: context.currentProvider)
        if hasTimeline || hasHourly || hasWeekly {
            menu.addItem(.separator())
        }

        let hasUtilization = self.addSubscriptionUtilizationSubmenu(to: menu, provider: context.currentProvider)
        let hasWindowComparison = self.addUsageWindowComparisonSubmenu(to: menu, provider: context.currentProvider)
        if hasUtilization || hasWindowComparison {
            menu.addItem(.separator())
        }

        let hasProjectBreakdown = self.addProjectBreakdownSubmenu(to: menu, provider: context.currentProvider)
        let hasModelBreakdown = self.addModelBreakdownSubmenu(to: menu, provider: context.currentProvider)
        if hasProjectBreakdown || hasModelBreakdown {
            menu.addItem(.separator())
        }
    }

    func addActionableSections(to menu: NSMenu, context: MenuPopulationContext) {
        let actionableSections = context.descriptor.sections.filter { section in
            section.entries.contains { entry in
                if case .action = entry { return true }
                return false
            }
        }
        for (index, section) in actionableSections.enumerated() {
            self.addActionableSection(section, isOverviewMode: context.isOverviewMode, to: menu)
            if index < actionableSections.count - 1 {
                menu.addItem(.separator())
            }
        }
    }

    func addActionableSection(
        _ section: MenuDescriptor.Section,
        isOverviewMode: Bool,
        to menu: NSMenu)
    {
        for entry in section.entries {
            switch entry {
            case let .text(text, style):
                menu.addItem(self.descriptorTextItem(title: text, style: style))
            case let .action(title, action):
                if let item = self.descriptorActionItem(title: title, action: action, isOverviewMode: isOverviewMode) {
                    menu.addItem(item)
                }
            case .divider:
                menu.addItem(.separator())
            }
        }
    }

    func descriptorTextItem(title: String, style: MenuDescriptor.TextStyle) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        if style == .headline {
            let font = RunicFont.nsFont(size: NSFont.systemFontSize, weight: .semibold)
            item.attributedTitle = NSAttributedString(string: title, attributes: [.font: font])
        } else if style == .secondary {
            let font = RunicFont.nsFont(size: NSFont.smallSystemFontSize)
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: font,
                    .foregroundColor: self.settings.theme.palette.nsSecondaryTextColor,
                ])
        }
        return item
    }

    func descriptorActionItem(
        title: String,
        action: MenuDescriptor.MenuAction,
        isOverviewMode: Bool) -> NSMenuItem?
    {
        if isOverviewMode, self.hidesActionInOverview(action) {
            return nil
        }
        if case .refresh = action {
            return self.makePersistentRefreshItem(title: title)
        }
        let (selector, represented) = self.selector(for: action)
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.representedObject = represented
        self.applyActionIcon(action, to: item)
        if case let .switchAccount(targetProvider) = action,
           let subtitle = self.switchAccountSubtitle(for: targetProvider)
        {
            item.isEnabled = false
            self.applySubtitle(subtitle, to: item, title: title)
        }
        return item
    }

    func hidesActionInOverview(_ action: MenuDescriptor.MenuAction) -> Bool {
        switch action {
        case .switchAccount, .dashboard, .statusPage:
            true
        case .installUpdate, .refresh, .settings, .about, .quit, .copyError:
            false
        }
    }

    func applyActionIcon(_ action: MenuDescriptor.MenuAction, to item: NSMenuItem) {
        guard let iconName = action.systemImageName,
              let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        else {
            return
        }
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        item.image = image
    }

    func addHostedMenuItem<Content: View>(
        _ rootView: Content,
        id: String,
        width: CGFloat,
        to menu: NSMenu)
    {
        let hosting = MenuHostingView(rootView: rootView)
        let controller = NSHostingController(rootView: rootView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))
        let item = NSMenuItem()
        item.view = hosting
        item.isEnabled = false
        item.representedObject = id
        menu.addItem(item)
    }

    func addExportUsageSubmenu(to menu: NSMenu) {
        let exportItem = NSMenuItem(title: "Export Usage\u{2026}", action: nil, keyEquivalent: "")
        if let image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Export") {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            exportItem.image = image
        }
        let submenu = NSMenu(title: "Export Usage")
        let csvItem = NSMenuItem(
            title: "Export as CSV\u{2026}",
            action: #selector(self.exportUsageCSV(_:)),
            keyEquivalent: "")
        csvItem.target = self
        let jsonItem = NSMenuItem(
            title: "Export as JSON\u{2026}",
            action: #selector(self.exportUsageJSON(_:)),
            keyEquivalent: "")
        jsonItem.target = self
        submenu.addItem(csvItem)
        submenu.addItem(jsonItem)
        exportItem.submenu = submenu
        menu.addItem(exportItem)
        menu.addItem(.separator())
    }

    func selector(for action: MenuDescriptor.MenuAction) -> (Selector, Any?) {
        switch action {
        case .installUpdate: (#selector(self.installUpdate), nil)
        case .refresh: (#selector(self.refreshNow), nil)
        case .dashboard: (#selector(self.openDashboard), nil)
        case .statusPage: (#selector(self.openStatusPage), nil)
        case let .switchAccount(provider): (#selector(self.runSwitchAccount(_:)), provider.rawValue)
        case .settings: (#selector(self.showSettingsGeneral), nil)
        case .about: (#selector(self.showSettingsAbout), nil)
        case .quit: (#selector(self.quit), nil)
        case let .copyError(message): (#selector(self.copyError(_:)), message)
        }
    }

    @objc func menuCardNoOp(_ sender: NSMenuItem) {
        _ = sender
    }
}
