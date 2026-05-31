import AppKit
import RunicCore
import SwiftUI

struct MenuPopoverActions {
    let installUpdate: () -> Void
    let refresh: () -> Void
    let openDashboard: () -> Void
    let openStatusPage: () -> Void
    let switchAccount: (UsageProvider) -> Void
    let exportCSV: (UsageExporter.Scope) -> Void
    let exportJSON: (UsageExporter.Scope) -> Void
    let openSettings: () -> Void
    let openAbout: () -> Void
    let quit: () -> Void
    let copyError: (String) -> Void
}

@MainActor
struct MenuPopoverView: View {
    @Environment(\.runicFonts) private var fonts
    @Bindable var store: UsageStore
    @Bindable var settings: SettingsStore
    let account: AccountInfo
    let updateReady: Bool
    let width: CGFloat
    let actions: MenuPopoverActions
    let onSelectProvider: (UsageProvider?) -> Void

    @State private var selectedProvider: UsageProvider?
    @State private var selectedPanel: PopoverInsightPanel?
    @State private var selectedTimelineRange: UsageTimelineChartMenuView.TimeRange = .sevenDays
    @State private var hasAppeared = false

    init(
        store: UsageStore,
        settings: SettingsStore,
        account: AccountInfo,
        updateReady: Bool,
        initialProvider: UsageProvider?,
        width: CGFloat,
        actions: MenuPopoverActions,
        onSelectProvider: @escaping (UsageProvider?) -> Void)
    {
        self.store = store
        self.settings = settings
        self.account = account
        self.updateReady = updateReady
        self.width = width
        self.actions = actions
        self.onSelectProvider = onSelectProvider
        self._selectedProvider = State(initialValue: initialProvider)
    }

