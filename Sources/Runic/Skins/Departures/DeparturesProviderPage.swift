import AppKit
import RunicCore
import SwiftUI

/// The provider card as its own gate on the board: the gate letter and name
/// over a flap row with the next reset, the status line, a yellow rule,
/// then every window as a departure (TIME / WINDOW / REMAINING / STATUS),
/// the pace and context on a ticker, the account as plain table rows, and
/// the insights as a numbered list of notices.
struct DeparturesProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 0) {
                self.masthead(now: now)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                DeparturesRule()

                if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                    MenuEmptyStateView(
                        providerName: self.model.providerName,
                        placeholder: placeholder,
                        needsCredentials: self.model.needsCredentials,
                        isHighlighted: self.isHighlighted)
                        .padding(.vertical, 12)
                }

                if !self.model.metrics.isEmpty {
                    DeparturesTableHeader(width: self.width)
                        .padding(.top, 4)
                    ForEach(Array(self.model.metrics.enumerated()), id: \.element.id) { index, metric in
                        self.row(for: metric, now: now)
                        if index < self.model.metrics.count - 1 {
                            DeparturesHairline()
                        }
                    }
                }

                if let ticker = self.ticker {
                    DeparturesTicker(text: ticker)
                        .padding(.top, 8)
                }

                let account = self.accountRows
                if !account.isEmpty {
                    DeparturesHeader(text: "Account")
                        .padding(.top, 14)
                        .padding(.bottom, 2)
                    ForEach(Array(account.enumerated()), id: \.offset) { index, row in
                        DeparturesKeyValue(
                            label: row.key,
                            value: row.value,
                            valueColor: row.color,
                            detail: row.detail,
                            isLast: index == account.count - 1)
                    }
                }

                let notices = self.notices
                if !notices.isEmpty {
                    DeparturesHeader(text: "Notices")
                        .padding(.top, 14)
                        .padding(.bottom, 6)
                    ForEach(Array(notices.enumerated()), id: \.offset) { index, notice in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(String(format: "%02d", index + 1))
                                .font(RunicDepartures.condensed(12, .semibold))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.accent)
                                .frame(width: 18, alignment: .leading)
                            Text(notice)
                                .font(RunicDepartures.copy(11.5))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.primaryText.opacity(0.9))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .overlay { ClickToCopyOverlay(copyText: notice) }
                        }
                        .padding(.vertical, 3)
                    }
                }

                if let error = self.ledgerError {
                    Text(error)
                        .font(RunicDepartures.copy(11.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.warm)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .overlay { ClickToCopyOverlay(copyText: self.model.tokenUsage?.errorCopyText ?? error) }
                }
            }
            .skinFace()
            .padding(.horizontal, 2)
            .padding(.bottom, 6)
            .frame(width: self.width, alignment: .leading)
        }
    }

    // MARK: Masthead

    private func masthead(now _: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                DeparturesHeader(text: "Gate \(RunicDepartures.gate(for: self.model.provider))")
                Text(self.model.providerName.uppercased())
                    .font(RunicDepartures.condensed(22, .bold))
                    .skinFace()
                    .tracking(0.8)
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                if let plan = self.planLine {
                    DeparturesHeader(text: plan)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            FlapRow(segments: self.mastheadSegments, scale: .masthead, fit: self.width - 4)
            Text(self.statusLine)
                .font(RunicDepartures.condensed(12))
                .skinFace()
                .tracking(1.2)
                .foregroundStyle(self.model.subtitleStyle == .error ? self.runicTheme.warm : self.runicTheme
                    .secondary)
                .lineLimit(self.model.subtitleStyle == .error ? 4 : 1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .overlay {
                    if self.model.subtitleStyle == .error {
                        ClickToCopyOverlay(copyText: self.model.subtitleText)
                    }
                }
            if !self.model.email.isEmpty {
                Text(self.model.email)
                    .font(RunicDepartures.copy(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if self.isAuthError || self.model.isServedByCLIFallback {
                self.recoveryButton
                    .padding(.top, 2)
            }
        }
    }

    /// "NEXT · 2H 14M · SESSION", the soonest window; or the gate when no
    /// window names a countdown.
    private var mastheadSegments: [FlapRow.Segment] {
        let soonest = self.model.metrics
            .compactMap { metric -> (Metric, TimeInterval)? in
                RunicDepartures.countdownSeconds(in: metric.resetText).map { (metric, $0) }
            }
            .min { $0.1 < $1.1 }
        if let (metric, seconds) = soonest {
            return [
                FlapRow.Segment(text: "NEXT"),
                FlapRow.Segment(text: RunicDepartures.flapCountdown(seconds), tint: self.runicTheme.accent),
                FlapRow.Segment(
                    text: String(metric.title.prefix(10)),
                    tint: self.isExhausted(metric) ? self.runicTheme.warm : nil),
            ]
        }
        return [
            FlapRow.Segment(text: "GATE"),
            FlapRow.Segment(text: RunicDepartures.gate(for: self.model.provider), tint: self.runicTheme.accent),
            FlapRow.Segment(text: String(self.model.providerName.prefix(10))),
        ]
    }

    /// "Pro · CLI" — the plan and the badge, when there are any.
    private var planLine: String? {
        var parts: [String] = []
        if let plan = self.model.planText, !plan.isEmpty { parts.append(plan) }
        if let badge = self.model.headerBadge { parts.append(badge.text) }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    /// "CONNECTED · UPDATED 4M AGO", or the error itself.
    private var statusLine: String {
        let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self.model.subtitleStyle != .error else { return subtitle }
        var parts: [String] = []
        if let connection = self.model.insights?.connectionLine,
           let value = RunicDepartures.keyValue(connection)?.value
        {
            parts.append(value)
        }
        if !subtitle.isEmpty { parts.append(subtitle) }
        if let topModel = self.model.topModelLine, !topModel.isEmpty, parts.count < 2 { parts.append(topModel) }
        return parts.joined(separator: " \u{00B7} ").uppercased()
    }

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }

    @ViewBuilder
    private var recoveryButton: some View {
        if self.model.provider == .claude {
            DeparturesButton(title: "Reconnect Claude\u{2026}", filled: true) {
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
            DeparturesButton(title: "Add account\u{2026}", filled: true) {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }

    // MARK: Departures

    private typealias Metric = UsageMenuCardView.Model.Metric

    private func isExhausted(_ metric: Metric) -> Bool {
        guard let percent = metric.percent else { return false }
        switch metric.percentStyle {
        case .used: return percent >= 99.5
        case .left: return percent <= 0.5
        }
    }

    /// Used share for the gauge, whichever way the card counts.
    private func usedPercent(_ metric: Metric) -> Double? {
        guard let percent = metric.percent else { return nil }
        return metric.percentStyle == .used ? percent : 100 - percent
    }

    @ViewBuilder
    private func row(for metric: Metric, now: Date) -> some View {
        let seconds = RunicDepartures.countdownSeconds(in: metric.resetText)
        let exhausted = self.isExhausted(metric)
        let tint = exhausted ? self.runicTheme.warm : self.runicTheme.accent
        let showsGauge = metric.percent != nil && self.model.usageMetricDisplayMode.showsBars
        let gauge: (percent: Double, tint: Color, label: String)? = showsGauge
            ? (self.usedPercent(metric) ?? 0, tint, metric.percentStyle.accessibilityLabel)
            : nil
        let subtitle: String? = {
            if let percent = metric.percent, self.model.usageMetricDisplayMode.showsPercent {
                return "\(Int(percent.rounded()))% \(metric.percentStyle.labelSuffix)"
            }
            return metric.percent == nil ? metric.detailText : nil
        }()
        let remainingText: String? = {
            if seconds != nil { return nil }
            if metric.percent == nil { return metric.resetText }
            // "Resets tomorrow 9:00 AM" → "tomorrow 9:00 AM"
            return metric.resetText.map { text in
                text.hasPrefix("Resets ") ? String(text.dropFirst(7)) : text
            }
        }()
        let status: DeparturesStatus? = metric.percent == nil
            ? nil
            : DeparturesStatus.forWindow(exhausted: exhausted, secondsUntilReset: seconds, palette: self.runicTheme)
        DeparturesRow(
            width: self.width,
            time: seconds.map { RunicDepartures.boardTime(now.addingTimeInterval($0), now: now) },
            title: metric.title,
            subtitle: subtitle,
            gauge: gauge,
            remaining: seconds.map(RunicDepartures.boardRemaining),
            remainingText: remainingText,
            status: status,
            accessibilityLabel: self.accessibilityText(for: metric, seconds: seconds))
    }

    private func accessibilityText(for metric: Metric, seconds: TimeInterval?) -> String {
        var parts = [metric.title]
        if let label = metric.percentLabel { parts.append(label) }
        if let seconds {
            parts.append("resets in \(ResetScheduleMenuView.compactDuration(seconds))")
        } else if let reset = metric.resetText {
            parts.append(reset)
        }
        if let detail = metric.detailText, !detail.isEmpty { parts.append(detail) }
        return parts.joined(separator: ", ")
    }

    /// The pace and the context, as board copy.
    private var ticker: String? {
        var parts: [String] = []
        for metric in self.model.metrics where metric.percent != nil {
            if let detail = metric.detailText, !detail.isEmpty { parts.append(RunicDepartures.boardCopy(detail)) }
        }
        if self.model.menuMode == .operator,
           let context = self.model.insights?.contextLine,
           let value = RunicDepartures.keyValue(context)?.value
        {
            // Just the headline figure; the rest of the line is a notice.
            let head = value.components(separatedBy: " \u{00B7} ").first ?? value
            parts.append(RunicDepartures.boardCopy(head))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    // MARK: Account and notices

    private struct AccountRow {
        let key: String
        let value: String
        var color: Color?
        var detail: String?
    }

    private var accountRows: [AccountRow] {
        var rows: [AccountRow] = []
        if let credits = self.model.creditsText {
            let hint = self.model.creditsHintText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            rows.append(AccountRow(key: "Balance", value: credits, detail: hint.isEmpty ? nil : hint))
        }
        if let cost = self.model.providerCost {
            let used = cost.percentUsed.map { String(format: " \u{00B7} %.0f%% of limit", min(100, max(0, $0))) } ?? ""
            rows.append(AccountRow(key: cost.title, value: cost.spendLine + used))
        }
        if self.model.menuMode != .glance, let ledger = self.model.tokenUsage {
            rows.append(AccountRow(key: "Session cost", value: ledger.sessionLine))
            rows.append(AccountRow(key: "This month", value: ledger.monthLine))
        }
        if self.model.menuMode != .glance, let peak = self.model.peakHoursText {
            rows.append(AccountRow(key: "Peak hours", value: peak))
        }
        return rows
    }

    /// The insight lines, in reading order, minus the ones the masthead and
    /// ticker already carry.
    private var notices: [String] {
        guard self.model.menuMode == .operator, let insights = self.model.insights else { return [] }
        let lines = [
            insights.forecastLine, insights.anomalyLine, insights.compactionLine, insights.todayLine,
            insights.blockLine, insights.modelLine, insights.projectLine, insights.reliabilityLine,
            insights.routingLine,
        ]
        return lines.compactMap(\.self).filter { !$0.isEmpty }
    }

    private var ledgerError: String? {
        guard self.model.menuMode != .glance else { return nil }
        let error = self.model.tokenUsage?.errorLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return error.isEmpty ? nil : error
    }
}
