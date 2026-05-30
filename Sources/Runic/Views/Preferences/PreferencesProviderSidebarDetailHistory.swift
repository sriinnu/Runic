import Foundation
import RunicCore
import SwiftUI

extension ProviderSidebarDetailView {

    var statusBadge: some View {
        let (color, bg) = self.statusColors
        return Text(self.usageStatus.text)
            .font(self.fonts.caption2.weight(.medium))
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxs)
            .background(bg)
            .foregroundStyle(color)
            .clipShape(.capsule)
    }

    var statusColors: (Color, Color) {
        switch self.usageStatus.style {
        case .success: (.green, Color.green.opacity(0.15))
        case .error: (.red, Color.red.opacity(0.15))
        case .neutral: (.secondary, self.runicTheme.menuSubtleFill)
        }
    }

    var historyTaskID: String {
        let monthKey = Int(self.historyMonthStart.timeIntervalSince1970)
        return "\(self.provider.rawValue)-\(self.selectedSubview.rawValue)-\(monthKey)"
    }

    var historyContent: some View {
        ProviderSidebarSectionCard {
            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                HStack(alignment: .center, spacing: RunicSpacing.xs) {
                    ProviderHistoryNavigationButton(
                        systemName: "chevron.left",
                        enabled: true,
                        help: "Previous month")
                    {
                        self.shiftHistoryMonth(by: -1)
                    }

                    Text(self.historyMonthTitle)
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .frame(minWidth: 130, alignment: .leading)

                    ProviderHistoryNavigationButton(
                        systemName: "chevron.right",
                        enabled: self.canShiftHistoryForward,
                        help: "Next month")
                    {
                        self.shiftHistoryMonth(by: 1)
                    }

                    Spacer()

                    Picker("Metric", selection: self.$historyMetricMode) {
                        ForEach(ProviderHistoryMetricMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                if self.historyIsLoading, self.historySnapshot == nil {
                    HStack(spacing: RunicSpacing.xs) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading history…")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }
                    .padding(.vertical, RunicSpacing.xs)
                } else if let snapshot = self.historySnapshot {
                    if !snapshot.isSupported {
                        Text(snapshot.note ?? "History is not available for this provider yet.")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .padding(.vertical, RunicSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                                    style: .continuous)
                                    .fill(self.runicTheme.menuSubtleFill.opacity(
                                        ProviderListMetrics.sidebarCardBackgroundOpacity + 0.10)))
                    } else {
                        if let note = snapshot.note, !note.isEmpty {
                            Text(note)
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        }
                        Text(snapshot.days
                            .count == 1 ? "1 active day in \(self.historyMonthTitle)." :
                            "\(snapshot.days.count) active days in \(self.historyMonthTitle).")
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .padding(.bottom, RunicSpacing.xxs)

                        self.historyCalendarGrid
                        self.historyDayDetailCard
                    }
                } else {
                    Text("History is empty for this period.")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .padding(.vertical, RunicSpacing.xs)
                }

                if let historyError = self.historyError {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("History load failed")
                            .font(self.fonts.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        Text(historyError)
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .textSelection(.enabled)
                        Button("Retry") {
                            Task { await self.loadHistoryMonth(forceRefresh: true) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(RunicSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(
                            cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                            style: .continuous)
                            .fill(Color.red.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                            style: .continuous)
                            .strokeBorder(Color.red.opacity(0.28), lineWidth: 1))
                }

                Text(
                    "Local aggregated history only. Prompts, cookies, API keys, and raw payloads are never shown here.")
                    .font(self.fonts.caption2)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
            }
        }
    }

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

    var historyMonthTitle: String {
        self.historyMonthStart.formatted(.dateTime.month(.wide).year())
    }

    var canShiftHistoryForward: Bool {
        self.historyMonthStart < Self.monthStart(for: Date())
    }

    var historyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    var weekdaySymbols: [String] {
        let symbols = self.historyCalendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let start = max(0, min(symbols.count - 1, self.historyCalendar.firstWeekday - 1))
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    var calendarDaysForMonth: [Date] {
        guard let monthInterval = self.historyCalendar.dateInterval(of: .month, for: self.historyMonthStart),
              let firstWeek = self.historyCalendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastDayOfMonth = self.historyCalendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeek = self.historyCalendar.dateInterval(of: .weekOfMonth, for: lastDayOfMonth)
        else {
            return []
        }

        var days: [Date] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            days.append(cursor)
            guard let next = self.historyCalendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    var historySummaryByDay: [Date: ProviderHistoryDaySnapshot] {
        guard let snapshot = self.historySnapshot else { return [:] }
        var map: [Date: ProviderHistoryDaySnapshot] = [:]
        for day in snapshot.days {
            map[self.historyCalendar.startOfDay(for: day.dayStart)] = day
        }
        return map
    }

    var selectedHistoryDaySummary: ProviderHistoryDaySnapshot? {
        guard let snapshot = self.historySnapshot else { return nil }
        guard let selectedDay = self.historySelectedDay else { return snapshot.days.last }
        return snapshot.days.first { self.historyCalendar.isDate($0.dayStart, inSameDayAs: selectedDay) }
    }

    var historyMaxMetricValue: Double {
        guard let snapshot = self.historySnapshot, !snapshot.days.isEmpty else { return 0 }
        return snapshot.days.reduce(0) { max($0, self.historyMetricValue(for: $1)) }
    }

    func historyMetricValue(for day: ProviderHistoryDaySnapshot) -> Double {
        switch self.historyMetricMode {
        case .tokens:
            Double(day.totals.totalTokens)
        case .cost:
            max(0, day.totals.costUSD ?? 0)
        case .requests:
            Double(day.requestCount)
        }
    }

    func historyIntensity(for day: ProviderHistoryDaySnapshot?) -> Double {
        guard let day else { return 0 }
        let maxValue = self.historyMaxMetricValue
        guard maxValue > 0 else { return 0.15 }
        return min(1, max(0.15, self.historyMetricValue(for: day) / maxValue))
    }

    func historyDayHelp(for day: Date, summary: ProviderHistoryDaySnapshot?) -> String {
        var lines: [String] = [day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())]
        guard let summary else {
            lines.append("No recorded activity")
            return lines.joined(separator: "\n")
        }
        lines.append("Requests: \(self.decimalString(summary.requestCount))")
        lines.append("Tokens: \(UsageFormatter.tokenSummaryString(summary.totals))")
        if let spend = summary.totals.costUSD {
            lines.append("Spend: \(UsageFormatter.usdString(spend))")
        }
        if self.hasModelBreakdown, let topModel = summary.topModel {
            var modelLine = "Top model: \(UsageFormatter.modelDisplayName(topModel.model))"
            if let context = UsageFormatter.modelContextLabel(for: topModel.model) {
                modelLine += " · \(context)"
            }
            lines.append(modelLine)
        }
        if self.hasModelBreakdown, !summary.modelSummaries.isEmpty {
            let modelCount = min(3, summary.modelSummaries.count)
            for summary in summary.modelSummaries.prefix(modelCount) {
                let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
                var line = "Model: \(UsageFormatter.modelDisplayName(summary.model)) · \(tokens) tok"
                if let context = UsageFormatter.modelContextLabel(for: summary.model) {
                    line += " · \(context)"
                }
                lines.append(line)
            }
        }
        if self.hasProjectAttribution, let topProject = summary.topProject {
            var projectLine = "Top project: \(self.projectDisplay(topProject).title)"
            if let cost = topProject.totals.costUSD {
                projectLine += " · \(UsageFormatter.usdString(cost))"
            }
            lines.append(projectLine)
        }
        return lines.joined(separator: "\n")
    }

    func renderedModelsList(_ modelsUsed: [String]) -> [String] {
        var seen: Set<String> = []
        var rendered: [String] = []
        for model in modelsUsed {
            let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            var text = UsageFormatter.modelDisplayName(trimmed)
            if let context = UsageFormatter.modelContextLabel(for: trimmed) {
                text += " \(context)"
            }
            rendered.append(text)
        }
        return rendered
    }

    func historyModelLine(_ summary: UsageLedgerModelSummary) -> String {
        self.usageLine(
            title: UsageFormatter.modelDisplayName(summary.model),
            totals: summary.totals,
            requests: summary.entryCount,
            model: summary.model)
    }

    func historyProjectLine(_ summary: UsageLedgerProjectSummary) -> String {
        let project = self.projectDisplay(summary)
        return self.usageLine(
            title: project.title,
            totals: summary.totals,
            requests: summary.entryCount)
    }

    func shiftHistoryMonth(by delta: Int) {
        guard delta != 0 else { return }
        guard let shifted = self.historyCalendar.date(byAdding: .month, value: delta, to: self.historyMonthStart) else {
            return
        }
        let candidate = Self.monthStart(for: shifted)
        if delta > 0, candidate > Self.monthStart(for: Date()) {
            return
        }
        self.historyMonthStart = candidate
        self.historySnapshot = nil
        self.historySelectedDay = nil
        self.historyError = nil
    }

    static func monthStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    func loadHistoryMonth(forceRefresh: Bool = false) async {
        guard !self.historyIsLoading else { return }
        self.historyIsLoading = true
        self.historyError = nil
        let snapshot = await self.store.providerHistoryMonth(
            provider: self.provider,
            monthStart: self.historyMonthStart,
            forceRefresh: forceRefresh)
        self.historySnapshot = snapshot
        self.historyError = snapshot.error
        self.historyIsLoading = false
        self.selectDefaultHistoryDay(from: snapshot)
    }

    func selectDefaultHistoryDay(from snapshot: ProviderHistoryMonthSnapshot) {
        guard !snapshot.days.isEmpty else {
            self.historySelectedDay = self.historyCalendar.startOfDay(for: self.historyMonthStart)
            return
        }
        if let selected = self.historySelectedDay,
           snapshot.days.contains(where: { self.historyCalendar.isDate($0.dayStart, inSameDayAs: selected) })
        {
            self.historySelectedDay = self.historyCalendar.startOfDay(for: selected)
            return
        }
        self.historySelectedDay = snapshot.days.map(\.dayStart).max()
    }


}
