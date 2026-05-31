import RunicCore
import SwiftUI

extension ProviderSidebarDetailView {
    var historyCalendarGrid: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            let weekdays = self.weekdaySymbols
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: RunicSpacing.xxs), count: 7),
                spacing: RunicSpacing.xxs)
            {
                ForEach(weekdays, id: \.self) { symbol in
                    Text(symbol)
                        .font(self.fonts.caption2.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: RunicSpacing.xxs), count: 7),
                spacing: RunicSpacing.xxs)
            {
                ForEach(self.calendarDaysForMonth, id: \.self) { day in
                    let inMonth = self.historyCalendar.isDate(
                        day,
                        equalTo: self.historyMonthStart,
                        toGranularity: .month)
                    let normalizedDay = self.historyCalendar.startOfDay(for: day)
                    let summary = self.historySummaryByDay[normalizedDay]
                    let dayNumber = self.historyCalendar.component(.day, from: day)
                    let isSelected = self.historySelectedDay
                        .map { self.historyCalendar.isDate($0, inSameDayAs: day) } ?? false
                    ProviderHistoryCalendarDayCell(
                        dayNumber: dayNumber,
                        isInMonth: inMonth,
                        isSelected: isSelected,
                        hasActivity: summary != nil,
                        intensity: self.historyIntensity(for: summary),
                        action: { self.historySelectedDay = normalizedDay })
                        .help(self.historyDayHelp(for: day, summary: summary))
                }
            }
        }
    }

    var historyDayDetailCard: some View {
        ProviderSidebarSectionCard {
            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: RunicSpacing.xs) {
                    Text("Day details")
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(0.25)
                    Spacer()
                    if self.selectedHistoryDaySummary != nil {
                        Picker("History detail", selection: self.$historyDayDetailMode) {
                            ForEach(ProviderHistoryDayDetailMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.mini)
                        .frame(maxWidth: 240)
                    }
                }

                if let selected = self.selectedHistoryDaySummary {
                    Text(selected.dayStart.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText)

                    if self.historyDayDetailMode == .summary {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 90), spacing: RunicSpacing.xs),
                                GridItem(.flexible(minimum: 90), spacing: RunicSpacing.xs),
                                GridItem(.flexible(minimum: 90), spacing: RunicSpacing.xs),
                            ],
                            alignment: .leading,
                            spacing: RunicSpacing.xs)
                        {
                            ProviderSidebarMetricChip(
                                title: "Requests",
                                value: self.decimalString(selected.requestCount),
                                helpText: "Count of requests recorded in local ledger logs.")
                            ProviderSidebarMetricChip(
                                title: "Tokens",
                                value: UsageFormatter.tokenSummaryString(selected.totals),
                                helpText: "Input, output, and cache token composition.")
                            if let spend = selected.totals.costUSD {
                                ProviderSidebarMetricChip(
                                    title: "Spend",
                                    value: UsageFormatter.usdString(spend),
                                    helpText: "Estimated day spend from ledger pricing.")
                            }
                        }

                        if self.hasModelBreakdown, let topModel = selected.topModel {
                            Text("Top model: \(self.historyModelLine(topModel))")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .textSelection(.enabled)
                        }

                        if self.hasProjectAttribution, let topProject = selected.topProject {
                            let project = self.projectDisplay(topProject)
                            Text("Top project: \(project.title)")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .textSelection(.enabled)
                                .help(project.helpText ?? "")
                        }
                    }

                    if self.historyDayDetailMode == .models {
                        if self.hasModelBreakdown, !selected.modelSummaries.isEmpty {
                            Text("Models used")
                                .font(self.fonts.caption2.weight(.medium))
                                .foregroundStyle(self.runicTheme.secondaryText)
                            ForEach(
                                Array(selected.modelSummaries.prefix(12).enumerated()),
                                id: \.offset)
                            { _, summary in
                                Text("• \(self.historyModelLine(summary))")
                                    .font(self.fonts.caption2)
                                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                                    .textSelection(.enabled)
                                    .help(self.historyModelLine(summary))
                            }
                        } else if self.hasModelBreakdown, !selected.modelsUsed.isEmpty {
                            Text("Models used: \(self.renderedModelsList(selected.modelsUsed).joined(separator: ", "))")
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                                .textSelection(.enabled)
                        } else {
                            Text(self
                                .hasModelBreakdown ? "No models recorded for this day." :
                                "Model attribution is not available for this provider.")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        }
                    }

                    if self.historyDayDetailMode == .projects {
                        if self.hasProjectAttribution, !selected.projectSummaries.isEmpty {
                            Text("Top projects")
                                .font(self.fonts.caption2.weight(.medium))
                                .foregroundStyle(self.runicTheme.secondaryText)
                            ForEach(
                                Array(selected.projectSummaries.prefix(12).enumerated()),
                                id: \.offset)
                            { _, summary in
                                let project = self.projectDisplay(summary)
                                Text("• \(self.historyProjectLine(summary))")
                                    .font(self.fonts.caption2)
                                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                                    .textSelection(.enabled)
                                    .help(project.helpText ?? "")
                            }
                        } else {
                            Text(self
                                .hasProjectAttribution ? "No projects recorded for this day." :
                                "Project attribution is not available for this provider.")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        }
                    }
                } else {
                    Text(self.historySelectedDay?
                        .formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()) ?? "No day selected")
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Text("No recorded activity for this day.")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                }
            }
        }
    }
}
