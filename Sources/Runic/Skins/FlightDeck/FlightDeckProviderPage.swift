import AppKit
import RunicCore
import SwiftUI

/// The provider card as a glass-cockpit primary flight display (MK II): a
/// header unit with the callsign, any master caution and the locked flight
/// mode annunciator strip (LINK · PLAN · HELD · BAL); a full-width ECAM
/// warning when the link faults; the PFD unit — a vertical tape for each of
/// the first two windows either side of the attitude indicator that tilts
/// with the pace, over a reset strip; further windows as flat tapes; the
/// 24-hour burn velocity strip; and the account as an ECAM ledger.
struct FlightDeckProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private let sidePadding: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            self.headerUnit

            if self.model.subtitleStyle == .error {
                self.faultMemo
            } else if self.model.isServedByCLIFallback {
                self.recoveryButton
            }

            if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                MenuEmptyStateView(
                    providerName: self.model.providerName,
                    placeholder: placeholder,
                    needsCredentials: self.model.needsCredentials,
                    isHighlighted: self.isHighlighted)
                    .padding(.vertical, 8)
            }

            let gauges = self.gaugeMetrics
            if !gauges.isEmpty {
                self.pfdUnit(gauges)
            }

            let extra = Array(gauges.dropFirst(2))
            if !extra.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(extra) { metric in
                        self.secondaryTape(metric)
                    }
                }
                .padding(8)
                .flightDeckBezel(fill: self.runicTheme.surface)
            }

            if self.model.menuMode != .glance, let burn = self.burnHistory(gauges) {
                FlightDeckBurnStrip(values: burn)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .flightDeckBezel(fill: self.runicTheme.surface)
            }

            let account = self.accountRows
            if !account.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    FlightDeckLabel(text: "ECAM \u{00B7} Ledger")
                        .padding(.bottom, 3)
                    ForEach(Array(account.enumerated()), id: \.offset) { index, row in
                        FlightDeckRow(
                            key: row.key,
                            value: row.value,
                            valueColor: row.color,
                            detail: row.detail,
                            isLast: index == account.count - 1,
                            tone: row.tone)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.top, 7)
                .padding(.bottom, 3)
                .flightDeckBezel(fill: self.runicTheme.surface)
            }

            if let note = self.note {
                FlightDeckMemo(title: "FCST \u{00B7} Advisory", tone: .cyan) {
                    Text(note)
                        .font(RunicFlightDeck.sans(10.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay { ClickToCopyOverlay(copyText: note) }
                }
            }

            if let error = self.ledgerError {
                FlightDeckMemo(title: "LDG FAULT \u{00B7} Caution", tone: .amber) {
                    Text(error)
                        .font(RunicFlightDeck.sans(10.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.highlight)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay { ClickToCopyOverlay(copyText: self.model.tokenUsage?.errorCopyText ?? error) }
                }
            }
        }
        .skinFace()
        .padding(.horizontal, self.sidePadding)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(width: self.width, alignment: .leading)
    }

    // MARK: Header unit

    private var headerUnit: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(RunicFlightDeck.callsign(self.model.providerName))
                    .font(RunicFlightDeck.sans(14, .bold))
                    .skinFace()
                    .tracking(1.2)
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 6)
                if self.model.subtitleStyle != .error {
                    Text(self.statusLine)
                        .font(RunicFlightDeck.mono(9))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .minimumScaleFactor(0.8)
                }
            }
            if !self.model.email.isEmpty {
                Text(self.model.email)
                    .font(RunicFlightDeck.mono(9))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            let tags = self.annunciatorTags
            if !tags.isEmpty {
                FlightDeckWrap(spacing: 5) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                        FlightDeckTag(text: tag.text, tone: tag.tone)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Annunciators")
            }
            FlightDeckFMAStrip(items: self.modeItems)
                .accessibilityLabel("Flight mode annunciator")
        }
        .padding(8)
        .flightDeckBezel(fill: self.runicTheme.surface)
    }

    /// Cautions and advisories that only show when they are live.
    private var annunciatorTags: [(text: String, tone: FlightDeckTag.Tone)] {
        var tags: [(String, FlightDeckTag.Tone)] = []
        let exhausted = self.model.metrics.filter(self.isExhausted)
        let hasFault = self.model.subtitleStyle == .error
            || !(self.model.tokenUsage?.errorLine ?? "").isEmpty
        if !exhausted.isEmpty || hasFault {
            tags.append(("MASTER CAUT", .caution))
        }
        if self.model.isServedByCLIFallback {
            tags.append(("CAP FALLBACK", .amber))
        }
        if let badge = self.model.headerBadge, badge.text.lowercased() != "via cli" {
            let tone: FlightDeckTag.Tone = switch badge.style {
            case .info: .cyan
            case .warning: .amber
            case .error: .magenta
            }
            tags.append((badge.text, tone))
        }
        if !exhausted.isEmpty {
            tags.append(("\(RunicFlightDeck.callsign(self.model.providerName)) EXH", .magenta))
        }
        return tags.map { (text: $0.0, tone: $0.1) }
    }

    /// LINK · PLAN · HELD · BAL, locked flush.
    private var modeItems: [FlightDeckFMAStrip.Item] {
        let faulted = self.model.subtitleStyle == .error
        let plan = self.model.planText?.trimmingCharacters(in: .whitespaces)
        let held = RunicFlightDeck.heldCount(from: self.model.bankedResetsText)
        let balance = RunicFlightDeck.compactBalance(from: self.model.balanceSummaryText)
        return [
            .init(
                id: 0,
                value: faulted ? "NO LINK" : "LINK",
                color: faulted ? self.runicTheme.warm : self.runicTheme.tertiary),
            .init(
                id: 1,
                value: (plan?.isEmpty ?? true) ? nil : plan,
                color: self.runicTheme.primaryText,
                boxed: !(plan?.isEmpty ?? true)),
            .init(
                id: 2,
                value: held.map { "\($0) HELD" } ?? "0 HELD",
                color: held == nil ? RunicFlightDeck.dim : self.runicTheme.highlight),
            .init(
                id: 3,
                value: balance.map { "BAL \($0)" },
                color: self.runicTheme.accent),
        ]
    }

    /// "CONNECTED · UPDATED 4M AGO".
    private var statusLine: String {
        let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if let connection = self.model.insights?.connectionLine,
           let value = RunicFlightDeck.keyValue(connection)?.value
        {
            parts.append(value)
        }
        if !subtitle.isEmpty { parts.append(subtitle) }
        if let topModel = self.model.topModelLine, !topModel.isEmpty, parts.count < 2 { parts.append(topModel) }
        return parts.joined(separator: " \u{00B7} ").uppercased()
    }

    // MARK: Fault

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }

    /// The link fault as a full-width ECAM warning: the whole message,
    /// wrapped to six lines, then COPY, RELOAD and the sign-in action.
    private var faultMemo: some View {
        let message = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        return FlightDeckMemo(
            title: self.isAuthError ? "AUTH FAULT \u{00B7} Warning" : "LINK FAULT \u{00B7} Warning",
            tone: .magenta)
        {
            Text(message.isEmpty ? "No response from \(self.model.providerName)." : message)
                .font(RunicFlightDeck.sans(10.5))
                .skinFace()
                .foregroundStyle(self.runicTheme.warm)
                .lineSpacing(1.5)
                .lineLimit(6)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay { ClickToCopyOverlay(copyText: self.model.subtitleText) }
            FlightDeckWrap(spacing: 6) {
                if !message.isEmpty {
                    FlightDeckCopyButton(text: self.model.subtitleText)
                }
                FlightDeckButton(title: "Reload", systemImage: "arrow.clockwise", compact: true) {
                    NotificationCenter.default.post(
                        name: .runicReloadProvider,
                        object: nil,
                        userInfo: ["provider": self.model.provider.rawValue])
                }
                .help("Re-reads \(self.model.providerName)'s credentials and pings it again.")
                .accessibilityLabel("Reload \(self.model.providerName)")
                if self.isAuthError || self.model.isServedByCLIFallback {
                    self.recoveryButton
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var recoveryButton: some View {
        if self.model.provider == .claude {
            FlightDeckButton(title: "Reconnect Claude\u{2026}", primary: true, compact: true) {
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
            FlightDeckButton(title: "Add account\u{2026}", primary: true, compact: true) {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }

    // MARK: Primary display

    /// Windows with a real percent; balances and counters go to the table.
    private var gaugeMetrics: [UsageMenuCardView.Model.Metric] {
        self.model.metrics.filter { $0.percent != nil }
    }

    private func pfdUnit(_ gauges: [UsageMenuCardView.Model.Metric]) -> some View {
        VStack(spacing: 8) {
            self.primaryDisplay(gauges)
            FlightDeckFMAStrip(items: self.resetItems(gauges), fill: self.runicTheme.cardFill)
                .accessibilityLabel("Reset annunciator")
        }
        .padding(8)
        .flightDeckBezel(fill: self.runicTheme.surface)
    }

    private func primaryDisplay(_ gauges: [UsageMenuCardView.Model.Metric]) -> some View {
        let pace = self.paceDelta
        let caption = self.paceCaption
        return HStack(alignment: .center, spacing: 4) {
            if let first = gauges.first {
                self.tape(first, ticksTrailing: true)
            }
            VStack(spacing: 5) {
                FlightDeckLabel(text: "PFD", size: 8.5)
                FlightDeckAttitude(paceDelta: pace, size: 164)
                FlightDeckLabel(text: caption ?? (pace == nil ? "No pace data" : "On pace"), size: 8.5)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: 164)
            }
            .frame(maxWidth: .infinity)
            if gauges.count > 1 {
                self.tape(gauges[1], ticksTrailing: false)
            } else {
                Color.clear.frame(width: 60, height: 240)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tape(_ metric: UsageMenuCardView.Model.Metric, ticksTrailing: Bool) -> some View {
        let slot = RunicFlightDeck.slot(forMetricID: metric.id)
        let rate = slot.flatMap { RunicFlightDeck.burnRate(provider: self.model.provider, slot: $0) }
        return FlightDeckTape(
            title: metric.title,
            percent: metric.percent ?? 0,
            style: metric.percentStyle,
            ticksTrailing: ticksTrailing,
            ratePerHour: rate,
            marker: self.paceMarker(for: metric),
            height: 240)
    }

    private func secondaryTape(_ metric: UsageMenuCardView.Model.Metric) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                FlightDeckLabel(text: metric.title)
                Spacer(minLength: 8)
                if let reset = RunicFlightDeck.compactReset(metric.resetText) {
                    FlightDeckLabel(text: reset, color: self.runicTheme.accent)
                }
            }
            FlightDeckHorizontalTape(
                percent: metric.percent,
                showsUsed: metric.percentStyle == .used,
                tint: self.isExhausted(metric) ? self.runicTheme.warm : self.model.progressColor,
                accessibilityLabel: "\(metric.title), \(metric.percentStyle.accessibilityLabel)",
                height: 30)
            if let detail = metric.detailText, !detail.isEmpty {
                Text(detail)
                    .font(RunicFlightDeck.sans(10))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// SES RST · WK RST · CTX under the PFD.
    private func resetItems(_ gauges: [UsageMenuCardView.Model.Metric]) -> [FlightDeckFMAStrip.Item] {
        let first = gauges.first
        let second = gauges.count > 1 ? gauges[1] : nil
        let context = RunicFlightDeck.readout(from: self.model.insights?.contextLine)
            ?? RunicFlightDeck.readout(from: self.model.topModelLine)
        return [
            .init(
                id: 0,
                label: "\(RunicFlightDeck.windowCode(first?.title ?? "SES")) RST",
                value: RunicFlightDeck.compactReset(first?.resetText)),
            .init(
                id: 1,
                label: "\(RunicFlightDeck.windowCode(second?.title ?? "WK")) RST",
                value: RunicFlightDeck.compactReset(second?.resetText)),
            .init(id: 2, label: "CTX", value: context, color: self.runicTheme.primaryText),
        ]
    }

    /// The burn history of the first window that has one.
    private func burnHistory(_ gauges: [UsageMenuCardView.Model.Metric]) -> [Double]? {
        for metric in gauges.prefix(2) {
            guard let slot = RunicFlightDeck.slot(forMetricID: metric.id) else { continue }
            if let history = RunicFlightDeck.burnHistory(provider: self.model.provider, slot: slot) {
                return history
            }
        }
        return nil
    }

    // MARK: Account

    private struct AccountRow {
        let key: String
        let value: String
        var color: Color?
        var detail: String?
        var tone: FlightDeckTag.Tone?
    }

    private var accountRows: [AccountRow] {
        var rows: [AccountRow] = []
        if let credits = self.model.creditsText {
            let hint = self.model.creditsHintText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            rows.append(AccountRow(
                key: "Balance",
                value: credits,
                color: self.runicTheme.accent,
                detail: hint.isEmpty ? nil : hint,
                tone: .cyan))
        }
        if let cost = self.model.providerCost {
            let used = cost.percentUsed.map { String(format: " \u{00B7} %.0f%% of limit", min(100, max(0, $0))) } ?? ""
            if let primary = cost.primarySpendLine {
                rows.append(AccountRow(key: cost.title, value: primary + used))
                if let apiCredits = cost.apiCreditsLine {
                    rows.append(AccountRow(
                        key: "API credits",
                        value: apiCredits,
                        color: self.runicTheme.accent,
                        tone: .cyan))
                }
            } else {
                rows.append(AccountRow(key: cost.title, value: cost.spendLine + used))
            }
        }
        if let banked = self.model.bankedResetsText {
            let count = RunicFlightDeck.heldCount(from: banked)
            rows.append(AccountRow(
                key: "Banked resets",
                value: count.map { "\($0) HELD" } ?? banked.uppercased(),
                color: self.runicTheme.highlight,
                detail: count == nil ? nil : RunicFlightDeck.heldDetail(from: banked),
                tone: .amber))
        }
        if self.model.menuMode != .glance, let ledger = self.model.tokenUsage {
            rows.append(AccountRow(key: "Session cost", value: ledger.sessionLine))
            rows.append(AccountRow(key: "This month", value: ledger.monthLine))
        }
        if self.model.menuMode != .glance, let peak = self.model.peakHoursText {
            rows.append(AccountRow(key: "Peak hours", value: peak))
        }
        for metric in self.model.metrics where metric.percent == nil {
            let value = [metric.resetText, metric.detailText].compactMap(\.self).joined(separator: " \u{00B7} ")
            rows.append(AccountRow(key: metric.title, value: value.isEmpty ? "\u{2014}" : value))
        }
        if self.model.menuMode == .operator, let insights = self.model.insights {
            let lines = [
                insights.contextLine, insights.compactionLine, insights.todayLine, insights.blockLine,
                insights.modelLine, insights.projectLine, insights.reliabilityLine, insights.routingLine,
            ]
            for line in lines.compactMap(\.self) where !line.isEmpty {
                if let pair = RunicFlightDeck.keyValue(line) {
                    rows.append(AccountRow(key: pair.key, value: pair.value))
                } else {
                    rows.append(AccountRow(key: line, value: ""))
                }
            }
        }
        return rows
    }

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

    // MARK: Pace

    /// The first window that carries a pace line decides the attitude.
    private var paceDetail: String? {
        self.model.metrics.lazy.compactMap(\.detailText).first { RunicFlightDeck.paceDelta(from: $0) != nil }
    }

    private var paceDelta: Double? {
        RunicFlightDeck.paceDelta(from: self.paceDetail)
    }

    private var paceCaption: String? {
        RunicFlightDeck.paceCaption(from: self.paceDetail)
    }

    /// Where the window "should" be: the used share pushed back by the delta.
    private func paceMarker(for metric: UsageMenuCardView.Model.Metric) -> Double? {
        guard let percent = metric.percent, let delta = RunicFlightDeck.paceDelta(from: metric.detailText),
              delta != 0
        else { return nil }
        let used = metric.percentStyle == .used ? percent : 100 - percent
        let expected = min(100, max(0, used - delta))
        return metric.percentStyle == .used ? expected : 100 - expected
    }

    private func isExhausted(_ metric: UsageMenuCardView.Model.Metric) -> Bool {
        guard let percent = metric.percent else { return false }
        switch metric.percentStyle {
        case .used: return percent >= 99.5
        case .left: return percent <= 0.5
        }
    }
}

/// A wrapping row of tags, the way annunciators pack a panel.
struct FlightDeckWrap: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + self.spacing
                rowHeight = 0
            }
            x += size.width + self.spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? max(0, x - self.spacing) : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + self.spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + self.spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