    var body: some View {
        let palette = self.settings.theme.palette
        let popoverRadius = min(palette.shape.cornerRadius(18), 14)
        let enabledProviders = self.store.enabledProviders()
        let provider = self.effectiveProvider(enabledProviders: enabledProviders)
        let isOverview = provider == nil && enabledProviders.count > 1

        ZStack {
            MenuPopoverBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: RunicSpacing.menuPanelSpacing) {
                    if enabledProviders.count > 1 {
                        self.providerTabs(providers: enabledProviders, selected: provider)
                    }

                    Group {
                        if isOverview {
                            MenuPopoverSurfaceCard {
                                self.overviewView(providers: enabledProviders)
                            }
                        } else if let provider, let model = self.menuCardModel(for: provider) {
                            MenuPopoverSurfaceCard {
                                UsageMenuCardView(model: model, width: self.contentWidth)
                                    .environment(\.menuItemHighlighted, false)
                            }
                        } else {
                            MenuPopoverSurfaceCard {
                                self.emptyProviderState
                            }
                        }
                    }
                    .frame(width: self.contentWidth, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    if let provider, !isOverview {
                        self.insightSection(provider: provider)
                        if let panel = self.effectivePanel(from: self.availablePanels(for: provider)) {
                            self.exportSection(panel: panel)
                        }
                    }

                    self.actionSections(provider: provider, isOverview: isOverview)

                    if palette.id == "retro" {
                        RetroTaglineFooter()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, RunicSpacing.xs)
                    }
                }
                .padding(.horizontal, self.outerHorizontalPadding)
                .padding(.top, self.outerVerticalPadding)
                .padding(.bottom, self.outerVerticalPadding)
            }
        }
        .frame(width: self.width, height: 680)
        .environment(\.runicTheme, palette)
        .runicColorScheme(palette)
        .runicTypography()
        .foregroundStyle(palette.primaryText)
        .tint(palette.accent)
        .clipShape(RoundedRectangle(cornerRadius: popoverRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: popoverRadius, style: .continuous)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: palette.style.chrome.borderWeight,
                        dash: []))
                .foregroundStyle(palette.cardStroke.opacity(palette.style.chrome.borderOpacity))
        }
        .retroBevel(baseRadius: popoverRadius)
        .shadow(
            color: Color.black.opacity(palette.id == "retro" ? 0.22 : 0.24 + palette.style.effects.glowStrength * 0.12),
            radius: palette.shape.separator == .glow ? 22 : (palette.id == "retro" ? 12 : 20),
            y: palette.shape.separator == .glow ? 14 : (palette.id == "retro" ? 6 : 10))
        .onAppear {
            withAnimation(palette.motion.curve) {
                self.hasAppeared = true
            }
            self.store.ensureLedgerHistoryCovers(days: self.selectedTimelineRange.days)
        }
        .onChange(of: self.selectedTimelineRange) { _, range in
            self.store.ensureLedgerHistoryCovers(days: range.days)
        }
        .animation(palette.motion.curve, value: self.selectedProvider)
        .animation(palette.motion.curve, value: self.selectedPanel)
    }

    private var contentWidth: CGFloat {
        max(0, self.width - (self.outerHorizontalPadding * 2))
    }

    private var outerHorizontalPadding: CGFloat {
        self.settings.theme.palette.density.padding(RunicSpacing.menuOuterInset)
    }

    private var outerVerticalPadding: CGFloat {
        self.settings.theme.palette.density.padding(RunicSpacing.menuPanelSpacing)
    }

    private var panelInset: CGFloat {
        self.settings.theme.palette.density.padding(RunicSpacing.menuPanelInset)
    }

    private var panelContentWidth: CGFloat {
        max(0, self.contentWidth - (self.panelInset * 2))
    }

    private var panelBodyWidth: CGFloat {
        max(0, self.panelContentWidth - (RunicSpacing.menuPanelBodyInset * 2))
    }

    private var emptyProviderState: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(spacing: RunicSpacing.xs) {
                RunicThemedSystemIcon(
                    systemName: "sparkles",
                    intent: .info,
                    font: self.fonts.subheadline.weight(.semibold),
                    width: RunicSpacing.menuIconColumnWidth)
                Text("No active providers")
                    .font(self.fonts.subheadline.weight(.semibold))
            }
            Text("Open Settings, enable a provider, then refresh.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.settings.theme.palette.secondaryText)
        }
        .padding(self.panelInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func effectiveProvider(enabledProviders: [UsageProvider]) -> UsageProvider? {
        if enabledProviders.count > 1, self.selectedProvider == nil {
            return nil
        }
        if let selectedProvider, enabledProviders.contains(selectedProvider) {
            return selectedProvider
        }
        return enabledProviders.first ?? .codex
    }

    private func selectProvider(_ provider: UsageProvider?) {
        self.selectedProvider = provider
        self.selectedPanel = nil
        self.onSelectProvider(provider)
    }

    private func providerTabs(providers: [UsageProvider], selected: UsageProvider?) -> some View {
        let tabs = self.providerTabItems(providers: providers, selected: selected)
        return ProviderTabBarView(
            tabs: tabs,
            width: self.contentWidth,
            onSelect: { provider in
                self.selectProvider(provider)
            })
            .clipShape(RoundedRectangle(
                cornerRadius: self.settings.theme.palette.shape.cornerRadius(RunicCornerRadius.lg),
                style: .continuous))
            .overlay {
                RoundedRectangle(
                    cornerRadius: self.settings.theme.palette.shape.cornerRadius(RunicCornerRadius.lg),
                    style: .continuous)
                    .stroke(
                        self.settings.theme.palette.cardStroke.opacity(
                            self.settings.theme.palette.style.chrome.borderOpacity * 0.7),
                        lineWidth: self.settings.theme.palette.style.chrome.borderWeight)
            }
            .frame(width: self.contentWidth, alignment: .leading)
    }

    private func providerTabItems(
        providers: [UsageProvider],
        selected: UsageProvider?) -> [ProviderTabBarView.TabItem]
    {
        var tabs: [ProviderTabBarView.TabItem] = [
            ProviderTabBarView.TabItem(
                id: "overview",
                label: "Overview",
                icon: nil,
                provider: nil,
                isSelected: selected == nil,
                brandColor: self.settings.theme.palette.accent),
        ]

        for provider in providers {
            let meta = self.store.metadata(for: provider)
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            tabs.append(ProviderTabBarView.TabItem(
                id: provider.rawValue,
                label: Self.abbreviatedProviderName(meta.displayName),
                icon: ProviderBrandIcon.image(for: provider, size: 24),
                provider: provider,
                isSelected: selected == provider,
                brandColor: Color(
                    red: Double(descriptor.branding.color.red),
                    green: Double(descriptor.branding.color.green),
                    blue: Double(descriptor.branding.color.blue))))
        }

        return tabs
    }

    private func overviewView(providers: [UsageProvider]) -> some View {
        let model = self.overviewModel(providers: providers)
        return OverviewMenuView(
            summaries: model.summaries,
            chartPoints: model.chartPoints,
            totalTodayTokens: model.totalTodayTokens,
            totalProviders: providers.count,
            width: self.contentWidth)
    }

    private func insightSection(provider: UsageProvider) -> some View {
        let panels = self.availablePanels(for: provider)
        let effectivePanel = self.effectivePanel(from: panels)

        return Group {
            if !panels.isEmpty, let effectivePanel {
                MenuPopoverSurfaceCard {
                    VStack(alignment: .leading, spacing: RunicSpacing.menuControlSpacing) {
                        HStack {
                            RetroSectionHeader(text: "Explore")
                                .padding(.horizontal, RunicSpacing.menuSectionHeaderInset)
                            Spacer()
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: RunicSpacing.menuControlSpacing),
                                GridItem(.flexible(), spacing: RunicSpacing.menuControlSpacing),
                            ],
                            spacing: RunicSpacing.menuControlSpacing)
                        {
                            ForEach(panels) { panel in
                                MenuPopoverChip(
                                    title: panel.title,
                                    systemImage: panel.systemImage,
                                    iconIntent: panel.iconIntent,
                                    isSelected: panel == effectivePanel)
                                {
                                    self.selectedPanel = panel
                                }
                            }
                        }
                        .padding(.horizontal, RunicSpacing.menuPanelBodyInset)

                        let chartStyleID = effectivePanel == .timeline ? self.settings.chartStyle.id : "fixed"
                        self.chartContent(panel: effectivePanel, provider: provider)
                            .id("\(provider.rawValue)-\(effectivePanel.id)-\(chartStyleID)")
                            .clipShape(RoundedRectangle(
                                cornerRadius: self.settings.theme.palette.shape.cornerRadius(RunicCornerRadius.md),
                                style: .continuous))
                            .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                            .padding(.horizontal, RunicSpacing.menuPanelBodyInset)
                    }
                    .padding(self.panelInset)
                }
                .frame(width: self.contentWidth, alignment: .leading)
            }
        }
    }

    private func exportSection(panel: PopoverInsightPanel) -> some View {
        let scope = UsageExporter.Scope(panel: panel, timelineRange: self.selectedTimelineRange)
        return MenuPopoverSurfaceCard {
            VStack(alignment: .leading, spacing: RunicSpacing.menuControlSpacing) {
                RetroSectionHeader(text: "Export visible \(scope.displayName)")
                    .padding(.horizontal, RunicSpacing.menuSectionHeaderInset)
                HStack(spacing: RunicSpacing.menuControlSpacing) {
                    MenuPopoverActionButton(
                        title: "CSV",
                        systemImage: "tablecells",
                        iconIntent: .data,
                        style: .compact,
                        action: { self.actions.exportCSV(scope) })
                        .frame(maxWidth: .infinity)
                    MenuPopoverActionButton(
                        title: "JSON",
                        systemImage: "curlybraces",
                        iconIntent: .data,
                        style: .compact,
                        action: { self.actions.exportJSON(scope) })
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, RunicSpacing.menuPanelBodyInset)
                Text("Exports the selected Explore panel and range.")
                    .font(self.fonts.caption2)
                    .foregroundStyle(self.settings.theme.palette.secondaryText)
                    .padding(.horizontal, RunicSpacing.menuSectionHeaderInset)
            }
            .padding(self.panelInset)
        }
        .frame(width: self.contentWidth, alignment: .leading)
    }

    private func actionSections(provider: UsageProvider?, isOverview: Bool) -> some View {
        let descriptor = MenuDescriptor.build(
            provider: provider,
            store: self.store,
            settings: self.settings,
            account: self.account,
            updateReady: self.updateReady)
        let sections = descriptor.sections.filter { section in
            section.entries.contains { entry in
                if case .action = entry { return true }
                return false
            }
        }

        return VStack(alignment: .leading, spacing: RunicSpacing.menuPanelSpacing) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                MenuPopoverSurfaceCard {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        ForEach(Array(section.entries.enumerated()), id: \.offset) { _, entry in
                            self.actionEntry(entry, provider: provider, isOverview: isOverview)
                        }
                    }
                    .padding(self.panelInset)
                }
            }
        }
        .frame(width: self.contentWidth, alignment: .leading)
    }

    @ViewBuilder
    private func actionEntry(
        _ entry: MenuDescriptor.Entry,
        provider: UsageProvider?,
        isOverview: Bool) -> some View
    {
        switch entry {
        case let .action(title, action):
            if self.shouldRender(action: action, isOverview: isOverview) {
                MenuPopoverActionButton(
                    title: title,
                    systemImage: self.systemImage(for: action),
                    iconIntent: action.iconIntent,
                    action: {
                        self.perform(action, provider: provider)
                    })
            }
        case let .text(text, style):
            HStack(spacing: RunicSpacing.menuActionIconTextSpacing) {
                Color.clear.frame(width: RunicSpacing.menuActionIconColumnWidth, height: 1)
                Text(text)
                    .font(style == .headline
                        ? self.fonts.caption.weight(.semibold)
                        : self.fonts.caption)
                    .foregroundStyle(style == .secondary
                        ? self.settings.theme.palette.secondaryText
                        : self.settings.theme.palette.primaryText)
                    .lineLimit(2)
                    .lineSpacing(self.settings.theme.palette.isTerminalHUD ? RunicSpacing.xxxs : 0)
                    .truncationMode(.tail)
                Spacer(minLength: RunicSpacing.menuControlSpacing)
            }
            .padding(.horizontal, 0)
            .padding(.vertical, RunicSpacing.xxxs)
        case .divider:
            RunicDivider().padding(.vertical, RunicSpacing.xxxs)
        }
    }

    private func shouldRender(action: MenuDescriptor.MenuAction, isOverview: Bool) -> Bool {
        guard isOverview else { return true }
        switch action {
        case .switchAccount, .dashboard, .statusPage:
            return false
        case .installUpdate, .refresh, .settings, .about, .quit, .copyError:
            return true
        }
    }

    private func systemImage(for action: MenuDescriptor.MenuAction) -> String? {
        switch action {
        case .installUpdate: "arrow.down.circle"
        case .settings: "gearshape"
        case .about: "info.circle"
        case .quit: "power"
        default: action.systemImageName
        }
    }

    private func perform(_ action: MenuDescriptor.MenuAction, provider: UsageProvider?) {
        switch action {
        case .installUpdate:
            self.actions.installUpdate()
        case .refresh:
            self.actions.refresh()
        case .dashboard:
            self.actions.openDashboard()
        case .statusPage:
            self.actions.openStatusPage()
        case let .switchAccount(target):
            self.actions.switchAccount(target)
        case .settings:
            self.actions.openSettings()
        case .about:
            self.actions.openAbout()
        case .quit:
            self.actions.quit()
        case let .copyError(message):
            self.actions.copyError(message)
        }
    }

    private func availablePanels(for provider: UsageProvider) -> [PopoverInsightPanel] {
        var panels: [PopoverInsightPanel] = []
        let daily = self.store.ledgerAllDailySummary(for: provider)
        let hourly = self.store.ledgerHourlySummary(for: provider)
        let todayTokens = self.store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0
        let snapshot = self.store.snapshot(for: provider)

        if !daily.isEmpty || !hourly.isEmpty { panels.append(.timeline) }
        if !hourly.isEmpty { panels.append(.hourly) }
        if !daily.isEmpty { panels.append(.weekly) }
        if !daily.isEmpty, todayTokens > 0 { panels.append(.utilization) }
        if !daily.isEmpty,
           todayTokens > 0,
           let snapshot,
           snapshot.primary.usedPercent > 0 || (snapshot.secondary?.usedPercent ?? 0) > 0
        {
            panels.append(.windows)
        }
        if !self.store.ledgerProjectBreakdown(for: provider).isEmpty { panels.append(.projects) }
        if !self.store.ledgerModelBreakdown(for: provider).isEmpty || !self.modelQuotaWindows(for: provider).isEmpty {
            panels.append(.models)
        }
        return panels
    }

    private func effectivePanel(from panels: [PopoverInsightPanel]) -> PopoverInsightPanel? {
        if let selectedPanel, panels.contains(selectedPanel) {
            return selectedPanel
        }
        return panels.first
    }

    @ViewBuilder
    private func chartContent(panel: PopoverInsightPanel, provider: UsageProvider) -> some View {
        switch panel {
        case .timeline:
            UsageTimelineChartMenuView(
                dailySummaries: self.store.ledgerAllDailySummary(for: provider),
                hourlySummaries: self.store.ledgerHourlySummary(for: provider),
                width: self.panelBodyWidth,
                chartStyle: self.settings.chartStyle,
                selectedTimeRange: self.$selectedTimelineRange,
                onRangeChange: { range in
                    self.store.ensureLedgerHistoryCovers(days: range.days)
                })
        case .hourly:
            HourlyActivityChartMenuView(
                hourlySummaries: self.store.ledgerHourlySummary(for: provider),
                width: self.panelBodyWidth)
        case .weekly:
            WeeklyActivityChartMenuView(
                dailySummaries: self.store.ledgerAllDailySummary(for: provider),
                width: self.panelBodyWidth)
        case .utilization:
            SubscriptionUtilizationChartMenuView(
                dailySummaries: self.store.ledgerAllDailySummary(for: provider),
                currentUsedPercent: self.store.snapshot(for: provider)?.primary.usedPercent ?? 0,
                todayTokens: self.store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0,
                width: self.panelBodyWidth)
        case .windows:
            let snapshot = self.store.snapshot(for: provider)
            UsageWindowComparisonChartMenuView(
                dailySummaries: self.store.ledgerAllDailySummary(for: provider),
                primaryLabel: snapshot?.primary.label ?? snapshot?.primary.resetDescription ?? "Session",
                secondaryLabel: snapshot?.secondary?.label ?? snapshot?.secondary?.resetDescription,
                primaryPercent: snapshot?.primary.usedPercent ?? 0,
                secondaryPercent: snapshot?.secondary?.usedPercent,
                width: self.panelBodyWidth)
        case .projects:
            ProjectBreakdownMenuView(
                breakdown: self.store.ledgerProjectBreakdown(for: provider),
                width: self.panelBodyWidth)
        case .models:
            let breakdown = self.store.ledgerModelBreakdown(for: provider)
            if breakdown.isEmpty {
                ModelQuotaWindowsPopoverView(
                    windows: self.modelQuotaWindows(for: provider),
                    width: self.panelBodyWidth)
            } else {
                ModelBreakdownMenuView(breakdown: breakdown, width: self.panelBodyWidth)
            }
        }
    }

    private func menuCardModel(for provider: UsageProvider) -> UsageMenuCardView.Model? {
        let metadata = self.store.metadata(for: provider)
        let snapshot = self.store.snapshot(for: provider)
        let ledgerTopModel = self.store.ledgerTopModel(for: provider)
        let providerContextStatus = ledgerTopModel.flatMap {
            ProviderContextWindowRegistry.shared.contextLabel(for: provider, model: $0.model)
        } ?? ProviderContextWindowRegistry.shared.contextLabel(for: provider)
        let ledgerTopModelContextLabel = providerContextStatus?.text
        let credits: CreditsSnapshot? = provider == .codex ? self.store.credits : nil
        let creditsError: String? = provider == .codex ? self.store.lastCreditsError : nil
        let dashboard: OpenAIDashboardSnapshot? = provider == .codex && !self.store.openAIDashboardRequiresLogin
            ? self.store.openAIDashboard
            : nil
        let dashboardError: String? = provider == .codex ? self.store.lastOpenAIDashboardError : nil

        let input = UsageMenuCardView.Model.Input(
            provider: provider,
            metadata: metadata,
            snapshot: snapshot,
            credits: credits,
            creditsError: creditsError,
            dashboard: dashboard,
            dashboardError: dashboardError,
            tokenSnapshot: self.store.tokenSnapshot(for: provider),
            tokenError: self.store.tokenError(for: provider),
            ledgerDaily: self.store.ledgerDailySummary(for: provider),
            ledgerActiveBlock: self.store.ledgerActiveBlock(for: provider),
            ledgerTopModel: ledgerTopModel,
            ledgerTopModelContextLabel: ledgerTopModelContextLabel,
            ledgerTopProject: self.store.ledgerTopProject(for: provider),
            ledgerSpendForecast: self.store.ledgerSpendForecast(for: provider),
            ledgerTopProjectSpendForecast: self.store.ledgerTopProjectSpendForecast(for: provider),
            ledgerAnomaly: self.store.ledgerAnomalySummary(for: provider),
            ledgerCompaction: self.store.ledgerCompactionSummary(for: provider),
            ledgerReliability: self.store.ledgerReliabilityScore(for: provider),
            ledgerRouting: self.store.ledgerRoutingRecommendation(for: provider),
            ledgerError: self.store.ledgerError(for: provider),
            ledgerUpdatedAt: self.store.ledgerUpdatedAt(for: provider),
            providerContextStatus: providerContextStatus,
            account: self.account,
            isRefreshing: self.store.isRefreshing,
            lastError: self.store.error(for: provider),
            usageBarsShowUsed: self.settings.usageBarsShowUsed,
            usageMetricDisplayMode: self.settings.usageMetricDisplayMode,
            menuMode: self.settings.menuMode,
            tokenCostUsageEnabled: self.settings.isCostUsageEffectivelyEnabled(for: provider),
            showOptionalCreditsAndExtraUsage: self.settings.showOptionalCreditsAndExtraUsage,
            now: Date())
        return UsageMenuCardView.Model.make(input)
    }

    private func overviewModel(providers: [UsageProvider])
        -> (
            summaries: [OverviewMenuView.ProviderSummary],
            chartPoints: [OverviewMenuView.DailyPoint],
            totalTodayTokens: Int)
    {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        var summaries: [OverviewMenuView.ProviderSummary] = []
        var chartPoints: [OverviewMenuView.DailyPoint] = []
        var totalToday = 0

        for provider in providers {
            let meta = self.store.metadata(for: provider)
            let snapshot = self.store.snapshot(for: provider)
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let brandColor = Color(
                red: Double(descriptor.branding.color.red),
                green: Double(descriptor.branding.color.green),
                blue: Double(descriptor.branding.color.blue))
            let todayTokens = self.store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0
            totalToday += todayTokens
            let topModel = self.store.ledgerTopModel(for: provider)
            let context = ProviderContextWindowRegistry.shared.contextLabel(for: provider, model: topModel?.model)?.text

            summaries.append(OverviewMenuView.ProviderSummary(
                id: provider.rawValue,
                provider: provider,
                name: meta.displayName,
                icon: ProviderBrandIcon.image(for: provider, size: 20),
                usedPercent: snapshot?.primary.usedPercent ?? 0,
                todayTokens: todayTokens,
                brandColor: brandColor,
                resetDescription: snapshot?.primary.resetDescription,
                windowLabel: snapshot?.primary.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                topModelContext: context))

            for summary in self.store.ledgerAllDailySummary(for: provider) where summary.dayStart >= weekAgo {
                chartPoints.append(OverviewMenuView.DailyPoint(
                    id: "\(provider.rawValue)-\(summary.dayKey)",
                    date: summary.dayStart,
                    tokens: summary.totals.totalTokens,
                    provider: meta.displayName,
                    color: brandColor))
            }
        }

        let activeSummaries = summaries.filter { $0.usedPercent > 0 || $0.todayTokens > 0 }
        return (activeSummaries.isEmpty ? summaries : activeSummaries, chartPoints, totalToday)
    }

    private func modelQuotaWindows(for provider: UsageProvider) -> [RateWindow] {
        guard let snapshot = self.store.snapshot(for: provider) else { return [] }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self)
        var seen: Set<String> = []
        var result: [RateWindow] = []

        for window in windows {
            guard let label = window.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty
            else { continue }
            guard seen.insert(label.lowercased()).inserted else { continue }
            result.append(window)
        }

        return result
    }

    private static func abbreviatedProviderName(_ name: String) -> String {
        if name.count <= 8 { return name }
        let abbreviations: [String: String] = [
            "Antigravity": "AntiG",
            "OpenRouter": "ORouter",
            "Perplexity": "Perplx",
            "SambaNova": "SambaN",
            "Azure OpenAI": "Azure",
        ]
        return abbreviations[name] ?? String(name.prefix(6))
    }
}
