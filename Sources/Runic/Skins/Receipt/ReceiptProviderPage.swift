import AppKit
import RunicCore
import SwiftUI

/// One provider's receipt: the provider is the store. "RUNIC" over a
/// centred header, every window as a line item with its reset indented
/// beneath, the account lines (balance, cost, ledger, context) as the
/// subtotal block, the forecast as NOTES, then the next-window figure with
/// its stamp, the barcode and the thank-you line.
struct ReceiptProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        let now = Date()
        ReceiptPrintout {
            VStack(alignment: .leading, spacing: 0) {
                self.header(now: now)
                ReceiptDashedRule()

                if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                    MenuEmptyStateView(
                        providerName: self.model.providerName,
                        placeholder: placeholder,
                        needsCredentials: self.model.needsCredentials,
                        isHighlighted: self.isHighlighted)
                        .environment(\.runicTheme, RunicReceipt.paperPalette(self.runicTheme))
                        .padding(.vertical, 6)
                } else {
                    self.lineItems
                }

                let account = self.accountRows
                if !account.isEmpty {
                    ReceiptDashedRule()
                    ForEach(Array(account.enumerated()), id: \.offset) { _, row in
                        // A long value would squeeze its label to nothing;
                        // it prints on its own indented line instead.
                        let wraps = row.value.count > 24
                        ReceiptLine(
                            label: row.key.uppercased(),
                            value: wraps ? "" : row.value,
                            valueBold: row.strong,
                            leader: !wraps && !row.value.isEmpty)
                        if wraps {
                            ReceiptSubline(text: row.value, color: RunicReceipt.ink, bold: row.strong, lines: 3)
                        }
                        if let detail = row.detail {
                            ReceiptSubline(text: detail, lines: 2)
                        }
                    }
                }

                let notes = self.notes
                if !notes.isEmpty {
                    ReceiptDashedRule()
                    ReceiptText(text: "NOTES", bold: true)
                        .frame(height: RunicReceipt.lineBox())
                    ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                        ReceiptText(text: note, size: RunicReceipt.smallSize, color: RunicReceipt.inkSoft)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 12)
                            .padding(.vertical, 2)
                            .overlay { ClickToCopyOverlay(copyText: note) }
                    }
                }

                if let error = self.ledgerError {
                    ReceiptDashedRule()
                    ReceiptText(text: error, size: RunicReceipt.smallSize, bold: true, color: RunicReceipt.stamp)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay { ClickToCopyOverlay(copyText: self.model.tokenUsage?.errorCopyText ?? error) }
                }

                if !self.model.metrics.isEmpty {
                    ReceiptDashedRule()
                    ReceiptNextWindow(soonest: self.soonestReset, exhausted: self.exhaustedCount)
                }
                ReceiptTail(soonest: self.soonestReset, date: now)
            }
        }
        .skinFace()
        .frame(width: self.width, alignment: .leading)
        .preference(key: ReceiptBarePanelKey.self, value: true)
    }

    // MARK: Header

    private func header(now: Date) -> some View {
        VStack(spacing: 0) {
            ReceiptCentred(text: "RUNIC", size: 22, bold: true, tracking: 6.6)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            ReceiptCentred(text: self.storeLine, tracking: 1.1)
                .accessibilityAddTraits(.isHeader)
            ReceiptCentred(text: RunicReceipt.stampDate(now))
            ReceiptCentred(text: RunicReceipt.transactionLine)
            ReceiptCentred(
                text: "MODE: \(self.model.menuMode.label.uppercased()) \u{00B7} ITEMS: \(self.model.metrics.count)")
            if self.model.subtitleStyle == .error {
                let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
                ReceiptText(text: subtitle, size: RunicReceipt.smallSize, bold: true, color: RunicReceipt.stamp)
                    .lineLimit(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    .overlay { ClickToCopyOverlay(copyText: self.model.subtitleText) }
            } else if let status = self.statusLine {
                ReceiptCentred(text: status, color: RunicReceipt.inkSoft)
            }
            if !self.model.email.isEmpty {
                ReceiptText(text: "ACCT: \(self.model.email)", size: 10.5, color: RunicReceipt.inkSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(minHeight: RunicReceipt.lineBox(10.5))
            }
            if self.isAuthError || self.model.isServedByCLIFallback {
                self.recoveryButton
                    .padding(.top, 8)
            }
        }
    }

    /// "CODEX RECEIPT · PRO" — the provider as the store, the plan or badge
    /// as its department.
    private var storeLine: String {
        var parts = ["\(self.model.providerName) RECEIPT"]
        if let plan = self.model.planText, !plan.isEmpty { parts.append(plan) }
        if let badge = self.model.headerBadge { parts.append(badge.text) }
        return parts.joined(separator: " \u{00B7} ").uppercased()
    }

    /// "connected · updated 4m ago"
    private var statusLine: String? {
        var parts: [String] = []
        if let connection = self.model.insights?.connectionLine,
           let value = RunicReceipt.keyValue(connection)?.value
        {
            parts.append(value)
        }
        let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !subtitle.isEmpty { parts.append(subtitle) }
        if let topModel = self.model.topModelLine, !topModel.isEmpty, parts.count < 2 { parts.append(topModel) }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " \u{00B7} ").lowercased()
    }

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }

    @ViewBuilder
    private var recoveryButton: some View {
        if self.model.provider == .claude {
            ReceiptButton(title: "Reconnect Claude\u{2026}", filled: true, onPaper: true) {
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
            ReceiptButton(title: "Add account\u{2026}", filled: true, onPaper: true) {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }

    // MARK: Line items

    private var lineItems: some View {
        VStack(alignment: .leading, spacing: 0) {
            let column = self.model.metrics.first?.percentStyle.labelSuffix.uppercased() ?? "USED"
            ReceiptLine(label: "ITEM", value: column, bold: true, leader: false)
            ForEach(self.model.metrics) { metric in
                ReceiptMetricItem(metric: metric)
            }
        }
    }

    private var exhaustedCount: Int {
        self.model.metrics.count(where: { ReceiptMetricItem.isExhausted($0) })
    }

    /// Seconds to the soonest reset any window prints.
    private var soonestReset: TimeInterval? {
        self.model.metrics.compactMap { metric in
            metric.percent == nil ? nil : RunicReceipt.seconds(in: metric.resetText)
        }.min()
    }

    // MARK: Subtotal

    private struct AccountRow {
        let key: String
        let value: String
        var strong = false
        var detail: String?
    }

    private var accountRows: [AccountRow] {
        var rows: [AccountRow] = []
        if let credits = self.model.creditsText {
            let hint = self.model.creditsHintText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            rows.append(AccountRow(key: "Balance", value: credits, strong: true, detail: hint.isEmpty ? nil : hint))
        }
        if let cost = self.model.providerCost {
            let used = cost.percentUsed.map { String(format: " \u{00B7} %.0f%% of limit", min(100, max(0, $0))) } ?? ""
            rows.append(AccountRow(key: cost.title, value: cost.spendLine + used, strong: true))
        }
        if self.model.menuMode != .glance, let ledger = self.model.tokenUsage {
            rows.append(AccountRow(key: "Session cost", value: ledger.sessionLine, strong: true))
            rows.append(AccountRow(key: "This month", value: ledger.monthLine, strong: true))
        }
        if self.model.menuMode == .operator, let insights = self.model.insights {
            let lines = [
                insights.contextLine, insights.compactionLine, insights.todayLine, insights.blockLine,
                insights.modelLine, insights.projectLine, insights.reliabilityLine, insights.routingLine,
            ]
            for line in lines.compactMap(\.self) where !line.isEmpty {
                if let pair = RunicReceipt.keyValue(line) {
                    rows.append(AccountRow(key: pair.key, value: pair.value))
                } else {
                    rows.append(AccountRow(key: line, value: ""))
                }
            }
        }
        return rows
    }

    /// The forecast and the anomaly, when the page has them.
    private var notes: [String] {
        guard self.model.menuMode == .operator, let insights = self.model.insights else { return [] }
        return [insights.forecastLine, insights.anomalyLine].compactMap(\.self).filter { !$0.isEmpty }
    }

    private var ledgerError: String? {
        guard self.model.menuMode != .glance else { return nil }
        let error = self.model.tokenUsage?.errorLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return error.isEmpty ? nil : error
    }
}

/// One window as a line item: "SESSION ........ 62%", the reset indented
/// beneath, the pace under that; an exhausted window prints bold with a red
/// "** EXHAUSTED **" line.
struct ReceiptMetricItem: View {
    let metric: UsageMenuCardView.Model.Metric

    var body: some View {
        let exhausted = Self.isExhausted(self.metric)
        VStack(alignment: .leading, spacing: 0) {
            ReceiptLine(label: self.metric.title.uppercased(), value: self.value, valueBold: exhausted)
            if self.metric.percent != nil, let reset = RunicReceipt.resetDetail(self.metric.resetText) {
                if exhausted {
                    ReceiptSubline(text: "** EXHAUSTED ** resets \(reset)", color: RunicReceipt.stamp, bold: true)
                } else {
                    ReceiptSubline(text: "resets \(reset)")
                }
            } else if exhausted {
                ReceiptSubline(text: "** EXHAUSTED **", color: RunicReceipt.stamp, bold: true)
            }
            if let detail = self.metric.detailText, !detail.isEmpty {
                ReceiptSubline(text: detail, lines: 2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The percent, or — for a window without one (a balance, a counter) —
    /// whatever the card prints in the reset slot.
    private var value: String {
        if let percent = self.metric.percent {
            return "\(Int(percent.rounded()))%"
        }
        return self.metric.resetText ?? "N/A"
    }

    static func isExhausted(_ metric: UsageMenuCardView.Model.Metric) -> Bool {
        guard let percent = metric.percent else { return false }
        switch metric.percentStyle {
        case .used: return percent >= 99.5
        case .left: return percent <= 0.5
        }
    }
}
