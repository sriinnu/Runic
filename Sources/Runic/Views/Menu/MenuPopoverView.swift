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
        let enabledProviders = self.store.enabledProviders()
        let provider = self.effectiveProvider(enabledProviders: enabledProviders)
        let isOverview = provider == nil && enabledProviders.count > 1

        ZStack {
            MenuPopoverBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
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
                        self.exportSection(provider: provider)
                    }

                    self.actionSections(provider: provider, isOverview: isOverview)
                }
                .padding(.horizontal, self.outerHorizontalPadding)
                .padding(.top, RunicSpacing.sm)
                .padding(.bottom, RunicSpacing.md)
            }
        }
        .frame(width: self.width, height: 680)
        .environment(\.runicTheme, palette)
        .runicColorScheme(palette)
        .runicTypography()
        .foregroundStyle(palette.primaryText)
        .tint(palette.accent)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.cardStroke.opacity(palette.isTerminalHUD ? 0.55 : 0.72), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.24), radius: 24, y: 12)
        .onAppear {
            withAnimation(RunicAnimation.cardEntrance) {
                self.hasAppeared = true
            }
        }
        .animation(RunicAnimation.providerSwitch, value: self.selectedProvider)
        .animation(RunicAnimation.providerSwitch, value: self.selectedPanel)
    }

    private var contentWidth: CGFloat {
        max(0, self.width - (self.outerHorizontalPadding * 2))
    }

    private var outerHorizontalPadding: CGFloat {
        RunicSpacing.md
    }

    private var paddedSurfaceContentWidth: CGFloat {
        max(0, self.contentWidth - (RunicSpacing.xs * 2))
    }

    private var actionLabelLeadingInset: CGFloat {
        RunicSpacing.xs + 18 + RunicSpacing.xs
    }

    private var emptyProviderState: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Label("No active providers", systemImage: "sparkles")
                .font(RunicFont.subheadline.weight(.semibold))
            Text("Open Settings, enable a provider, then refresh.")
                .font(RunicFont.footnote)
                .foregroundStyle(self.settings.theme.palette.secondaryText)
        }
        .padding(RunicSpacing.sm)
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
            .clipShape(RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                    .stroke(self.settings.theme.palette.cardStroke.opacity(0.42), lineWidth: 0.6)
            }
            .frame(width: self.contentWidth, alignment: .leading)
            .scaleEffect(self.hasAppeared ? 1 : 0.98)
            .opacity(self.hasAppeared ? 1 : 0)
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
                    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                        HStack {
                            Text("Explore")
                                .font(RunicFont.caption.weight(.semibold))
                                .foregroundStyle(self.settings.theme.palette.secondaryText)
                            Spacer()
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: RunicSpacing.xs),
                                GridItem(.flexible(), spacing: RunicSpacing.xs),
                            ],
                            spacing: RunicSpacing.xs)
                        {
                            ForEach(panels) { panel in
                                MenuPopoverChip(
                                    title: panel.title,
                                    systemImage: panel.systemImage,
                                    isSelected: panel == effectivePanel)
                                {
                                    self.selectedPanel = panel
                                }
                            }
                        }

                        self.chartContent(panel: effectivePanel, provider: provider)
                            .id("\(provider.rawValue)-\(effectivePanel.id)")
                            .clipShape(RoundedRectangle(cornerRadius: RunicCornerRadius.md, style: .continuous))
                            .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                    }
                    .padding(RunicSpacing.xs)
                }
                .frame(width: self.contentWidth, alignment: .leading)
            }
        }
    }

    private func exportSection(provider: UsageProvider) -> some View {
        let panel = self.effectivePanel(from: self.availablePanels(for: provider)) ?? .timeline
        let scope = UsageExporter.Scope(panel: panel, timelineRange: self.selectedTimelineRange)
        return MenuPopoverSurfaceCard {
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Export visible \(scope.displayName)")
                    .font(RunicFont.caption.weight(.semibold))
                    .foregroundStyle(self.settings.theme.palette.secondaryText)
                HStack(spacing: RunicSpacing.xs) {
                    MenuPopoverActionButton(
                        title: "CSV",
                        systemImage: "tablecells",
                        style: .compact,
                        action: { self.actions.exportCSV(scope) })
                    MenuPopoverActionButton(
                        title: "JSON",
                        systemImage: "curlybraces",
                        style: .compact,
                        action: { self.actions.exportJSON(scope) })
                }
                Text("Exports the selected Explore panel and range.")
                    .font(RunicFont.caption2)
                    .foregroundStyle(self.settings.theme.palette.secondaryText)
            }
            .padding(RunicSpacing.xs)
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

        return VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                MenuPopoverSurfaceCard {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        ForEach(Array(section.entries.enumerated()), id: \.offset) { _, entry in
                            self.actionEntry(entry, provider: provider, isOverview: isOverview)
                        }
                    }
                    .padding(RunicSpacing.xs)
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
                    action: {
                        self.perform(action, provider: provider)
                    })
            }
        case let .text(text, style):
            if style == .secondary {
                Text(text)
                    .font(RunicFont.caption)
                    .foregroundStyle(self.settings.theme.palette.secondaryText)
                    .padding(.leading, self.actionLabelLeadingInset)
                    .padding(.trailing, RunicSpacing.compact)
                    .padding(.vertical, RunicSpacing.xxxs)
            } else {
                Text(text)
                    .font(style == .headline ? RunicFont.caption.weight(.semibold) : RunicFont.caption)
                    .foregroundStyle(self.settings.theme.palette.primaryText)
                    .padding(.leading, self.actionLabelLeadingInset)
                    .padding(.trailing, RunicSpacing.compact)
                    .padding(.vertical, RunicSpacing.xxxs)
            }
        case .divider:
            MenuPopoverSeparator()
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
                width: self.paddedSurfaceContentWidth,
                selectedTimeRange: self.$selectedTimelineRange)
        case .hourly:
            HourlyActivityChartMenuView(
                hourlySummaries: self.store.ledgerHourlySummary(for: provider),
                width: self.paddedSurfaceContentWidth)
        case .weekly:
            WeeklyActivityChartMenuView(
                dailySummaries: self.store.ledgerAllDailySummary(for: provider),
                width: self.paddedSurfaceContentWidth)
        case .utilization:
            SubscriptionUtilizationChartMenuView(
                dailySummaries: self.store.ledgerAllDailySummary(for: provider),
                currentUsedPercent: self.store.snapshot(for: provider)?.primary.usedPercent ?? 0,
                todayTokens: self.store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0,
                width: self.paddedSurfaceContentWidth)
        case .windows:
            let snapshot = self.store.snapshot(for: provider)
            UsageWindowComparisonChartMenuView(
                dailySummaries: self.store.ledgerAllDailySummary(for: provider),
                primaryLabel: snapshot?.primary.label ?? snapshot?.primary.resetDescription ?? "Session",
                secondaryLabel: snapshot?.secondary?.label ?? snapshot?.secondary?.resetDescription,
                primaryPercent: snapshot?.primary.usedPercent ?? 0,
                secondaryPercent: snapshot?.secondary?.usedPercent,
                width: self.paddedSurfaceContentWidth)
        case .projects:
            ProjectBreakdownMenuView(
                breakdown: self.store.ledgerProjectBreakdown(for: provider),
                width: self.paddedSurfaceContentWidth)
        case .models:
            let breakdown = self.store.ledgerModelBreakdown(for: provider)
            if breakdown.isEmpty {
                ModelQuotaWindowsPopoverView(windows: self.modelQuotaWindows(for: provider), width: self.paddedSurfaceContentWidth)
            } else {
                ModelBreakdownMenuView(breakdown: breakdown, width: self.paddedSurfaceContentWidth)
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
        -> (summaries: [OverviewMenuView.ProviderSummary], chartPoints: [OverviewMenuView.DailyPoint], totalTodayTokens: Int)
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

private enum PopoverInsightPanel: String, CaseIterable, Identifiable {
    case timeline
    case hourly
    case weekly
    case utilization
    case windows
    case projects
    case models

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .timeline: "Timeline"
        case .hourly: "Today"
        case .weekly: "7 days"
        case .utilization: "Utilization"
        case .windows: "Windows"
        case .projects: "Projects"
        case .models: "Models"
        }
    }

    var systemImage: String {
        switch self {
        case .timeline: "chart.xyaxis.line"
        case .hourly: "clock"
        case .weekly: "calendar"
        case .utilization: "gauge.with.dots.needle.67percent"
        case .windows: "rectangle.split.2x1"
        case .projects: "folder"
        case .models: "cpu"
        }
    }
}

