import AppKit
import RunicCore
import SwiftUI

// MARK: - Menu card construction

extension StatusItemController {
    func makeMenuCardItem(
        _ view: some View,
        id: String,
        width: CGFloat,
        submenu: NSMenu? = nil) -> NSMenuItem
    {
        let highlightState = MenuCardHighlightState()
        let wrapped = MenuCardSectionContainerView(
            highlightState: highlightState,
            showsSubmenuIndicator: submenu != nil)
        {
            view
        }
        let hosting = MenuCardItemHostingView(rootView: wrapped, highlightState: highlightState)
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: 1))
        hosting.needsLayout = true
        hosting.layoutSubtreeIfNeeded()
        let height = self.menuCardHeight(for: hosting, width: width)
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
        let item = NSMenuItem()
        item.view = hosting
        item.isEnabled = true
        item.representedObject = id
        item.submenu = submenu
        if submenu != nil {
            item.target = self
            item.action = #selector(self.menuCardNoOp(_:))
        }
        return item
    }

    func menuCardHeight(for view: NSView, width: CGFloat) -> CGFloat {
        let basePadding: CGFloat = MenuCardMetrics.menuItemBasePadding
        let descenderSafety: CGFloat = MenuCardMetrics.menuItemDescenderPadding

        if let measured = view as? MenuCardMeasuring {
            return max(1, ceil(measured.measuredHeight(width: width) + basePadding + descenderSafety))
        }

        view.frame = NSRect(origin: .zero, size: NSSize(width: width, height: 1))
        let widthConstraint = view.widthAnchor.constraint(equalToConstant: width)
        widthConstraint.priority = .required
        widthConstraint.isActive = true
        view.layoutSubtreeIfNeeded()
        widthConstraint.isActive = false
        let fitted = view.fittingSize
        return max(1, ceil(fitted.height + basePadding + descenderSafety))
    }

    func addMenuCardSections(
        to menu: NSMenu,
        model: UsageMenuCardView.Model,
        provider: UsageProvider,
        width: CGFloat,
        sidebar: MenuCardSidebarConfig?,
        webItems: OpenAIWebMenuItems)
    {
        let menuMode = self.settings.menuMode
        let includeSummarySections = menuMode != .glance
        let includeInsights = menuMode == .`operator`
        let includeActions = menuMode == .`operator`
        let hasUsageBlock = !model.metrics.isEmpty || model.placeholder != nil
        let hasCredits = includeSummarySections && model.creditsText != nil
        let hasExtraUsage = includeSummarySections && model.providerCost != nil
        let hasCost = includeSummarySections && model.tokenUsage != nil
        let hasInsights = includeInsights && model.insights != nil
        let bottomPadding = MenuCardMetrics.sectionBottomPadding
        let sectionSpacing = MenuCardMetrics.sectionTopPadding
        let usageBottomPadding = bottomPadding
        let creditsBottomPadding = bottomPadding

        let headerView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
            UsageMenuCardHeaderSectionView(
                model: model,
                showDivider: hasUsageBlock,
                width: $0)
        }
        menu.addItem(self.makeMenuCardItem(headerView, id: "menuCardHeader", width: width))

        if hasUsageBlock {
            let usageView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
                UsageMenuCardUsageSectionView(
                    model: model,
                    showBottomDivider: false,
                    bottomPadding: usageBottomPadding,
                    width: $0)
            }
            let usageSubmenu: NSMenu? = if includeActions {
                self.makeUsageSubmenu(
                    provider: provider,
                    snapshot: self.store.snapshot(for: provider),
                    webItems: webItems)
            } else {
                nil
            }
            menu.addItem(self.makeMenuCardItem(
                usageView,
                id: "menuCardUsage",
                width: width,
                submenu: usageSubmenu))
        }

        // Hero today stat + glassmorphism cards + timestamp (Features 2, 4, 7)
        if includeSummarySections {
            self.addHeroStatCards(
                to: menu,
                provider: provider,
                width: width,
                sidebar: sidebar)
        }

        if hasCredits || hasExtraUsage || hasCost || hasInsights {
            menu.addItem(.separator())
        }

        if hasCredits {
            let creditsView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
                UsageMenuCardCreditsSectionView(
                    model: model,
                    showBottomDivider: false,
                    topPadding: sectionSpacing,
                    bottomPadding: creditsBottomPadding,
                    width: $0)
            }
            let creditsSubmenu: NSMenu? = if includeActions, webItems.hasCreditsHistory {
                self.makeCreditsHistorySubmenu()
            } else {
                nil
            }
            menu.addItem(self.makeMenuCardItem(
                creditsView,
                id: "menuCardCredits",
                width: width,
                submenu: creditsSubmenu))
            if includeActions, provider == .codex {
                menu.addItem(self.makeBuyCreditsItem())
            }
            if hasExtraUsage || hasCost || hasInsights {
                menu.addItem(.separator())
            }
        }
        if hasExtraUsage {
            let extraUsageView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
                UsageMenuCardExtraUsageSectionView(
                    model: model,
                    topPadding: sectionSpacing,
                    bottomPadding: bottomPadding,
                    width: $0)
            }
            menu.addItem(self.makeMenuCardItem(
                extraUsageView,
                id: "menuCardExtraUsage",
                width: width))
            if hasCost || hasInsights {
                menu.addItem(.separator())
            }
        }
        if hasCost {
            let costView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
                UsageMenuCardCostSectionView(
                    model: model,
                    topPadding: sectionSpacing,
                    bottomPadding: bottomPadding,
                    width: $0)
            }
            let costSubmenu: NSMenu? = if includeActions, webItems.hasCostHistory {
                self.makeCostHistorySubmenu(provider: provider)
            } else {
                nil
            }
            menu.addItem(self.makeMenuCardItem(
                costView,
                id: "menuCardCost",
                width: width,
                submenu: costSubmenu))
            if hasInsights {
                menu.addItem(.separator())
            }
        }
        if hasInsights {
            let insightsView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
                UsageMenuCardInsightsSectionView(
                    model: model,
                    topPadding: sectionSpacing,
                    bottomPadding: bottomPadding,
                    width: $0)
            }
            let insightsSubmenu = self.makeInsightsSubmenu(provider: provider)
            menu.addItem(self.makeMenuCardItem(
                insightsView,
                id: "menuCardInsights",
                width: width,
                submenu: insightsSubmenu))
        }
    }

    // MARK: - Hero stat cards, timestamp

    private func addHeroStatCards(
        to menu: NSMenu,
        provider: UsageProvider,
        width: CGFloat,
        sidebar: MenuCardSidebarConfig?)
    {
        let daily = self.store.ledgerDailySummary(for: provider)
        let hourlySummaries = self.store.ledgerHourlySummary(for: provider)
        let allDaily = self.store.ledgerAllDailySummary(for: provider)

        // Hero today stat with provider icon
        if let daily, daily.totals.totalTokens > 0 {
            let providerIcon = ProviderBrandIcon.image(for: provider, size: 28)
            let heroView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
                HeroTodayStatView(
                    providerIcon: providerIcon,
                    tokenCount: daily.totals.totalTokens,
                    costUSD: daily.totals.costUSD,
                    width: $0)
            }
            menu.addItem(self.makeMenuCardItem(heroView, id: "heroTodayStat", width: width))
        }

        // Inline usage line chart (directly in the menu, not a submenu)
        if !allDaily.isEmpty || !hourlySummaries.isEmpty {
            let chartView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
                InlineUsageChartView(
                    dailySummaries: allDaily,
                    hourlySummaries: hourlySummaries,
                    width: $0)
            }
            menu.addItem(self.makeMenuCardItem(chartView, id: "inlineUsageChart", width: width))
        }

        // Glassmorphism stat cards
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayHourly = hourlySummaries.filter { $0.hourStart >= todayStart }

        // Compute peak hour
        var tokensByHour: [Int: Int] = [:]
        for summary in todayHourly {
            let hour = calendar.component(.hour, from: summary.hourStart)
            tokensByHour[hour, default: 0] += summary.totals.totalTokens
        }
        let peakEntry = tokensByHour.max(by: { $0.value < $1.value })
        let hasPeakHour = peakEntry != nil && (peakEntry?.value ?? 0) > 0

        // Compute this week total
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        let weekTotal = allDaily
            .filter { $0.dayStart >= weekAgo }
            .reduce(0) { $0 + $1.totals.totalTokens }

        if hasPeakHour || weekTotal > 0 {
            let peakHourLabel: String = if let peakEntry {
                Self.hourLabel(peakEntry.key)
            } else {
                "--"
            }
            let peakHourTokens = UsageFormatter.tokenCountString(peakEntry?.value ?? 0)

            // Sparkline data: last 12 hours
            let hourlySparkline: [Int] = {
                let nowHour = calendar.component(.hour, from: Date())
                return (0..<12).map { offset in
                    let hour = (nowHour - 11 + offset + 24) % 24
                    return tokensByHour[hour] ?? 0
                }
            }()

            // Sparkline data: last 7 days
            let dailySparkline: [Int] = {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone.current
                var tokensByDay: [String: Int] = [:]
                for d in allDaily { tokensByDay[d.dayKey, default: 0] += d.totals.totalTokens }
                return (0..<7).map { offset in
                    guard let date = calendar.date(byAdding: .day, value: offset - 6, to: todayStart) else { return 0 }
                    return tokensByDay[formatter.string(from: date)] ?? 0
                }
            }()

            let cardsView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
                GlassmorphismStatCardsView(
                    peakHourLabel: peakHourLabel,
                    peakHourTokens: peakHourTokens,
                    hourlySparkline: hourlySparkline,
                    weekTotalTokens: UsageFormatter.tokenCountString(weekTotal),
                    dailySparkline: dailySparkline,
                    width: $0)
            }
            menu.addItem(self.makeMenuCardItem(cardsView, id: "glassStatCards", width: width))
        }

        // Updated timestamp
        let updatedAt: Date? = [
            self.store.snapshot(for: provider)?.updatedAt,
            self.store.ledgerUpdatedAt[provider],
        ].compactMap { $0 }.max()

        if let updatedAt {
            let timestampView = self.menuCardContent(width: width, sidebar: sidebar, showIcons: true) {
                UpdatedTimestampView(updatedAt: updatedAt, width: $0)
            }
            menu.addItem(self.makeMenuCardItem(timestampView, id: "updatedTimestamp", width: width))
        }
    }

    private static func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12AM" }
        if hour < 12 { return "\(hour)AM" }
        if hour == 12 { return "12PM" }
        return "\(hour - 12)PM"
    }

    func makeBuyCreditsItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Buy Credits...", action: #selector(self.openCreditsPurchase), keyEquivalent: "")
        item.target = self
        if let image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            item.image = image
        }
        return item
    }
}
