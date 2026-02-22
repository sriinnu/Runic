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