private extension UsageExporter.Scope {
    init(panel: PopoverInsightPanel, timelineRange: UsageTimelineChartMenuView.TimeRange) {
        switch panel {
        case .timeline:
            self = timelineRange.exportScope
        case .hourly:
            self = .hourly
        case .weekly:
            self = .weekly
        case .utilization:
            self = .utilization
        case .windows:
            self = .windows
        case .projects:
            self = .projects
        case .models:
            self = .models
        }
    }
}

private extension UsageTimelineChartMenuView.TimeRange {
    var exportScope: UsageExporter.Scope {
        switch self {
        case .threeDays: .timeline3d
        case .sevenDays: .timeline7d
        case .thirtyDays: .timeline30d
        case .quarter: .timeline90d
        case .year: .timeline1y
        }
    }
}

private struct MenuPopoverBackground: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        ZStack {
            self.runicTheme.menuSurfaceGradient
            if self.runicTheme.id == "glass" {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.72)
            }
            if self.runicTheme.isTerminalHUD {
                RunicTerminalScanlineOverlay(opacity: 0.22)
                RunicTerminalCornerOverlay(inset: 10, length: 18, lineWidth: 1, opacity: 0.34)
            }
        }
        .ignoresSafeArea()
    }
}

private struct MenuPopoverSurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.runicTheme) private var runicTheme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        self.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                    .fill(self.runicTheme.menuSubtleFill)
                    .background {
                        if self.runicTheme.id == "glass" {
                            RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                                .fill(.thinMaterial)
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                    .stroke(self.runicTheme.cardStroke.opacity(self.runicTheme.isTerminalHUD ? 0.60 : 0.85), lineWidth: 0.7)
            }
    }
}

