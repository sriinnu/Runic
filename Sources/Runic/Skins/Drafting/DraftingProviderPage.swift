import AppKit
import RunicCore
import SwiftUI

/// The provider card as a drawing sheet: a title block masthead (kicker,
/// the name in caps, the plan and account line, DWG NO and REV cells), a
/// legend with the check stamp, each window as a numbered dimensioned bar,
/// the account as a ruled table of cells, numbered notes beside the
/// revisions table. Crop marks sit in the sheet's corners.
struct DraftingProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private let inset: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.masthead
                .padding(.top, 10)
                .padding(.bottom, 12)
            DraftingRule(dashed: true, opacity: 0.5)
            self.legend
                .padding(.top, 10)

            if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                MenuEmptyStateView(
                    providerName: self.model.providerName,
                    placeholder: placeholder,
                    needsCredentials: self.model.needsCredentials,
                    isHighlighted: self.isHighlighted)
                    .padding(.vertical, 12)
            }

            let windows = self.windows
            ForEach(windows, id: \.metric.id) { window in
                DraftingWindowSheet(window: window, displayMode: self.model.usageMetricDisplayMode)
                    .padding(.top, window.index == 0 ? 18 : 12)
            }

            let account = self.accountCells
            if !account.isEmpty {
                DraftingCap(text: "Schedule \u{00B7} account")
                    .padding(.top, 18)
                    .padding(.bottom, 6)
                DraftingCellGrid(cells: account)
            }

            HStack(alignment: .top, spacing: 14) {
                self.notes(windows)
                    .frame(maxWidth: .infinity, alignment: .leading)
                self.revisions
                    .frame(width: (self.width - self.inset * 2 - 14) * 0.45)
            }
            .padding(.top, 16)

            if let error = self.ledgerError {
                Text(error)
                    .font(RunicDrafting.copy(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.warm)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .overlay { ClickToCopyOverlay(copyText: self.model.tokenUsage?.errorCopyText ?? error) }
            }
        }
        .skinFace()
        .padding(.horizontal, self.inset)
        .padding(.bottom, 14)
        .frame(width: self.width, alignment: .leading)
        .overlay(DraftingCropMarks(inset: 4))
    }

    // MARK: Masthead

    private var masthead: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                DraftingCap(text: self.kicker)
                Text(self.model.providerName.uppercased())
                    .font(RunicDrafting.title(26))
                    .skinFace()
                    .tracking(-0.3)
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                if let planLine = self.planLine {
                    Text(planLine)
                        .font(RunicDrafting.mono(10.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.top, 2)
                }
                if let status = self.statusLine {
                    Text(status)
                        .font(RunicDrafting.copy(11))
                        .skinFace()
                        .foregroundStyle(self.model.subtitleStyle == .error ? self.runicTheme.warm : self.runicTheme
                            .secondaryText)
                        .lineLimit(self.model.subtitleStyle == .error ? 4 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay {
                            if self.model.subtitleStyle == .error {
                                ClickToCopyOverlay(copyText: self.model.subtitleText)
                            }
                        }
                }
                if self.isAuthError || self.model.isServedByCLIFallback {
                    self.recoveryButton
                        .padding(.top, 6)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                DraftingCell(
                    label: "Dwg No",
                    value: RunicDrafting.drawingNumber(for: self.model.providerName),
                    valueFont: RunicDrafting.mono(11, .semibold),
                    edges: [.top, .bottom, .leading])
                    .fixedSize()
                DraftingCell(
                    label: "Rev",
                    value: RunicDrafting.revision,
                    valueFont: RunicDrafting.mono(11, .semibold))
                    .fixedSize()
            }
            .padding(.top, 2)
        }
    }

    /// "Usage drawing · section A–A", with the badge when there is one.
    private var kicker: String {
        var parts = ["Usage drawing", "section A\u{2013}A"]
        if let badge = self.model.headerBadge { parts.append(badge.text) }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// "PLAN: PRO · ACCT: s•••@icloud.com", or nothing when the provider
    /// reports neither.
    private var planLine: String? {
        var parts: [String] = []
        if let plan = self.model.planText, !plan.isEmpty { parts.append("PLAN: \(plan.uppercased())") }
        if !self.model.email.isEmpty { parts.append("ACCT: \(self.model.email)") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    /// "Connected · updated 4m ago", or the error itself.
    private var statusLine: String? {
        let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self.model.subtitleStyle != .error else { return subtitle.isEmpty ? nil : subtitle }
        var parts: [String] = []
        if let connection = self.model.insights?.connectionLine,
           let value = RunicDrafting.keyValue(connection)?.value
        {
            parts.append(value.prefix(1).uppercased() + value.dropFirst())
        }
        if !subtitle.isEmpty { parts.append(parts.isEmpty ? subtitle : subtitle.lowercased()) }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }

    @ViewBuilder
    private var recoveryButton: some View {
        if self.model.provider == .claude {
            DraftingButton(title: "Reconnect Claude\u{2026}", filled: true, compact: true) {
                NotificationCenter.default.post(
                    name: .runicReloadProvider,
                    object: nil,
                    userInfo: ["provider": UsageProvider.claude.rawValue])
            }
            .help(self.model.isServedByCLIFallback
                ? "Runic's copy of the Claude login has expired, so usage is read through the Claude CLI "
                + "(no cost or reset credits). Reconnect re-reads the login from Keychain; macOS may ask once."
                : "Re-reads the Claude CLI's login from Keychain. macOS may ask once.")
            .accessibilityLabel("Reconnect Claude from the CLI's Keychain login")
        } else {
            DraftingButton(title: "Add account\u{2026}", filled: true, compact: true) {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }

    // MARK: Legend

    private var legend: some View {
        let ink = self.runicTheme.primary
        let isError = self.model.subtitleStyle == .error
        return HStack(spacing: 10) {
            HStack(spacing: 5) {
                DraftingHatchBar(percent: 100, accessibilityLabel: "Used", height: 9)
                    .frame(width: 18)
                DraftingCap(text: "Used", size: 9, tracking: 1)
                    .fixedSize()
            }
            HStack(spacing: 5) {
                Rectangle()
                    .stroke(ink, lineWidth: 1)
                    .frame(width: 18, height: 9)
                DraftingCap(text: "Remaining", size: 9, tracking: 1)
                    .fixedSize()
            }
            HStack(spacing: 5) {
                DraftingEdgeShape(edges: .top)
                    .stroke(self.runicTheme.highlight, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: 18, height: 1)
                DraftingCap(text: "Plan line", size: 9, color: self.runicTheme.highlight, tracking: 1)
                    .fixedSize()
            }
            Spacer(minLength: 4)
            DraftingStamp(
                text: isError ? "HOLD \u{2717}" : "CHECKED \u{2713}",
                color: isError ? self.runicTheme.warm : self.runicTheme.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend: hatched is used, blank is remaining, dashed amber is the plan line")
    }

    // MARK: Windows

    struct Window {
        let index: Int
        let metric: UsageMenuCardView.Model.Metric
        let tint: Color
        /// "A" when the window carries a note, listed under Notes.
        let bubble: String?
        let marker: Double?
        let paceText: String?
    }

    private var windows: [Window] {
        var letter = 0
        return self.model.metrics.enumerated().map { index, metric in
            let detail = metric.detailText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var bubble: String?
            if !detail.isEmpty, metric.percent != nil {
                bubble = String(Character(UnicodeScalar(0x41 + min(letter, 25))!))
                letter += 1
            }
            let marker = Self.paceMarker(for: metric)
            return Window(
                index: index,
                metric: metric,
                tint: self.model.progressColor,
                bubble: bubble,
                marker: marker,
                paceText: marker == nil ? nil : RunicDrafting.paceCallout(detail))
        }
    }

    /// The plan line names where the window "should" be: the used share
    /// pushed back by the pace delta ("Pace: Behind (-34%)" → used + 34).
    static func paceMarker(for metric: UsageMenuCardView.Model.Metric) -> Double? {
        guard let percent = metric.percent, let detail = metric.detailText,
              let delta = RunicDrafting.paceDelta(detail)
        else { return nil }
        return min(100, max(0, percent - delta))
    }

    // MARK: Account

    private var accountCells: [DraftingCellGrid.Cell] {
        var cells: [DraftingCellGrid.Cell] = []
        if let credits = self.model.creditsText {
            cells.append(.init(label: "Balance", value: credits, numeric: true))
        }
        if let cost = self.model.providerCost {
            let used = cost.percentUsed.map { String(format: " \u{00B7} %.0f%% of limit", min(100, max(0, $0))) } ?? ""
            cells.append(.init(label: cost.title, value: cost.spendLine + used))
        }
        if self.model.menuMode != .glance, let ledger = self.model.tokenUsage {
            cells.append(.init(label: "Session cost", value: ledger.sessionLine))
            cells.append(.init(label: "This month", value: ledger.monthLine))
        }
        if self.model.menuMode == .operator, let insights = self.model.insights {
            let lines = [
                insights.contextLine, insights.compactionLine, insights.todayLine, insights.blockLine,
                insights.modelLine, insights.projectLine, insights.reliabilityLine, insights.routingLine,
            ]
            for line in lines.compactMap(\.self) where !line.isEmpty {
                if let pair = RunicDrafting.keyValue(line) {
                    cells.append(.init(label: pair.key, value: pair.value))
                } else {
                    cells.append(.init(label: "Note", value: line))
                }
            }
        }
        return cells
    }

    // MARK: Notes and revisions

    private func notes(_ windows: [Window]) -> some View {
        var items: [String] = []
        for window in windows {
            guard let detail = window.metric.detailText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !detail.isEmpty
            else { continue }
            if let bubble = window.bubble {
                items.append("Detail \(bubble): \(detail)")
            } else {
                items.append("\(window.metric.title): \(detail)")
            }
        }
        if let hint = self.model.creditsHintText?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            items.append(hint)
        }
        if self.model.menuMode != .glance,
           let hint = self.model.tokenUsage?.hintLine?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hint.isEmpty
        {
            items.append(hint)
        }
        if self.model.menuMode == .operator, let insights = self.model.insights {
            if let forecast = insights.forecastLine, !forecast.isEmpty { items.append(forecast) }
            if let anomaly = insights.anomalyLine, !anomaly.isEmpty { items.append(anomaly) }
        }
        if let topModel = self.model.topModelLine, !topModel.isEmpty, items.count < 3 {
            items.append(topModel)
        }
        if items.isEmpty { items.append("No remarks on this sheet.") }

        return VStack(alignment: .leading, spacing: 4) {
            DraftingCap(text: "Notes")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.prefix(5).enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 5) {
                        Text("\(index + 1).")
                            .font(RunicDrafting.mono(10))
                            .skinFace()
                            .frame(width: 14, alignment: .trailing)
                        Text(item)
                            .font(RunicDrafting.mono(10))
                            .skinFace()
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .overlay { ClickToCopyOverlay(copyText: item) }
                    }
                    .foregroundStyle(self.runicTheme.primaryText.opacity(0.88))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notes")
    }

    private var revisions: some View {
        let ink = self.runicTheme.primary
        let today = RunicDrafting.dateStamp()
        var rows: [(rev: String, change: String, date: String)] = []
        if let build = RunicDrafting.build { rows.append((build, "Build", today)) }
        rows.append((RunicVersion.marketing, "Release", today))
        return VStack(alignment: .leading, spacing: 4) {
            DraftingCap(text: "Revisions")
            VStack(spacing: 0) {
                DraftingRevisionRow(rev: "REV", change: "CHANGE", date: "DATE", isHeader: true)
                    .draftingEdges(.bottom, color: ink.opacity(0.6))
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    DraftingRevisionRow(rev: row.rev, change: row.change, date: row.date, isHeader: false)
                        .draftingEdges(index < rows.count - 1 ? .bottom : [], color: ink.opacity(0.3))
                }
            }
            .overlay(Rectangle().stroke(ink.opacity(0.6), lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Revisions: build \(RunicDrafting.revision), release \(RunicVersion.marketing)")
    }

    private var ledgerError: String? {
        guard self.model.menuMode != .glance else { return nil }
        let error = self.model.tokenUsage?.errorLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return error.isEmpty ? nil : error
    }
}

// MARK: - Window sheet

/// One window: the numbered callout and title, the reset as a mono
/// callout, then the dimensioned bar. A window without a percent (a
/// balance) sets its value as the dimension instead.
struct DraftingWindowSheet: View {
    let window: DraftingProviderPage.Window
    let displayMode: UsageMetricDisplayMode
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let metric = self.window.metric
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                DraftingCallout(number: self.window.index + 1)
                DraftingCap(text: metric.title, color: self.runicTheme.primaryText)
                    .layoutPriority(1)
                Spacer(minLength: 6)
                if let reset = metric.resetText, metric.percent != nil {
                    Text(RunicDrafting.resetCallout(reset))
                        .font(RunicDrafting.mono(10.5))
                        .skinFace()
                        .foregroundStyle(self.isExhausted ? self.runicTheme.warm : self.runicTheme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            if let percent = metric.percent {
                if self.displayMode.showsBars {
                    DraftingDimensionedBar(
                        percent: percent,
                        accessibilityLabel: "\(metric.title) \(metric.percentStyle.accessibilityLabel)",
                        remainingText: self.remainingText(percent),
                        marker: self.window.marker,
                        paceText: self.window.paceText,
                        bubble: self.window.bubble,
                        isWarm: self.isExhausted)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(percent.rounded()))%")
                            .font(RunicDrafting.numeral(22))
                            .skinFace()
                            .foregroundStyle(self.isExhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                        DraftingCap(text: metric.percentStyle.labelSuffix)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(metric.title) \(metric.percentStyle.accessibilityLabel)")
                    .accessibilityValue("\(Int(percent.rounded())) percent")
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    if let value = metric.resetText {
                        Text(value)
                            .font(RunicDrafting.numeral(20))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if let detail = metric.detailText, !detail.isEmpty {
                        Text(detail)
                            .font(RunicDrafting.mono(10))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 26)
            }
        }
    }

    private func remainingText(_ percent: Double) -> String {
        let clamped = min(100, max(0, percent))
        switch self.window.metric.percentStyle {
        case .used: return "\(Int((100 - clamped).rounded()))% REMAINING"
        case .left: return "\(Int((100 - clamped).rounded()))% USED"
        }
    }

    private var isExhausted: Bool {
        guard let percent = self.window.metric.percent else { return false }
        switch self.window.metric.percentStyle {
        case .used: return percent >= 99.5
        case .left: return percent <= 0.5
        }
    }
}

// MARK: - Cell grid

/// Cells two abreast, sharing rules; an odd last cell spans the row.
struct DraftingCellGrid: View {
    struct Cell {
        let label: String
        let value: String
        var numeric = false
        var color: Color?
    }

    let cells: [Cell]
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let rows = stride(from: 0, to: self.cells.count, by: 2)
            .map { Array(self.cells[$0..<min($0 + 2, self.cells.count)]) }
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, cell in
                        DraftingCell(
                            label: cell.label,
                            value: cell.value,
                            valueFont: cell.numeric
                                ? RunicDrafting.mono(12, .semibold)
                                : RunicDrafting.sans(12, .medium),
                            valueColor: cell.color,
                            edges: Self.edges(
                                isLastInRow: cellIndex == row.count - 1,
                                isLastRow: rowIndex == rows.count - 1),
                            lineLimit: 2)
                    }
                }
            }
        }
    }

    /// Every cell rules its top and leading edge; the row's last cell adds
    /// the trailing edge and the last row the bottom, so no rule doubles.
    private static func edges(isLastInRow: Bool, isLastRow: Bool) -> Edge.Set {
        var edges: Edge.Set = [.top, .leading]
        if isLastInRow { edges.insert(.trailing) }
        if isLastRow { edges.insert(.bottom) }
        return edges
    }
}

// MARK: - Revision row

struct DraftingRevisionRow: View {
    let rev: String
    let change: String
    let date: String
    let isHeader: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 4) {
            Text(self.rev)
                .frame(width: 34, alignment: .leading)
            Text(self.change)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(self.date)
                .frame(width: 42, alignment: .trailing)
        }
        .font(RunicDrafting.mono(self.isHeader ? 8.5 : 9.5, self.isHeader ? .medium : .regular))
        .skinFace()
        .tracking(self.isHeader ? 0.6 : 0)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(self.isHeader ? self.runicTheme.secondary : self.runicTheme.primaryText)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
    }
}
