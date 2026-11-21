import AppKit
import RunicCore
import SwiftUI

/// The provider card as the face of a ceramic instrument: the maker's mark,
/// name and plan key with a live LED; any fault in a recessed well with its
/// keys; each window as a module with a reset capsule, a large tabular
/// readout and a machined trough gauge; balances as recessed readout tiles;
/// and the ledger as engraved rows.
struct ReliefProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private let inset: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.header
                .padding(.top, 14)
                .padding(.bottom, 12)

            if self.model.subtitleStyle == .error || self.model.isServedByCLIFallback {
                ReliefFaultPanel(
                    message: self.faultMessage,
                    provider: self.model.provider,
                    showsSignIn: self.isAuthError,
                    isCLIFallback: self.model.isServedByCLIFallback,
                    title: self.model.subtitleStyle == .error ? "Fault" : "Reading through the CLI")
                    .padding(.bottom, 12)
            }

            if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                ReliefGroove()
                MenuEmptyStateView(
                    providerName: self.model.providerName,
                    placeholder: placeholder,
                    needsCredentials: self.model.needsCredentials,
                    isHighlighted: self.isHighlighted)
                    .padding(.vertical, 12)
            }

            let gauges = self.model.metrics.filter { $0.percent != nil }
            ForEach(Array(gauges.enumerated()), id: \.element.id) { index, metric in
                if index == 0 { ReliefGroove() }
                ReliefWindowModule(
                    metric: metric,
                    displayMode: self.model.usageMetricDisplayMode)
                    .padding(.vertical, 14)
                ReliefGroove()
            }

            self.readouts

            let ledger = self.ledgerRows
            if !ledger.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ReliefLabel(text: "Ledger")
                        .padding(.bottom, 2)
                    ForEach(Array(ledger.enumerated()), id: \.offset) { index, row in
                        ReliefKeyValue(
                            label: row.key,
                            value: row.value,
                            strong: row.strong,
                            valueColor: row.color,
                            detail: row.detail,
                            isLast: index == ledger.count - 1)
                    }
                }
                .padding(.top, 14)
            }

            if let note = self.note {
                HStack(alignment: .top, spacing: 8) {
                    ReliefLED(color: self.runicTheme.secondary, size: 6)
                        .padding(.top, 4)
                    Text(note)
                        .font(RunicRelief.face(11.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay { ClickToCopyOverlay(copyText: note) }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .reliefWell(radius: 9, depth: 0.7)
                .padding(.top, 12)
            }

            if let error = self.ledgerError {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        ReliefLED(color: RunicRelief.ledAmber)
                        ReliefLabel(text: "Ledger fault", color: self.runicTheme.highlight)
                    }
                    Text(error)
                        .font(RunicRelief.face(11))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.highlight)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ReliefCopyButton(copyText: self.model.tokenUsage?.errorCopyText ?? error)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .reliefWell(radius: 9, depth: 0.7)
                .padding(.top, 12)
            }
        }
        .skinFace()
        .padding(.horizontal, self.inset)
        .padding(.bottom, 14)
        .frame(width: self.width, alignment: .leading)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                self.mark
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(self.model.providerName)
                            .font(RunicRelief.face(18, .semibold))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityAddTraits(.isHeader)
                        if let plan = self.model.planText, !plan.isEmpty {
                            Text(plan)
                                .font(RunicRelief.face(10.5, .semibold))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.primaryText)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(ReliefKeycapBackground(isPressed: false, radius: 5))
                        }
                    }
                    if !self.model.email.isEmpty {
                        Text(self.model.email)
                            .font(RunicRelief.face(10.5))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 6)
                if let badge = self.model.headerBadge {
                    self.badge(badge)
                }
            }
            if self.model.subtitleStyle != .error {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ReliefLED(color: self.statusLED, size: 6)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    Text(self.statusLine)
                        .font(RunicRelief.face(11))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var mark: some View {
        ZStack {
            ReliefKeycapBackground(isPressed: false, radius: 8)
            if let icon = ProviderBrandIcon.image(for: self.model.provider, size: 20) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            } else {
                Text(String(self.model.providerName.prefix(1)).uppercased())
                    .font(RunicRelief.face(14, .bold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
            }
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }

    private func badge(_ badge: UsageMenuCardView.Model.HeaderBadge) -> some View {
        let color: Color = switch badge.style {
        case .info: RunicRelief.ledGreen
        case .warning: RunicRelief.ledAmber
        case .error: RunicRelief.ledRed
        }
        return HStack(spacing: 5) {
            ReliefLED(color: color, size: 6)
            Text(badge.text)
                .font(RunicRelief.face(10.5, .semibold))
                .skinFace()
                .foregroundStyle(self.runicTheme.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .reliefWell(radius: 6, depth: 0.7)
        .accessibilityElement(children: .combine)
    }

    private var statusLED: Color {
        switch self.model.subtitleStyle {
        case .info: RunicRelief.ledGreen
        case .loading: RunicRelief.ledAmber
        case .error: RunicRelief.ledRed
        }
    }

    /// "Connected · updated 4m ago · Opus 4.1".
    private var statusLine: String {
        let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if let connection = self.model.insights?.connectionLine,
           let value = RunicRelief.keyValue(connection)?.value
        {
            parts.append(value.prefix(1).uppercased() + value.dropFirst())
        }
        if !subtitle.isEmpty { parts.append(parts.isEmpty ? subtitle : subtitle.lowercased()) }
        if let topModel = self.model.topModelLine, !topModel.isEmpty { parts.append(topModel) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private var faultMessage: String {
        guard self.model.subtitleStyle == .error else {
            return "Runic's copy of the login has expired, so usage is read through the CLI "
                + "without cost or reset credits."
        }
        return self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }

    // MARK: Readouts

    private struct Tile: Identifiable {
        let id: String
        let label: String
        let value: String
        let led: Color?
    }

    private var tiles: [Tile] {
        var tiles: [Tile] = []
        if let credits = self.model.creditsText {
            tiles.append(Tile(id: "balance", label: "Balance", value: credits, led: RunicRelief.ledGreen))
        } else if let apiCredits = self.model.providerCost?.apiCreditsLine {
            tiles.append(Tile(id: "api", label: "API credits", value: apiCredits, led: RunicRelief.ledGreen))
        } else if let balance = self.model.balanceSummaryText {
            tiles.append(Tile(id: "balance", label: "Balance", value: balance, led: RunicRelief.ledGreen))
        }
        if let banked = self.model.bankedResetsText {
            tiles.append(Tile(id: "banked", label: "Banked resets", value: banked, led: RunicRelief.ledAmber))
        }
        return tiles
    }

    @ViewBuilder
    private var readouts: some View {
        let tiles = self.tiles
        if !tiles.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(tiles) { tile in
                        ReliefReadoutTile(label: tile.label, value: tile.value, led: tile.led)
                    }
                }
                if self.model.creditsText != nil,
                   let hint = self.model.creditsHintText?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !hint.isEmpty
                {
                    Text(hint)
                        .font(RunicRelief.face(10.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay { ClickToCopyOverlay(copyText: self.model.creditsHintCopyText ?? hint) }
                }
            }
            .padding(.top, 14)
        }
    }

    // MARK: Ledger

    private struct Row {
        let key: String
        let value: String
        var strong = false
        var color: Color?
        var detail: String?
    }

    private var ledgerRows: [Row] {
        var rows: [Row] = []
        let tileIDs = Set(self.tiles.map(\.id))
        if let cost = self.model.providerCost {
            let used = cost.percentUsed.map { String(format: " \u{00B7} %.0f%% of limit", min(100, max(0, $0))) } ?? ""
            if let primary = cost.primarySpendLine {
                rows.append(Row(key: cost.title, value: primary + used, strong: true))
                if let apiCredits = cost.apiCreditsLine, !tileIDs.contains("api") {
                    rows.append(Row(key: "API credits", value: apiCredits, strong: true))
                }
            } else {
                rows.append(Row(key: cost.title, value: cost.spendLine + used, strong: true))
            }
        }
        if self.model.menuMode != .glance, let ledger = self.model.tokenUsage {
            rows.append(Row(
                key: "Session cost",
                value: ledger.sessionLine,
                strong: true,
                detail: ledger.sessionDetailLine))
            rows.append(Row(key: "This month", value: ledger.monthLine, strong: true, detail: ledger.monthDetailLine))
            if let hint = ledger.hintLine, !hint.isEmpty {
                rows.append(Row(key: "Note", value: "", detail: hint))
            }
        }
        if self.model.menuMode != .glance, let peak = self.model.peakHoursText {
            rows.append(Row(key: "Peak hours", value: peak))
        }
        for metric in self.model.metrics where metric.percent == nil {
            let value = [metric.resetText, metric.detailText].compactMap(\.self).joined(separator: " \u{00B7} ")
            rows.append(Row(key: metric.title, value: value.isEmpty ? "\u{2014}" : value))
        }
        if self.model.menuMode == .operator, let insights = self.model.insights {
            let lines = [
                insights.contextLine, insights.compactionLine, insights.todayLine, insights.blockLine,
                insights.modelLine, insights.projectLine, insights.reliabilityLine, insights.routingLine,
            ]
            for line in lines.compactMap(\.self) where !line.isEmpty {
                if let pair = RunicRelief.keyValue(line) {
                    rows.append(Row(key: pair.key, value: pair.value))
                } else {
                    rows.append(Row(key: line, value: ""))
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
}

/// One window as an instrument module: the engraved title and the reset
/// capsule, a large tabular readout, the trough gauge with its scale and
/// pace detent, and the pace line under a small LED.
struct ReliefWindowModule: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let exhausted = RunicRelief.isExhausted(percent: self.metric.percent, style: self.metric.percentStyle)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                ReliefLabel(text: self.metric.title, size: 10)
                Spacer(minLength: 8)
                if let reset = RunicRelief.capsuleText(self.metric.resetText) {
                    ReliefCapsule(text: reset, tone: exhausted ? self.runicTheme.warm : nil)
                }
            }
            if let percent = self.metric.percent, self.displayMode.showsPercent {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(percent.rounded()))")
                        .font(RunicRelief.numeral(42, .medium))
                        .skinFace()
                        .tracking(-1)
                        .foregroundStyle(exhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                    Text("%")
                        .font(RunicRelief.face(22, .medium))
                        .skinFace()
                        .foregroundStyle(exhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                    Text(self.metric.percentStyle.labelSuffix)
                        .font(RunicRelief.face(14))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .padding(.leading, 4)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
            if let percent = self.metric.percent, self.displayMode.showsBars {
                ReliefGauge(
                    percent: percent,
                    accessibilityLabel: "\(self.metric.title), \(self.metric.percentStyle.accessibilityLabel)",
                    nib: exhausted ? RunicRelief.ledRed : RunicRelief.signal,
                    marker: RunicRelief.paceMarker(
                        percent: percent,
                        style: self.metric.percentStyle,
                        detail: self.metric.detailText))
            }
            if let detail = self.metric.detailText, !detail.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ReliefLED(color: self.paceLED(detail), size: 5)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    Text(detail)
                        .font(RunicRelief.face(11))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Green when on pace or behind, amber when ahead of it.
    private func paceLED(_ detail: String) -> Color {
        let lower = detail.lowercased()
        if lower.contains("ahead") || lower.contains("runs out") { return RunicRelief.ledAmber }
        return RunicRelief.ledGreen
    }
}
