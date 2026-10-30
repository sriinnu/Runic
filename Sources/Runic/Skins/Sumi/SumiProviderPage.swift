import AppKit
import RunicCore
import SwiftUI

/// The provider card as a hanging scroll: the name in Mincho under a tracked
/// label with the seal beside it, each window as a vertical-labelled stanza
/// with a thin numeral and a brush-stroke gauge, the account as a key-value
/// list, and the forecast as a note under a small indigo seal. Rules are
/// dry-brush strokes; nothing is boxed.
struct SumiProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.masthead
                .padding(.top, 8)
                .padding(.bottom, 10)
            SumiRule()

            if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                MenuEmptyStateView(
                    providerName: self.model.providerName,
                    placeholder: placeholder,
                    needsCredentials: self.model.needsCredentials,
                    isHighlighted: self.isHighlighted)
                    .padding(.vertical, 12)
            }

            ForEach(Array(self.model.metrics.enumerated()), id: \.element.id) { index, metric in
                SumiWindowStanza(
                    metric: metric,
                    tint: self.model.progressColor,
                    displayMode: self.model.usageMetricDisplayMode,
                    marker: self.paceMarker(for: metric))
                    .padding(.top, index == 0 ? 18 : 6)
                    .padding(.bottom, 6)
            }

            let account = self.accountRows
            if !account.isEmpty {
                SumiRule()
                    .padding(.top, 8)
                SumiLabel(text: "Account")
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                ForEach(Array(account.enumerated()), id: \.offset) { index, row in
                    SumiKeyValue(
                        label: row.key,
                        value: row.value,
                        strong: row.strong,
                        valueFont: row.numeric ? RunicSumi.headline(15) : nil,
                        valueColor: row.color,
                        detail: row.detail,
                        isLast: index == account.count - 1)
                }
            }

            if let note = self.note {
                HStack(alignment: .top, spacing: 12) {
                    SumiSeal(text: "\u{6CE8}", color: self.runicTheme.secondary, size: 22, rotation: -2)
                    Text(note)
                        .font(RunicSumi.mincho(13))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText.opacity(0.88))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay { ClickToCopyOverlay(copyText: note) }
                }
                .padding(.top, 14)
            }

            if let error = self.ledgerError {
                Text(error)
                    .font(RunicSumi.copy(11.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.warm)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .overlay { ClickToCopyOverlay(copyText: self.model.tokenUsage?.errorCopyText ?? error) }
            }
        }
        .skinFace()
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
        .frame(width: self.width, alignment: .leading)
    }

    // MARK: Masthead

    private var masthead: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SumiLabel(text: self.kicker)
                Text(self.model.providerName)
                    .font(RunicSumi.name(38))
                    .skinFace()
                    .tracking(-0.4)
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                Text(self.statusLine)
                    .font(RunicSumi.copy(12))
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
                if !self.model.email.isEmpty {
                    Text(self.model.email)
                        .font(RunicSumi.copy(10.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if self.isAuthError || self.model.isServedByCLIFallback {
                    self.recoveryButton
                        .padding(.top, 6)
                }
            }
            Spacer(minLength: 8)
            SumiSeal(
                text: RunicSumi.initial(for: self.model.providerName),
                size: 32,
                image: ProviderBrandIcon.image(for: self.model.provider, size: 20))
                .padding(.bottom, 6)
        }
    }

    /// "Usage · Pro" — the plan, the badge, or just the word.
    private var kicker: String {
        var parts = ["Usage"]
        if let plan = self.model.planText, !plan.isEmpty { parts.append(plan) }
        if let badge = self.model.headerBadge { parts.append(badge.text) }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// "Connected · updated 4m ago", or the error itself.
    private var statusLine: String {
        let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self.model.subtitleStyle != .error else { return subtitle }
        var parts: [String] = []
        if let connection = self.model.insights?.connectionLine,
           let value = RunicSumi.keyValue(connection)?.value
        {
            parts.append(value.prefix(1).uppercased() + value.dropFirst())
        }
        if !subtitle.isEmpty { parts.append(parts.isEmpty ? subtitle : subtitle.lowercased()) }
        if let topModel = self.model.topModelLine, !topModel.isEmpty, parts.count < 2 { parts.append(topModel) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }

    @ViewBuilder
    private var recoveryButton: some View {
        if self.model.provider == .claude {
            SumiButton(title: "Reconnect Claude\u{2026}", filled: true) {
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
            SumiButton(title: "Add account\u{2026}", filled: true) {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }

    // MARK: Account

    private struct AccountRow {
        let key: String
        let value: String
        var strong = false
        var numeric = false
        var color: Color?
        var detail: String?
    }

    private var accountRows: [AccountRow] {
        var rows: [AccountRow] = []
        if let credits = self.model.creditsText {
            let hint = self.model.creditsHintText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            rows.append(AccountRow(
                key: "Balance",
                value: credits,
                strong: true,
                numeric: true,
                detail: hint.isEmpty ? nil : hint))
        }
        if let cost = self.model.providerCost {
            let used = cost.percentUsed.map { String(format: " \u{00B7} %.0f%% of limit", min(100, max(0, $0))) } ?? ""
            rows.append(AccountRow(key: cost.title, value: cost.spendLine + used, strong: true))
        }
        if self.model.menuMode != .glance, let ledger = self.model.tokenUsage {
            rows.append(AccountRow(key: "Session cost", value: ledger.sessionLine, strong: true))
            rows.append(AccountRow(key: "This month", value: ledger.monthLine, strong: true))
        }
        if self.model.menuMode != .glance, let peak = self.model.peakHoursText {
            rows.append(AccountRow(key: "Peak hours", value: peak))
        }
        if self.model.menuMode == .operator, let insights = self.model.insights {
            let lines = [
                insights.contextLine, insights.compactionLine, insights.todayLine, insights.blockLine,
                insights.modelLine, insights.projectLine, insights.reliabilityLine, insights.routingLine,
            ]
            for line in lines.compactMap(\.self) where !line.isEmpty {
                if let pair = RunicSumi.keyValue(line) {
                    rows.append(AccountRow(key: pair.key, value: pair.value))
                } else {
                    rows.append(AccountRow(key: line, value: ""))
                }
            }
        }
        return rows
    }

    /// The forecast or the anomaly, whichever the page has room to set.
    private var note: String? {
        guard self.model.menuMode == .operator, let insights = self.model.insights else { return nil }
        if let forecast = insights.forecastLine, !forecast.isEmpty { return forecast }
        if let anomaly = insights.anomalyLine, !anomaly.isEmpty { return anomaly }
        return nil
    }

    private var ledgerError: String? {
        guard self.model.menuMode != .glance else { return nil }
        let error = self.model.tokenUsage?.errorLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return error.isEmpty ? nil : error
    }

    /// The pace line names where the window "should" be; the marker is the
    /// elapsed share when the detail carries one ("Pace: Behind (-34%)" has
    /// no absolute, so the marker is the used share pushed by the delta).
    private func paceMarker(for metric: UsageMenuCardView.Model.Metric) -> Double? {
        guard let percent = metric.percent, let detail = metric.detailText else { return nil }
        guard let open = detail.range(of: "("), let close = detail.range(of: "%)"),
              open.upperBound < close.lowerBound
        else { return nil }
        let delta = Double(detail[open.upperBound..<close.lowerBound].replacingOccurrences(of: "+", with: "")) ?? 0
        guard delta != 0 else { return nil }
        return min(100, max(0, percent - delta))
    }
}

/// One window: the vertical side label, the numeral with its unit and the
/// reset on the same baseline, the brush gauge, and the pace beneath.
struct SumiWindowStanza: View {
    let metric: UsageMenuCardView.Model.Metric
    let tint: Color
    let displayMode: UsageMetricDisplayMode
    var marker: Double?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SumiVerticalLabel(text: self.metric.title, length: self.metric.percent == nil ? 56 : 100)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let percent = self.metric.percent, self.displayMode.showsPercent {
                        Text("\(Int(percent.rounded()))")
                            .font(RunicSumi.numeral(50))
                            .skinFace()
                            .tracking(-1.5)
                            .foregroundStyle(self.isExhausted ? self.runicTheme.accent : self.runicTheme.primaryText)
                        Text("%")
                            .font(RunicSumi.mincho(18))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                        Text(self.metric.percentStyle.labelSuffix)
                            .font(RunicSumi.copy(12))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                    } else {
                        Text(self.metric.title)
                            .font(RunicSumi.headline(18))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.primaryText)
                    }
                    Spacer(minLength: 6)
                    if let reset = self.metric.resetText {
                        Text(reset)
                            .font(RunicSumi.copy(11.5))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if let percent = self.metric.percent, self.displayMode.showsBars {
                    SumiBrushBar(
                        percent: percent,
                        tint: self.isExhausted ? self.runicTheme.accent : self.runicTheme.primaryText,
                        accessibilityLabel: self.metric.percentStyle.accessibilityLabel,
                        marker: self.marker)
                        .padding(.trailing, 8)
                }
                if let detail = self.metric.detailText, !detail.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(self.runicTheme.accent)
                            .frame(width: 5, height: 5)
                            .offset(y: -1)
                        Text(detail)
                            .font(RunicSumi.copy(12))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var isExhausted: Bool {
        guard let percent = self.metric.percent else { return false }
        switch self.metric.percentStyle {
        case .used: return percent >= 99.5
        case .left: return percent <= 0.5
        }
    }
}
