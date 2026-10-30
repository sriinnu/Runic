import AppKit
import RunicCore
import SwiftUI

/// The provider card as one channel of a bench instrument: "CHANNEL · PRO"
/// engraved over the name, an LCD status strip, a plate of VU meters (one
/// per window) with LCD readouts, a pace plate with a segment bar, a status
/// plate of three lamps, a readouts plate of engraved label · LCD rows, and
/// the note engraved into the enamel.
struct InstrumentProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.masthead
                .padding(.top, 6)
                .padding(.horizontal, 2)

            if let error = self.errorText {
                Text(error)
                    .font(RunicInstrument.copy(11.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.warm)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
                    .overlay { ClickToCopyOverlay(copyText: error) }
            }

            if self.isAuthError || self.model.isServedByCLIFallback {
                self.recoveryButton
                    .padding(.horizontal, 2)
            }

            InstrumentGroove()

            if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                InstrumentPlate {
                    MenuEmptyStateView(
                        providerName: self.model.providerName,
                        placeholder: placeholder,
                        needsCredentials: self.model.needsCredentials,
                        isHighlighted: self.isHighlighted)
                }
            }

            if !self.model.metrics.isEmpty {
                self.metersPlate
            }

            if let pace = self.paceMetric {
                InstrumentPacePlate(detail: pace.detailText ?? "")
            }

            self.statusPlate

            let rows = self.readoutRows
            if !rows.isEmpty {
                InstrumentPlate {
                    VStack(spacing: 8) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            InstrumentReadoutRow(label: row.label, value: row.value, dim: row.dim, alert: row.alert)
                        }
                    }
                }
            }

            if let note = self.note {
                HStack(alignment: .top, spacing: 10) {
                    InstrumentEngraved(text: "Note")
                        .padding(.top, 2)
                    Text(note)
                        .font(RunicInstrument.copy(12.5))
                        .skinFace()
                        .foregroundStyle(RunicInstrument.Paint.engrave)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay { ClickToCopyOverlay(copyText: note) }
                }
                .padding(.horizontal, 4)
            }

            if let error = self.ledgerError {
                Text(error)
                    .font(RunicInstrument.copy(11.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.warm)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .overlay { ClickToCopyOverlay(copyText: self.model.tokenUsage?.errorCopyText ?? error) }
            }
        }
        .skinFace()
        .padding(.bottom, 4)
        .frame(width: self.width, alignment: .leading)
    }

    // MARK: Masthead

    private var masthead: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                InstrumentEngraved(text: self.kicker)
                Text(self.model.providerName.uppercased())
                    .font(RunicInstrument.name(30))
                    .skinFace()
                    .tracking(1.8)
                    .foregroundStyle(self.runicTheme.primary)
                    .shadow(color: Color.white.opacity(0.7), radius: 0, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                if !self.model.email.isEmpty {
                    Text(self.model.email)
                        .font(RunicInstrument.copy(10.5))
                        .skinFace()
                        .foregroundStyle(RunicInstrument.Paint.engrave)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            let status = self.statusLines
            InstrumentLCD {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(status.top)
                        .font(RunicInstrument.lcd(11))
                        .skinFace()
                        .foregroundStyle(status.alert ? RunicInstrument.Paint.lcdAlert : RunicInstrument.Paint.lcdText)
                    Text(status.bottom)
                        .font(RunicInstrument.lcd(11))
                        .skinFace()
                        .foregroundStyle(status.alert ? RunicInstrument.Paint.lcdAlert : RunicInstrument.Paint.lcdText)
                        .opacity(status.alert ? 1 : 0.75)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 84, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status: \(self.model.subtitleText)")
        }
    }

    /// "Channel · Pro" — the plan, the badge, or just the word.
    private var kicker: String {
        var parts = ["Channel"]
        if let plan = self.model.planText, !plan.isEmpty { parts.append(plan) }
        if let badge = self.model.headerBadge { parts.append(badge.text) }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// The LCD strip: when it was last read, and whether the link is up.
    private var statusLines: (top: String, bottom: String, alert: Bool) {
        switch self.model.subtitleStyle {
        case .error:
            return ("LINK ERR", self.isAuthError ? "AUTH" : "FAULT", true)
        case .loading:
            return ("REFRESH", "LINK --", false)
        case .info:
            let link = self.model.isServedByCLIFallback ? "LINK CLI" : "LINK OK"
            return (RunicInstrument.lcdUpdated(self.model.subtitleText), link, false)
        }
    }

    private var errorText: String? {
        guard self.model.subtitleStyle == .error else { return nil }
        let text = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }

    @ViewBuilder
    private var recoveryButton: some View {
        if self.model.provider == .claude {
            InstrumentKey(title: "Reconnect Claude\u{2026}", systemImage: "key", variant: .orange) {
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
            InstrumentKey(title: "Add account\u{2026}", systemImage: "plus", variant: .orange) {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }

    // MARK: Meters

    private var metersPlate: some View {
        let metrics = self.model.metrics
        let pairs = stride(from: 0, to: metrics.count, by: 2).map { Array(metrics[$0..<min($0 + 2, metrics.count)]) }
        return InstrumentPlate(padding: .init(top: 14, leading: 12, bottom: 12, trailing: 12)) {
            VStack(spacing: 12) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(pair) { metric in
                            InstrumentMeterCell(
                                metric: metric,
                                displayMode: self.model.usageMetricDisplayMode,
                                showsDetail: metric.id != self.paceMetric?.id)
                                .frame(maxWidth: .infinity)
                        }
                        if pair.count == 1 {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meters")
    }

    /// The first window with a pace reading feeds the pace plate.
    private var paceMetric: UsageMenuCardView.Model.Metric? {
        self.model.metrics.first { RunicInstrument.isPaceLine($0.detailText) }
    }

    // MARK: Status

    private var statusPlate: some View {
        InstrumentPlate {
            HStack(spacing: 8) {
                InstrumentLampLabel(lamp: self.linkLamp, text: "Link")
                    .frame(maxWidth: .infinity, alignment: .leading)
                InstrumentLampLabel(lamp: self.capLamp.lamp, text: self.capLamp.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                InstrumentLampLabel(lamp: self.model.creditsText == nil ? .off : .green, text: "Balance")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.statusAccessibility)
    }

    private var linkLamp: RunicInstrument.Lamp {
        switch self.model.subtitleStyle {
        case .error: .red
        case .loading: .amber
        case .info: .green
        }
    }

    private var capLamp: (lamp: RunicInstrument.Lamp, text: String) {
        if self.model.isServedByCLIFallback { return (.amber, "Cap \u{00B7} fallback") }
        if self.model.metrics.contains(where: Self.isExhausted) { return (.red, "Cap \u{00B7} clip") }
        return (.off, "Cap")
    }

    private var statusAccessibility: String {
        let link = switch self.model.subtitleStyle {
        case .error: "link error"
        case .loading: "link refreshing"
        case .info: "link ok"
        }
        let cap = self.capLamp.lamp.isLit ? self.capLamp.text : "no cap"
        let balance = self.model.creditsText == nil ? "no balance" : "balance on"
        return "Status: \(link), \(cap), \(balance)"
    }

    static func isExhausted(_ metric: UsageMenuCardView.Model.Metric) -> Bool {
        guard let percent = metric.percent else { return false }
        switch metric.percentStyle {
        case .used: return percent >= 99.5
        case .left: return percent <= 0.5
        }
    }

    // MARK: Readouts

    private struct ReadoutRow {
        let label: String
        let value: String
        var dim = false
        var alert = false
    }

    private var readoutRows: [ReadoutRow] {
        var rows: [ReadoutRow] = []
        let insights = self.model.menuMode == .operator ? self.model.insights : nil
        if let insights {
            if let context = insights.contextLine.flatMap(RunicInstrument.keyValue)?.value {
                // "max ctx ~272K · observed ..." — the readout is the figure.
                let first = context.components(separatedBy: " \u{00B7} ").first ?? context
                let value = first.replacingOccurrences(of: "max ctx ", with: "")
                rows.append(ReadoutRow(label: "Max context", value: value.uppercased()))
            } else {
                rows.append(ReadoutRow(label: "Max context", value: "----", dim: true))
            }
        }
        if let credits = self.model.creditsText {
            rows.append(ReadoutRow(label: "Balance", value: credits.uppercased()))
        } else {
            rows.append(ReadoutRow(label: "Balance", value: "----.--", dim: true))
        }
        if let cost = self.model.providerCost {
            let used = cost.percentUsed.map { String(format: " \u{00B7} %.0f%%", min(100, max(0, $0))) } ?? ""
            rows.append(ReadoutRow(label: cost.title, value: (cost.spendLine + used).uppercased()))
        }
        if self.model.menuMode != .glance, let ledger = self.model.tokenUsage {
            rows.append(ReadoutRow(label: "Session", value: ledger.sessionLine.uppercased()))
            rows.append(ReadoutRow(label: "Month", value: ledger.monthLine.uppercased()))
        }
        if self.model.menuMode != .glance, let peak = self.model.peakHoursText {
            rows.append(ReadoutRow(label: "Peak hrs", value: peak.uppercased()))
        }
        if let insights {
            var sources: [String] = []
            if insights.modelLine != nil { sources.append("MDL") }
            if insights.todayLine != nil || self.model.tokenUsage != nil { sources.append("TOK") }
            if insights.projectLine != nil { sources.append("PRJ") }
            rows.append(ReadoutRow(
                label: "Sources",
                value: sources.isEmpty ? "----" : sources.joined(separator: "\u{00B7}"),
                dim: sources.isEmpty))
            let lines = [
                insights.compactionLine, insights.todayLine, insights.blockLine, insights.modelLine,
                insights.projectLine, insights.reliabilityLine, insights.routingLine,
            ]
            for line in lines.compactMap(\.self) where !line.isEmpty {
                if let pair = RunicInstrument.keyValue(line) {
                    rows.append(ReadoutRow(label: pair.key, value: pair.value.uppercased()))
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
}

// MARK: - Meter cell

/// One window on the meters plate: the VU meter with the title engraved
/// under its arc, an LCD "USED 62%" readout, the reset in mono caps.
struct InstrumentMeterCell: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    var showsDetail = true
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            if let percent = self.metric.percent {
                if self.displayMode.showsBars {
                    InstrumentVUMeter(
                        title: self.metric.title,
                        percent: percent,
                        redZoneLow: self.metric.percentStyle == .left,
                        accessibilityLabel: "\(self.metric.title) meter, "
                            + self.metric.percentStyle.accessibilityLabel)
                } else {
                    InstrumentEngraved(text: self.metric.title)
                        .frame(maxWidth: .infinity)
                }
                if self.displayMode.showsPercent {
                    InstrumentLCD {
                        HStack(alignment: .lastTextBaseline) {
                            Text(self.metric.percentStyle.labelSuffix.uppercased())
                                .font(RunicInstrument.lcd(9))
                                .skinFace()
                                .opacity(0.75)
                            Spacer(minLength: 4)
                            Text("\(Int(percent.rounded()))%")
                                .font(RunicInstrument.lcd(16, bold: true))
                                .skinFace()
                                .foregroundStyle(self.isExhausted
                                    ? RunicInstrument.Paint.lcdAlert
                                    : RunicInstrument.Paint.lcdText)
                        }
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Int(percent.rounded())) percent \(self.metric.percentStyle.labelSuffix)")
                }
            } else {
                // A window with no denominator (a balance, a spend line)
                // reads out on the LCD alone.
                InstrumentEngraved(text: self.metric.title)
                    .frame(maxWidth: .infinity)
                InstrumentLCDText(text: self.metric.resetText ?? "----", size: 14, bold: true, alignment: .center)
                    .frame(maxWidth: .infinity)
            }
            if self.metric.percent != nil, let reset = self.metric.resetText {
                Text(RunicInstrument.lcdReset(reset))
                    .font(RunicInstrument.mono(9.5))
                    .skinFace()
                    .tracking(0.4)
                    .foregroundStyle(RunicInstrument.Paint.engrave)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            if self.showsDetail, let detail = self.metric.detailText, !detail.isEmpty {
                Text(detail)
                    .font(RunicInstrument.copy(10.5))
                    .skinFace()
                    .foregroundStyle(RunicInstrument.Paint.engrave)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var isExhausted: Bool {
        InstrumentProviderPage.isExhausted(self.metric)
    }
}

// MARK: - Pace plate

/// "PACE" engraved, a 12-segment bar lit to the size of the delta (red
/// when behind, green when ahead, the tail amber) and the delta on an LCD.
struct InstrumentPacePlate: View {
    let detail: String

    var body: some View {
        let delta = RunicInstrument.paceDelta(self.detail)
        let magnitude = abs(delta ?? 0)
        let lit = delta == nil ? 0 : min(12, max(1, Int((Double(magnitude) / 100 * 12).rounded(.up))))
        let behind = (delta ?? 0) < 0
        InstrumentPlate {
            HStack(alignment: .center, spacing: 12) {
                InstrumentEngraved(text: "Pace")
                VStack(alignment: .leading, spacing: 4) {
                    InstrumentSegmentBar(count: 12, lit: lit, height: 8, spacing: 3) { index in
                        if index >= Int(Double(lit) * 0.67) { return .amber }
                        return behind ? .red : .green
                    }
                    if let eta = RunicInstrument.paceETA(self.detail) {
                        Text(eta)
                            .font(RunicInstrument.mono(8.5))
                            .skinFace()
                            .foregroundStyle(RunicInstrument.Paint.engrave)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
                InstrumentLCDText(text: self.readout(delta: delta), alert: behind, minWidth: 44)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.detail)
    }

    private func readout(delta: Int?) -> String {
        guard let delta else {
            let label = self.detail.replacingOccurrences(of: "Pace: ", with: "")
            return String(label.prefix(while: { $0 != "\u{00B7}" })).trimmingCharacters(in: .whitespaces).uppercased()
        }
        return delta < 0 ? "\u{2212}\(abs(delta))%" : "+\(delta)%"
    }
}
