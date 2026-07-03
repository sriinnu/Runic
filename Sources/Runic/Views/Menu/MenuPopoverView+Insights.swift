import RunicCore
import SwiftUI

extension MenuPopoverView {
    func insightSection(provider: UsageProvider) -> some View {
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

    func exportSection(panel: PopoverInsightPanel) -> some View {
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

    func availablePanels(for provider: UsageProvider) -> [PopoverInsightPanel] {
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

    func effectivePanel(from panels: [PopoverInsightPanel]) -> PopoverInsightPanel? {
        if let selectedPanel, panels.contains(selectedPanel) {
            return selectedPanel
        }
        return panels.first
    }

    @ViewBuilder
    func chartContent(panel: PopoverInsightPanel, provider: UsageProvider) -> some View {
        switch panel {
        case .timeline:
            UsageTimelineChartMenuView(
                dailySummaries: self.store.ledgerAllDailySummary(for: provider),
                hourlySummaries: self.store.ledgerHourlySummary(for: provider),
                width: self.panelBodyWidth,
                chartStyle: self.settings.chartStyle,
                numberStyle: self.settings.numberFormat.formatterStyle,
                selectedTimeRange: self.$selectedTimelineRange,
                onRangeChange: { range in
                    self.store.ensureLedgerHistoryCovers(days: range.days)
                })
        case .hourly:
            HourlyActivityChartMenuView(
                hourlySummaries: self.store.ledgerHourlySummary(for: provider),
                width: self.panelBodyWidth,
                numberStyle: self.settings.numberFormat.formatterStyle)
        case .weekly:
            WeeklyActivityChartMenuView(
                dailySummaries: self.store.ledgerAllDailySummary(for: provider),
                width: self.panelBodyWidth,
                numberStyle: self.settings.numberFormat.formatterStyle)
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

    func modelQuotaWindows(for provider: UsageProvider) -> [RateWindow] {
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
}