private struct MenuPopoverSeparator: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Rectangle()
            .fill(self.runicTheme.menuSeparatorColor.opacity(0.72))
            .frame(height: 1)
            .padding(.vertical, RunicSpacing.xxxs)
    }
}

private struct MenuPopoverChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: RunicSpacing.xxs) {
                Image(systemName: self.systemImage)
                    .font(RunicFont.caption.weight(.semibold))
                    .frame(width: 15)
                Text(self.title)
                    .font(RunicFont.caption.weight(self.isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RunicSpacing.compact)
            .padding(.vertical, RunicSpacing.xxs + 1)
            .foregroundStyle(self.foreground)
            .background {
                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                    .fill(self.background)
            }
            .overlay {
                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                    .stroke(self.border, lineWidth: 0.7)
            }
            .scaleEffect(self.isHovered ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(RunicAnimation.hoverFeedback) {
                self.isHovered = hovering
            }
        }
    }

    private var foreground: Color {
        self.isSelected ? self.runicTheme.accent : self.runicTheme.primaryText
    }

    private var background: Color {
        if self.isSelected { return self.runicTheme.accent.opacity(self.runicTheme.isTerminalHUD ? 0.16 : 0.18) }
        if self.isHovered { return self.runicTheme.menuHoverFill }
        return self.runicTheme.cardFill.opacity(0.34)
    }

    private var border: Color {
        self.isSelected
            ? self.runicTheme.accent.opacity(0.64)
            : self.runicTheme.cardStroke.opacity(self.isHovered ? 0.72 : 0.42)
    }
}

private struct MenuPopoverActionButton: View {
    enum Style {
        case normal
        case compact
    }

    let title: String
    let systemImage: String?
    var style: Style = .normal
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: RunicSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(self.iconFont)
                        .frame(width: self.style == .compact ? 16 : 18)
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
                Text(self.title)
                    .font(self.titleFont)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: RunicSpacing.xs)
            }
            .padding(.horizontal, self.style == .compact ? RunicSpacing.compact : RunicSpacing.xs)
            .padding(.vertical, self.style == .compact ? RunicSpacing.xxs : RunicSpacing.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(self.runicTheme.primaryText)
            .background {
                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                    .fill(self.isHovered ? self.runicTheme.menuHoverFill : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(RunicAnimation.hoverFeedback) {
                self.isHovered = hovering
            }
        }
    }

    private var titleFont: Font {
        self.style == .compact ? RunicFont.caption.weight(.medium) : RunicFont.body.weight(.medium)
    }

    private var iconFont: Font {
        self.style == .compact ? RunicFont.caption.weight(.semibold) : RunicFont.body.weight(.medium)
    }
}

private struct ModelQuotaWindowsPopoverView: View {
    let windows: [RateWindow]
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Models")
                .font(RunicFont.caption.weight(.semibold))
            if self.windows.isEmpty {
                Text("No model windows available.")
                    .font(RunicFont.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            } else {
                ForEach(Array(self.windows.enumerated()), id: \.offset) { _, window in
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        HStack {
                            Text(UsageFormatter.modelDisplayName(window.label ?? "Model"))
                                .font(RunicFont.caption.weight(.medium))
                            Spacer()
                            Text("\(Int(window.usedPercent.rounded()))% used")
                                .font(RunicFont.caption)
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }
                        UsageProgressBar(
                            percent: window.usedPercent,
                            tint: self.runicTheme.accent,
                            accessibilityLabel: "Model quota")
                        if let reset = self.resetText(for: window) {
                            Text(reset)
                                .font(RunicFont.caption2)
                                .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private func resetText(for window: RateWindow) -> String? {
        if let resetsAt = window.resetsAt {
            return "Resets \(UsageFormatter.resetCountdownDescription(from: resetsAt))"
        }
        if let reset = window.resetDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !reset.isEmpty {
            return reset.lowercased().hasPrefix("resets") ? reset : "Resets \(reset)"
        }
        return nil
    }
}
