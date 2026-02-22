import AppKit
import RunicCore
import SwiftUI

// MARK: - Menu helper types & hosting views

extension StatusItemController {
    struct OpenAIWebMenuItems {
        let hasUsageBreakdown: Bool
        let hasCreditsHistory: Bool
        let hasCostHistory: Bool
    }

    struct MenuCardSidebarConfig {
        let providers: [UsageProvider]
        let selected: UsageProvider?
        let iconProvider: (UsageProvider, CGFloat) -> NSImage
        let weeklyRemainingProvider: (UsageProvider) -> Double?
        let onSelect: (UsageProvider) -> Void
    }

    @MainActor
    protocol MenuCardHighlighting: AnyObject {
        func setHighlighted(_ highlighted: Bool)
    }

    @MainActor
    protocol MenuCardMeasuring: AnyObject {
        func measuredHeight(width: CGFloat) -> CGFloat
    }

    @MainActor
    @Observable
    final class MenuCardHighlightState {
        var isHighlighted = false
    }

    final class MenuHostingView<Content: View>: NSHostingView<Content> {
        override var allowsVibrancy: Bool { true }
        override var isOpaque: Bool { false }
    }

    @MainActor
    final class MenuCardItemHostingView<Content: View>: NSHostingView<Content>, MenuCardHighlighting,
    MenuCardMeasuring {
        private let highlightState: MenuCardHighlightState
        override var allowsVibrancy: Bool { true }
        override var isOpaque: Bool { false }

        override var intrinsicContentSize: NSSize {
            let size = super.intrinsicContentSize
            guard self.frame.width > 0 else { return size }
            return NSSize(width: self.frame.width, height: size.height)
        }

        init(rootView: Content, highlightState: MenuCardHighlightState) {
            self.highlightState = highlightState
            super.init(rootView: rootView)
            self.layer?.backgroundColor = nil
        }

        required init(rootView: Content) {
            self.highlightState = MenuCardHighlightState()
            super.init(rootView: rootView)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func measuredHeight(width: CGFloat) -> CGFloat {
            let controller = NSHostingController(rootView: self.rootView)
            let measured = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            return measured.height
        }

        func setHighlighted(_ highlighted: Bool) {
            guard self.highlightState.isHighlighted != highlighted else { return }
            self.highlightState.isHighlighted = highlighted
        }
    }

    struct MenuCardSectionContainerView<Content: View>: View {
        @Bindable var highlightState: MenuCardHighlightState
        let showsSubmenuIndicator: Bool
        let content: Content

        init(
            highlightState: MenuCardHighlightState,
            showsSubmenuIndicator: Bool,
            @ViewBuilder content: () -> Content)
        {
            self.highlightState = highlightState
            self.showsSubmenuIndicator = showsSubmenuIndicator
            self.content = content()
        }

        var body: some View {
            self.content
                .environment(\.menuItemHighlighted, self.highlightState.isHighlighted)
                .foregroundStyle(MenuHighlightStyle.primary(self.highlightState.isHighlighted))
                .background(alignment: .topLeading) {
                    if self.highlightState.isHighlighted {
                        RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                            .fill(MenuHighlightStyle.selectionBackground(true))
                            .padding(.horizontal, RunicSpacing.compact)
                            .padding(.vertical, RunicSpacing.xxxs)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if self.showsSubmenuIndicator {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(MenuHighlightStyle.secondary(self.highlightState.isHighlighted))
                            .padding(.top, RunicSpacing.xs)
                            .padding(.trailing, RunicSpacing.xs)
                    }
                }
        }
    }

    @MainActor
    final class MenuActionButtonView: NSView, MenuCardHighlighting {
        private let iconView = NSImageView()
        private let titleField: NSTextField
        private let stack = NSStackView()
        private let highlightLayer = CALayer()
        private let onSelect: () -> Void
        private var isHighlighted = false

        init(title: String, image: NSImage?, onSelect: @escaping () -> Void) {
            self.titleField = NSTextField(labelWithString: title)
            self.onSelect = onSelect
            super.init(frame: .zero)
            self.wantsLayer = true
            self.layer?.insertSublayer(self.highlightLayer, at: 0)
            self.highlightLayer.cornerRadius = CGFloat(RunicCornerRadius.sm)

            self.iconView.image = image
            self.iconView.contentTintColor = NSColor.secondaryLabelColor
            self.iconView.imageScaling = .scaleNone
            self.iconView.translatesAutoresizingMaskIntoConstraints = false

            self.titleField.font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
            self.titleField.lineBreakMode = .byTruncatingTail
            self.titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            self.stack.orientation = .horizontal
            self.stack.alignment = .centerY
            self.stack.spacing = 6
            self.stack.translatesAutoresizingMaskIntoConstraints = false
            if image != nil {
                self.stack.addArrangedSubview(self.iconView)
            }
            self.stack.addArrangedSubview(self.titleField)
            self.addSubview(self.stack)

            var constraints: [NSLayoutConstraint] = [
                self.stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 18),
                self.stack.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -10),
                self.stack.topAnchor.constraint(equalTo: self.topAnchor, constant: 2),
                self.stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -2),
            ]

            if image != nil {
                constraints.append(self.iconView.widthAnchor.constraint(equalToConstant: 16))
                constraints.append(self.iconView.heightAnchor.constraint(equalToConstant: 16))
            }

            NSLayoutConstraint.activate(constraints)

            let click = NSClickGestureRecognizer(target: self, action: #selector(self.handleClick))
            self.addGestureRecognizer(click)
            self.updateColors()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func layout() {
            super.layout()
            self.highlightLayer.frame = self.bounds.insetBy(dx: 6, dy: 2)
        }

        override var intrinsicContentSize: NSSize {
            let size = self.stack.fittingSize
            return NSSize(width: size.width + 28, height: size.height + 4)
        }

        func setHighlighted(_ highlighted: Bool) {
            self.isHighlighted = highlighted
            self.updateColors()
        }

        private func updateColors() {
            let textColor = self.isHighlighted ? NSColor.selectedMenuItemTextColor : NSColor.controlTextColor
            let iconColor = self.isHighlighted ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor
            self.titleField.textColor = textColor
            if self.iconView.image?.isTemplate == true {
                self.iconView.contentTintColor = iconColor
            } else {
                self.iconView.contentTintColor = nil
            }
            self.highlightLayer.backgroundColor = self.isHighlighted
                ? NSColor.selectedContentBackgroundColor.cgColor
                : NSColor.clear.cgColor
        }

        @objc private func handleClick() {
            self.onSelect()
        }
    }

    // MARK: - Sidebar content builder

    @ViewBuilder
    func menuCardContent<Content: View>(
        width: CGFloat,
        sidebar: MenuCardSidebarConfig?,
        showIcons: Bool,
        @ViewBuilder content: @escaping (CGFloat) -> Content) -> some View
    {
        if let sidebar {
            ProviderSidebarMenuCardView(
                providers: sidebar.providers,
                selected: sidebar.selected,
                totalWidth: width,
                showIcons: showIcons,
                iconSize: self.settings.providerSwitcherIconSize,
                iconProvider: sidebar.iconProvider,
                weeklyRemainingProvider: sidebar.weeklyRemainingProvider,
                onSelect: sidebar.onSelect,
                content: content)
        } else {
            content(width)
        }
    }

    // MARK: - Menu card model

    func menuCardModel(for provider: UsageProvider?) -> UsageMenuCardView.Model? {
        let target = provider ?? self.store.enabledProviders().first ?? .codex
        let metadata = self.store.metadata(for: target)

        let snapshot = self.store.snapshot(for: target)
        let credits: CreditsSnapshot?
        let creditsError: String?
        let dashboard: OpenAIDashboardSnapshot?
        let dashboardError: String?
        let tokenSnapshot: CostUsageTokenSnapshot?
        let tokenError: String?
        let ledgerDaily = self.store.ledgerDailySummary(for: target)
        let ledgerActiveBlock = self.store.ledgerActiveBlock(for: target)
        let ledgerTopModel = self.store.ledgerTopModel(for: target)
        let ledgerTopProject = self.store.ledgerTopProject(for: target)
        let ledgerSpendForecast = self.store.ledgerSpendForecast(for: target)
        let ledgerTopProjectSpendForecast = self.store.ledgerTopProjectSpendForecast(for: target)
        let ledgerAnomaly = self.store.ledgerAnomalySummary(for: target)
        let ledgerReliability = self.store.ledgerReliabilityScore(for: target)
        let ledgerRouting = self.store.ledgerRoutingRecommendation(for: target)
        let ledgerError = self.store.ledgerError(for: target)
        let ledgerUpdatedAt = self.store.ledgerUpdatedAt(for: target)
        if target == .codex {
            credits = self.store.credits
            creditsError = self.store.lastCreditsError
            dashboard = self.store.openAIDashboardRequiresLogin ? nil : self.store.openAIDashboard
            dashboardError = self.store.lastOpenAIDashboardError
            tokenSnapshot = self.store.tokenSnapshot(for: target)
            tokenError = self.store.tokenError(for: target)
        } else if target == .claude {
            credits = nil
            creditsError = nil
            dashboard = nil
            dashboardError = nil
            tokenSnapshot = self.store.tokenSnapshot(for: target)
            tokenError = self.store.tokenError(for: target)
        } else {
            credits = nil
            creditsError = nil
            dashboard = nil
            dashboardError = nil
            tokenSnapshot = nil
            tokenError = nil
        }

        let input = UsageMenuCardView.Model.Input(
            provider: target,
            metadata: metadata,
            snapshot: snapshot,
            credits: credits,
            creditsError: creditsError,
            dashboard: dashboard,
            dashboardError: dashboardError,
            tokenSnapshot: tokenSnapshot,
            tokenError: tokenError,
            ledgerDaily: ledgerDaily,
            ledgerActiveBlock: ledgerActiveBlock,
            ledgerTopModel: ledgerTopModel,
            ledgerTopProject: ledgerTopProject,
            ledgerSpendForecast: ledgerSpendForecast,
            ledgerTopProjectSpendForecast: ledgerTopProjectSpendForecast,
            ledgerAnomaly: ledgerAnomaly,
            ledgerReliability: ledgerReliability,
            ledgerRouting: ledgerRouting,
            ledgerError: ledgerError,
            ledgerUpdatedAt: ledgerUpdatedAt,
            account: self.account,
            isRefreshing: self.store.isRefreshing,
            lastError: self.store.error(for: target),
            usageBarsShowUsed: self.settings.usageBarsShowUsed,
            usageMetricDisplayMode: self.settings.usageMetricDisplayMode,
            menuMode: self.settings.menuMode,
            tokenCostUsageEnabled: self.settings.isCostUsageEffectivelyEnabled(for: target),
            showOptionalCreditsAndExtraUsage: self.settings.showOptionalCreditsAndExtraUsage,
            now: Date())
        return UsageMenuCardView.Model.make(input)
    }

    // MARK: - Persistent refresh item

    func makePersistentRefreshItem(title: String) -> NSMenuItem {
        let image = NSImage(
            systemSymbolName: MenuDescriptor.MenuActionSystemImage.refresh.rawValue,
            accessibilityDescription: nil) ?? NSImage(
                systemSymbolName: "arrow.triangle.2.circlepath",
                accessibilityDescription: nil)
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
        let view = MenuActionButtonView(title: title, image: image) { [weak self] in
            self?.refreshNow()
        }
        let size = view.fittingSize
        if size.height <= 1 {
            let fallback = NSMenuItem(title: title, action: #selector(self.refreshNow), keyEquivalent: "")
            fallback.target = self
            fallback.image = image
            return fallback
        }
        view.frame = NSRect(origin: .zero, size: size)
        let item = NSMenuItem()
        item.view = view
        item.isEnabled = true
        return item
    }

    // MARK: - Subtitle helpers

    func applySubtitle(_ subtitle: String, to item: NSMenuItem, title: String) {
        if #available(macOS 14.4, *) {
            item.subtitle = subtitle
        } else {
            item.view = self.makeMenuSubtitleView(title: title, subtitle: subtitle, isEnabled: item.isEnabled)
            item.toolTip = "\(title) — \(subtitle)"
        }
    }

    private func makeMenuSubtitleView(title: String, subtitle: String, isEnabled: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.alphaValue = isEnabled ? 1.0 : 0.7

        let titleField = NSTextField(labelWithString: title)
        titleField.font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
        titleField.textColor = NSColor.labelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let subtitleField = NSTextField(labelWithString: subtitle)
        subtitleField.font = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)
        subtitleField.textColor = NSColor.secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingTail
        subtitleField.maximumNumberOfLines = 1
        subtitleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [titleField, subtitleField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
        ])

        return container
    }
}
