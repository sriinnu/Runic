import AppKit
import Observation
import RunicCore
import SwiftUI

// MARK: - NSMenu construction

private struct MenuPopulationContext {
    let selectedProvider: UsageProvider?
    let enabledProviders: [UsageProvider]
    let isOverviewMode: Bool
    let menuWidth: CGFloat
    let descriptor: MenuDescriptor
    let currentProvider: UsageProvider
    let webItems: StatusItemController.OpenAIWebMenuItems
    let useSidebarSwitcher: Bool
    let sidebarConfig: StatusItemController.MenuCardSidebarConfig?

    var hasOpenAIWebMenuItems: Bool {
        self.webItems.hasUsageBreakdown || self.webItems.hasCreditsHistory || self.webItems.hasCostHistory
    }
}

extension StatusItemController {
    static let menuCardBaseWidth: CGFloat = 340
    private static let menuOpenPingDelay: Duration = PerformanceConstants.menuOpenPingDelay

    func menuCardWidth(for providers: [UsageProvider], menu: NSMenu? = nil) -> CGFloat {
        _ = menu
        let baseWidth = Self.menuCardBaseWidth
        guard self.usesSidebarSwitcher(for: providers) else { return baseWidth }
        return baseWidth + MenuCardSidebarMetrics.sidebarWidth(
            for: providers.count,
            iconSize: self.settings.providerSwitcherIconSize)
    }

    func usesSidebarSwitcher(for providers: [UsageProvider]) -> Bool {
        guard self.shouldMergeIcons, providers.count > 1 else { return false }
        return self.settings.providerSwitcherLayout == .sidebar
    }

    func makeMenu() -> NSMenu {
        guard self.shouldMergeIcons else {
            return self.makeMenu(for: nil)
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        self.applyRunicAppearance(to: menu)
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        if self.isHostedSubviewMenu(menu) {
            self.refreshHostedSubviewHeights(in: menu)
            self.openMenus[ObjectIdentifier(menu)] = menu
            return
        }
        if menu.supermenu != nil {
            return
        }

        var provider: UsageProvider?
        if self.shouldMergeIcons {
            self.selectedMenuProvider = self.resolvedMenuProvider()
            self.lastMenuProvider = self.selectedMenuProvider ?? .codex
            provider = self.selectedMenuProvider
        } else {
            if let menuProvider = self.menuProviders[ObjectIdentifier(menu)] {
                self.lastMenuProvider = menuProvider
                provider = menuProvider
            } else if menu === self.fallbackMenu {
                self.lastMenuProvider = self.store.enabledProviders().first ?? .codex
                provider = nil
            } else {
                let resolved = self.store.enabledProviders().first ?? .codex
                self.lastMenuProvider = resolved
                provider = resolved
            }
        }

        if self.menuNeedsRefresh(menu) {
            self.populateMenu(menu, provider: provider)
            self.markMenuFresh(menu)
        }
        self.refreshMenuCardHeights(in: menu)
        self.openMenus[ObjectIdentifier(menu)] = menu
        self.scheduleOpenMenuPing(for: menu)
    }

    func menuDidClose(_ menu: NSMenu) {
        self.openMenus.removeValue(forKey: ObjectIdentifier(menu))
        self.menuPingTasks.removeValue(forKey: ObjectIdentifier(menu))?.cancel()
        for menuItem in menu.items {
            (menuItem.view as? MenuCardHighlighting)?.setHighlighted(false)
        }
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for menuItem in menu.items {
            let highlighted = menuItem == item && menuItem.isEnabled
            (menuItem.view as? MenuCardHighlighting)?.setHighlighted(highlighted)
        }
    }

    func populateMenu(_ menu: NSMenu, provider: UsageProvider?) {
        menu.removeAllItems()
        self.applyRunicAppearance(to: menu)

        let context = self.makeMenuPopulationContext(provider: provider, menu: menu)
        self.addProviderSwitcherIfNeeded(to: menu, context: context)
        self.addOverviewCardIfNeeded(to: menu, context: context)
        let addedOpenAIWebItems = self.addUsageCardIfNeeded(to: menu, context: context)
        self.addOpenAIWebSubmenusIfNeeded(to: menu, context: context, cardAlreadyAdded: addedOpenAIWebItems)
        self.addActivityChartSubmenusIfNeeded(to: menu, context: context)
        self.addExportUsageSubmenu(to: menu)
        self.addCustomProvidersSection(to: menu)
        self.addActionableSections(to: menu, context: context)
        self.applyRunicFont(to: menu)
    }

    private func makeMenuPopulationContext(provider: UsageProvider?, menu: NSMenu) -> MenuPopulationContext {
        let selectedProvider = provider
        let enabledProviders = self.store.enabledProviders()
        let isOverviewMode = selectedProvider == nil && enabledProviders.count > 1
        let menuWidth = self.menuCardWidth(for: enabledProviders, menu: menu)
        let descriptor = MenuDescriptor.build(
            provider: selectedProvider,
            store: self.store,
            settings: self.settings,
            account: self.account,
            updateReady: self.updater.updateStatus.isUpdateReady)
        let dashboard = self.store.openAIDashboard
        let currentProvider = selectedProvider ?? enabledProviders.first ?? .codex
        let openAIWebEligible = !isOverviewMode &&
            currentProvider == .codex &&
            self.store.openAIDashboardRequiresLogin == false &&
            dashboard != nil
        let hasCreditsHistory = openAIWebEligible && !(dashboard?.dailyBreakdown ?? []).isEmpty
        let hasUsageBreakdown = openAIWebEligible && !(dashboard?.usageBreakdown ?? []).isEmpty
        let hasCostHistory = !isOverviewMode &&
            self.settings.isCostUsageEffectivelyEnabled(for: currentProvider) &&
            (self.store.tokenSnapshot(for: currentProvider)?.daily.isEmpty == false)
        let useSidebarSwitcher = self.usesSidebarSwitcher(for: enabledProviders)
        let webItems = OpenAIWebMenuItems(
            hasUsageBreakdown: hasUsageBreakdown,
            hasCreditsHistory: hasCreditsHistory,
            hasCostHistory: hasCostHistory)
        return MenuPopulationContext(
            selectedProvider: selectedProvider,
            enabledProviders: enabledProviders,
            isOverviewMode: isOverviewMode,
            menuWidth: menuWidth,
            descriptor: descriptor,
            currentProvider: currentProvider,
            webItems: webItems,
            useSidebarSwitcher: useSidebarSwitcher,
            sidebarConfig: self.sidebarConfig(
                enabledProviders: enabledProviders,
                selectedProvider: selectedProvider,
                useSidebarSwitcher: useSidebarSwitcher,
                menu: menu))
    }

    private func sidebarConfig(
        enabledProviders: [UsageProvider],
        selectedProvider: UsageProvider?,
        useSidebarSwitcher: Bool,
        menu: NSMenu) -> MenuCardSidebarConfig?
    {
        guard useSidebarSwitcher else { return nil }
        return MenuCardSidebarConfig(
            providers: enabledProviders,
            selected: selectedProvider,
            iconProvider: { [weak self] provider, iconSize in
                self?.switcherIcon(for: provider, size: iconSize) ?? NSImage()
            },
            weeklyRemainingProvider: { [weak self] provider in
                self?.switcherWeeklyRemaining(for: provider)
            },
            onSelect: { [weak self, weak menu] provider in
                guard let self, let menu else { return }
                self.selectedMenuProvider = provider
                self.lastMenuProvider = provider
                // Defer repopulation to avoid reentrancy: the SwiftUI button
                // that triggered this closure lives inside the menu item that
                // populateMenu will destroy via removeAllItems().
                Task { @MainActor [weak self, weak menu] in
                    guard let self, let menu else { return }
                    self.populateMenu(menu, provider: provider)
                    self.markMenuFresh(menu)
                    self.refreshMenuCardHeights(in: menu)
                    self.applyIcon(phase: nil)
                }
            })
    }

    private func addProviderSwitcherIfNeeded(to menu: NSMenu, context: MenuPopulationContext) {
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

    private func addOverviewCardIfNeeded(to menu: NSMenu, context: MenuPopulationContext) {
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

    private func addUsageCardIfNeeded(to menu: NSMenu, context: MenuPopulationContext) -> Bool {
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

    private func addOpenAIWebSubmenusIfNeeded(
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

    private func addActivityChartSubmenusIfNeeded(to menu: NSMenu, context: MenuPopulationContext) {
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

    private func addActionableSections(to menu: NSMenu, context: MenuPopulationContext) {
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

    private func addActionableSection(
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

    private func descriptorTextItem(title: String, style: MenuDescriptor.TextStyle) -> NSMenuItem {
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

    private func descriptorActionItem(
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

    private func hidesActionInOverview(_ action: MenuDescriptor.MenuAction) -> Bool {
        switch action {
        case .switchAccount, .dashboard, .statusPage:
            true
        case .installUpdate, .refresh, .settings, .about, .quit, .copyError:
            false
        }
    }

    private func applyActionIcon(_ action: MenuDescriptor.MenuAction, to item: NSMenuItem) {
        guard let iconName = action.systemImageName,
              let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        else {
            return
        }
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        item.image = image
    }

    private func addHostedMenuItem<Content: View>(
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


    func makeMenu(for provider: UsageProvider?) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        self.applyRunicAppearance(to: menu)
        if let provider {
            self.menuProviders[ObjectIdentifier(menu)] = provider
        }
        return menu
    }

    private func makeProviderSwitcherItem(
        providers: [UsageProvider],
        selected: UsageProvider?,
        menu: NSMenu) -> NSMenuItem
    {
        let view = ProviderSwitcherView(
            providers: providers,
            selected: selected,
            width: self.menuCardWidth(for: providers, menu: menu),
            showsIcons: self.settings.switcherShowsIcons,
            iconSizePreference: self.settings.providerSwitcherIconSize,
            theme: self.settings.theme.palette,
            iconProvider: { [weak self] provider, iconSize in
                self?.switcherIcon(for: provider, size: iconSize) ?? NSImage()
            },
            weeklyRemainingProvider: { [weak self] provider in
                self?.switcherWeeklyRemaining(for: provider)
            },
            onSelect: { [weak self, weak menu] provider in
                guard let self, let menu else { return }
                self.selectedMenuProvider = provider
                self.lastMenuProvider = provider
                self.populateMenu(menu, provider: provider)
                self.markMenuFresh(menu)
                self.refreshMenuCardHeights(in: menu)
                self.applyIcon(phase: nil)
            })
        let item = NSMenuItem()
        item.view = view
        item.isEnabled = false
        return item
    }

    private func makeProviderTabBar(
        providers: [UsageProvider],
        selected: UsageProvider?,
        width: CGFloat,
        menu: NSMenu) -> ProviderTabBarView?
    {
        guard providers.count > 1 else { return nil }
        let overviewColor = self.settings.theme.palette.accent

        var tabs: [ProviderTabBarView.TabItem] = [
            ProviderTabBarView.TabItem(
                id: "overview",
                label: "Overview",
                icon: nil,
                provider: nil,
                isSelected: selected == nil,
                brandColor: overviewColor),
        ]

        for provider in providers {
            let meta = self.store.metadata(for: provider)
            let icon = ProviderBrandIcon.image(for: provider, size: 22)
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let brandColor = Color(
                red: Double(descriptor.branding.color.red),
                green: Double(descriptor.branding.color.green),
                blue: Double(descriptor.branding.color.blue))
            tabs.append(ProviderTabBarView.TabItem(
                id: provider.rawValue,
                label: Self.abbreviatedProviderName(meta.displayName),
                icon: icon,
                provider: provider,
                isSelected: selected == provider,
                brandColor: brandColor))
        }

        return ProviderTabBarView(
            tabs: tabs,
            width: width,
            onSelect: { [weak self, weak menu] provider in
                guard let self, let menu else { return }
                self.selectedMenuProvider = provider
                self.lastMenuProvider = provider
                Task { @MainActor [weak self, weak menu] in
                    guard let self, let menu else { return }
                    self.populateMenu(menu, provider: provider)
                    self.markMenuFresh(menu)
                    self.refreshMenuCardHeights(in: menu)
                    self.applyIcon(phase: nil)
                }
            })
    }

    private func makeOverviewView(
        providers: [UsageProvider],
        width: CGFloat) -> OverviewMenuView
    {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        var summaries: [OverviewMenuView.ProviderSummary] = []
        var chartPoints: [OverviewMenuView.DailyPoint] = []
        var totalToday = 0

        for provider in providers {
            let meta = self.store.metadata(for: provider)
            let snapshot = self.store.snapshot(for: provider)
            let icon = ProviderBrandIcon.image(for: provider, size: 20)
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let brandColor = Color(
                red: Double(descriptor.branding.color.red),
                green: Double(descriptor.branding.color.green),
                blue: Double(descriptor.branding.color.blue))
            let usedPercent = snapshot?.primary.usedPercent ?? 0
            let todayTokens = self.store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0
            totalToday += todayTokens

            let resetDesc = snapshot?.primary.resetDescription
            let windowLabel = snapshot?.primary.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            let topModel = self.store.ledgerTopModel(for: provider)
            let topModelContext = ProviderContextWindowRegistry.shared
                .contextLabel(for: provider, model: topModel?.model)?
                .text

            summaries.append(OverviewMenuView.ProviderSummary(
                id: provider.rawValue,
                provider: provider,
                name: meta.displayName,
                icon: icon,
                usedPercent: usedPercent,
                todayTokens: todayTokens,
                brandColor: brandColor,
                resetDescription: resetDesc,
                windowLabel: windowLabel,
                topModelContext: topModelContext))

            // Chart data — last 7 days
            let dailySummaries = self.store.ledgerAllDailySummary(for: provider)
            for summary in dailySummaries where summary.dayStart >= weekAgo {
                chartPoints.append(OverviewMenuView.DailyPoint(
                    id: "\(provider.rawValue)-\(summary.dayKey)",
                    date: summary.dayStart,
                    tokens: summary.totals.totalTokens,
                    provider: meta.displayName,
                    color: brandColor))
            }
        }

        // Only show providers with data
        let activeSummaries = summaries.filter { $0.usedPercent > 0 || $0.todayTokens > 0 }

        return OverviewMenuView(
            summaries: activeSummaries.isEmpty ? summaries : activeSummaries,
            chartPoints: chartPoints,
            totalTodayTokens: totalToday,
            totalProviders: providers.count,
            width: width)
    }

    private static func abbreviatedProviderName(_ name: String) -> String {
        if name.count <= 8 { return name }
        // Abbreviate long names
        let abbreviations: [String: String] = [
            "Antigravity": "AntiG",
            "OpenRouter": "ORouter",
            "Perplexity": "Perplx",
            "SambaNova": "SambaN",
            "Azure OpenAI": "Azure",
        ]
        return abbreviations[name] ?? String(name.prefix(6))
    }

    private func resolvedMenuProvider() -> UsageProvider? {
        let enabled = self.store.enabledProviders()
        if enabled.isEmpty { return .codex }
        if let selected = self.selectedMenuProvider, enabled.contains(selected) {
            return selected
        }
        return enabled.first
    }

    private func menuNeedsRefresh(_ menu: NSMenu) -> Bool {
        let key = ObjectIdentifier(menu)
        return self.menuVersions[key] != self.menuContentVersion
    }

    private func markMenuFresh(_ menu: NSMenu) {
        let key = ObjectIdentifier(menu)
        self.menuVersions[key] = self.menuContentVersion
    }

    func refreshOpenMenusIfNeeded() {
        guard !self.openMenus.isEmpty else { return }
        for (key, menu) in self.openMenus {
            guard key == ObjectIdentifier(menu) else {
                self.openMenus.removeValue(forKey: key)
                continue
            }

            if self.isHostedSubviewMenu(menu) {
                self.refreshHostedSubviewHeights(in: menu)
                continue
            }

            if self.menuNeedsRefresh(menu) {
                let provider = self.menuProvider(for: menu)
                self.populateMenu(menu, provider: provider)
                self.markMenuFresh(menu)
                self.refreshMenuCardHeights(in: menu)
            }
        }
    }

    private func menuProvider(for menu: NSMenu) -> UsageProvider? {
        if self.shouldMergeIcons {
            return self.selectedMenuProvider ?? self.resolvedMenuProvider()
        }
        if let provider = self.menuProviders[ObjectIdentifier(menu)] {
            return provider
        }
        if menu === self.fallbackMenu {
            return nil
        }
        return self.store.enabledProviders().first ?? .codex
    }

    private func scheduleOpenMenuPing(for menu: NSMenu) {
        guard self.settings.refreshFrequency != .manual else { return }
        let key = ObjectIdentifier(menu)
        self.menuPingTasks[key]?.cancel()
        self.menuPingTasks[key] = Task { @MainActor [weak self, weak menu] in
            guard let self, let menu else { return }
            try? await Task.sleep(for: Self.menuOpenPingDelay)
            guard !Task.isCancelled else { return }
            guard self.openMenus[ObjectIdentifier(menu)] != nil else { return }
            guard !self.store.isRefreshing else { return }
            let provider = self.menuProvider(for: menu) ?? self.resolvedMenuProvider()
            let isStale = provider.map { self.store.isStale(provider: $0) } ?? self.store.isStale
            let hasSnapshot = provider.map { self.store.snapshot(for: $0) != nil } ?? true
            guard isStale || !hasSnapshot else { return }
            await self.store.refresh(trigger: .menuOpen)
        }
    }

    func refreshMenuCardHeights(in menu: NSMenu) {
        let cardItems = menu.items.filter { item in
            (item.representedObject as? String)?.hasPrefix("menuCard") == true
        }
        for item in cardItems {
            guard let view = item.view else { continue }
            let width = self.menuCardWidth(for: self.store.enabledProviders(), menu: menu)
            let height = self.menuCardHeight(for: view, width: width)
            view.frame = NSRect(
                origin: .zero,
                size: NSSize(width: width, height: height))
        }
    }

    private func switcherIcon(for provider: UsageProvider, size: CGFloat) -> NSImage {
        if let brand = ProviderBrandIcon.image(for: provider, size: size) {
            return brand
        }

        let snapshot = self.store.snapshot(for: provider)
        let showUsed = self.settings.usageBarsShowUsed
        let primary = showUsed ? snapshot?.primary.usedPercent : snapshot?.primary.remainingPercent
        let weekly = showUsed ? snapshot?.secondary?.usedPercent : snapshot?.secondary?.remainingPercent
        let credits = provider == .codex ? self.store.credits?.remaining : nil
        let stale = self.store.isStale(provider: provider)
        let style = self.store.style(for: provider)
        let indicator = self.store.statusIndicator(for: provider)
        let image = IconRenderer.makeIcon(
            primaryRemaining: primary,
            weeklyRemaining: weekly,
            creditsRemaining: credits,
            stale: stale,
            style: style,
            blink: 0,
            wiggle: 0,
            tilt: 0,
            statusIndicator: indicator)
        image.isTemplate = true
        image.size = NSSize(width: size, height: size)
        return image
    }

    private func switcherWeeklyRemaining(for provider: UsageProvider) -> Double? {
        let snapshot = self.store.snapshot(for: provider)
        let window: RateWindow? = if provider == .factory {
            snapshot?.secondary ?? snapshot?.primary
        } else {
            snapshot?.primary ?? snapshot?.secondary
        }
        guard let window else { return nil }
        if self.settings.usageBarsShowUsed {
            return window.usedPercent
        }
        return window.remainingPercent
    }

    private func addExportUsageSubmenu(to menu: NSMenu) {
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

    private func selector(for action: MenuDescriptor.MenuAction) -> (Selector, Any?) {
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

    private func isHostedSubviewMenu(_ menu: NSMenu) -> Bool {
        let ids: Set = [
            "usageBreakdownChart",
            "creditsHistoryChart",
            "costHistoryChart",
            "projectBreakdownChart",
            "modelBreakdownChart",
        ]
        return menu.items.contains { item in
            guard let id = item.representedObject as? String else { return false }
            return ids.contains(id)
        }
    }

    private func refreshHostedSubviewHeights(in menu: NSMenu) {
        let enabledProviders = self.store.enabledProviders()
        let width = self.menuCardWidth(for: enabledProviders, menu: menu)

        for item in menu.items {
            guard let view = item.view else { continue }
            view.frame = NSRect(origin: .zero, size: NSSize(width: width, height: 1))
            view.layoutSubtreeIfNeeded()
            let height = view.fittingSize.height
            view.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
        }
    }
}
