import AppKit
import RunicCore
import SwiftUI

// MARK: - Atelier Provider Page

/// Architectural specification sheet for a single provider: dot-grid studio
/// header with index code & tier pill, primary Session sheet framed by electric
/// cobalt crop-marks (`┌ ┐ └ ┘`) with 3-column hairline spec strip, Secondary
/// Weekly & Model sheets, and crisp Ledger / Insights / Error sections.
struct AtelierProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        let hasError = self.model.subtitleStyle == .error || self.model.isServedByCLIFallback
        let hasEmptyPlaceholder = self.model.metrics.isEmpty && self.model.placeholder != nil
        let hasMetrics = !self.model.metrics.isEmpty
        let hasCredits = self.model.creditsText != nil
        let hasCost = self.model.providerCost != nil
        let hasLedger = self.model.menuMode != .glance && self.model.tokenUsage != nil

        VStack(alignment: .leading, spacing: 0) {
            self.header
            AtelierHairline()

            VStack(alignment: .leading, spacing: 0) {
                if self.model.subtitleStyle == .error {
                    AtelierErrorBanner(
                        message: self.model.subtitleText,
                        provider: self.model.provider,
                        isAuth: self.isAuthError,
                        isServedByCLIFallback: self.model.isServedByCLIFallback)
                        .padding(RunicAtelier.panelInset)
                } else if self.model.isServedByCLIFallback {
                    AtelierErrorBanner(
                        message: "Read through the Claude CLI: Runic's copy of the login expired, "
                            + "so cost and reset credits are unavailable.",
                        provider: self.model.provider,
                        isAuth: true,
                        isServedByCLIFallback: true,
                        isAdvisory: true)
                        .padding(RunicAtelier.panelInset)
                }

                if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                    if hasError { AtelierHairline() }
                    MenuEmptyStateView(
                        providerName: self.model.providerName,
                        placeholder: placeholder,
                        needsCredentials: self.model.needsCredentials,
                        isHighlighted: self.isHighlighted)
                        .padding(.horizontal, RunicAtelier.panelInset)
                        .padding(.vertical, 10)
                }

                if let primary = self.model.metrics.first {
                    if hasError || hasEmptyPlaceholder { AtelierHairline() }
                    AtelierPrimarySpecSheet(
                        metric: primary,
                        displayMode: self.model.usageMetricDisplayMode,
                        bankedResetsText: self.model.bankedResetsText)
                }

                ForEach(Array(self.model.metrics.dropFirst())) { metric in
                    AtelierHairline()
                    AtelierSecondarySpecSheet(
                        metric: metric,
                        displayMode: self.model.usageMetricDisplayMode)
                }

                if let credits = self.model.creditsText {
                    if hasError || hasEmptyPlaceholder || hasMetrics { AtelierHairline() }
                    self.creditsSection(credits)
                }

                if let cost = self.model.providerCost {
                    if hasError || hasEmptyPlaceholder || hasMetrics || hasCredits { AtelierHairline() }
                    self.providerCostSection(cost)
                }

                if self.model.menuMode != .glance, let ledger = self.model.tokenUsage {
                    if hasError || hasEmptyPlaceholder || hasMetrics || hasCredits || hasCost { AtelierHairline() }
                    self.ledgerSection(ledger)
                }

                if self.model.menuMode == .operator, let insights = self.model.insights {
                    if hasError || hasEmptyPlaceholder || hasMetrics || hasCredits || hasCost || hasLedger {
                        AtelierHairline()
                    }
                    self.insightsSection(insights)
                }
            }
            .background(self.runicTheme.cardFill)
        }
        .skinFace()
        .frame(width: self.width, alignment: .leading)
    }

    // MARK: Masthead on Dot-Grid Paper

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Text(self.providerCode)
                    .font(RunicAtelier.mono(9.5, .medium))
                    .skinFace()
                    .tracking(0.8)
                    .foregroundStyle(self.runicTheme.secondaryText)
                if !self.model.email.isEmpty {
                    Text("\u{00B7}")
                        .font(RunicAtelier.mono(9.5))
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Text(self.model.email)
                        .font(RunicAtelier.mono(9.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 6)
                if let plan = self.model.planText, !plan.isEmpty {
                    AtelierPillBadge(text: plan.uppercased(), tone: .neutral)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            HStack(alignment: .center, spacing: 10) {
                if let icon = ProviderBrandIcon.image(for: self.model.provider, size: 24) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.model.providerName)
                        .font(RunicAtelier.display(20, .regular))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                    if self.model.subtitleStyle != .error, !self.statusLine.isEmpty {
                        Text(self.statusLine)
                            .font(RunicAtelier.mono(9.5))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 6)
                if let badge = self.model.headerBadge {
                    AtelierPillBadge(
                        text: badge.text.uppercased(),
                        tone: Self.badgeTone(badge.style))
                }
            }

            if let topModel = self.model.topModelLine, !topModel.isEmpty {
                Text(topModel)
                    .font(RunicAtelier.sans(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if self.model.menuMode != .glance, let peak = self.model.peakHoursText {
                Text("Peak hours: \(peak)")
                    .font(RunicAtelier.mono(9.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(RunicAtelier.panelInset)
        .background(AtelierDotGridPaper())
    }

    private var providerCode: String {
        let list = UsageProvider.allCases
        let idx = (list.firstIndex(of: self.model.provider) ?? 0) + 1
        return String(format: "No. %02d / %02d", idx, list.count)
    }

    private var statusLine: String {
        let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if let connection = self.model.insights?.connectionLine,
           let value = RunicAtelier.keyValue(connection)?.value
        {
            parts.append(value.prefix(1).uppercased() + value.dropFirst())
        }
        if !subtitle.isEmpty { parts.append(subtitle) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }

    private static func badgeTone(_ style: UsageMenuCardView.Model.HeaderBadgeStyle) -> AtelierPillBadge.Tone {
        switch style {
        case .info, .warning: .neutral
        case .error: .critical
        }
    }

    // MARK: Sections

    private func creditsSection(_ credits: String) -> some View {
        let hint = self.model.creditsHintText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return VStack(alignment: .leading, spacing: 6) {
            AtelierKicker(text: "Credits")
            AtelierSpecRow(
                label: "Balance",
                value: credits,
                detail: hint.isEmpty ? nil : hint,
                copyText: hint.isEmpty ? nil : (self.model.creditsHintCopyText ?? hint))
        }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 10)
    }

    private func providerCostSection(_ cost: UsageMenuCardView.Model.ProviderCostSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                AtelierKicker(text: cost.title)
                Spacer(minLength: 6)
                if let pct = cost.percentUsed {
                    Text(String(format: "%.0f%% used", min(100, max(0, pct))))
                        .font(RunicAtelier.mono(9.5, .medium))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                if let percent = cost.percentUsed {
                    AtelierGauge(
                        percent: percent,
                        tint: RunicAtelier.gaugeTint(used: percent, theme: self.runicTheme),
                        accessibilityLabel: "Extra usage spent")
                }
                AtelierSpecRow(label: "Spend", value: cost.primarySpendLine ?? cost.spendLine)
                if cost.primarySpendLine != nil, let apiCredits = cost.apiCreditsLine {
                    AtelierHairline()
                    AtelierSpecRow(label: "API credits", value: apiCredits)
                }
            }
        }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 10)
    }

    private func ledgerSection(_ ledger: UsageMenuCardView.Model.TokenUsageSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                AtelierKicker(text: "Local ledger")
                Spacer(minLength: 6)
                Text(ledger.updatedLine)
                    .font(RunicAtelier.mono(9.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 4) {
                if let pair = RunicAtelier.keyValue(ledger.sessionLine) {
                    AtelierSpecRow(label: pair.key, value: pair.value, detail: ledger.sessionDetailLine)
                } else {
                    AtelierSpecRow(label: "Today", value: ledger.sessionLine, detail: ledger.sessionDetailLine)
                }
                AtelierHairline()
                if let pair = RunicAtelier.keyValue(ledger.monthLine) {
                    AtelierSpecRow(label: pair.key, value: pair.value, detail: ledger.monthDetailLine)
                } else {
                    AtelierSpecRow(label: "30 days", value: ledger.monthLine, detail: ledger.monthDetailLine)
                }
                if let hint = ledger.hintLine?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
                    AtelierHairline()
                    Text(hint)
                        .font(RunicAtelier.sans(10.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            if let error = ledger.errorLine?.trimmingCharacters(in: .whitespacesAndNewlines), !error.isEmpty {
                AtelierInlineError(text: error, copyText: ledger.errorCopyText ?? error)
            }
        }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 10)
    }

    private func insightsSection(_ insights: UsageMenuCardView.Model.InsightsSection) -> some View {
        let rows: [(line: String, detail: String?)] = [
            (insights.connectionLine, insights.connectionDetail),
            (insights.contextLine, insights.contextDetail),
            (insights.compactionLine, insights.compactionDetail),
            (insights.todayLine, insights.todayDetail),
            (insights.blockLine, insights.blockDetail),
            (insights.projectLine, insights.projectDetail),
            (insights.anomalyLine, insights.anomalyDetail),
            (insights.reliabilityLine, insights.reliabilityDetail),
            (insights.routingLine, insights.routingDetail),
        ].compactMap { pair in
            guard let line = pair.0?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else {
                return nil
            }
            return (line, pair.1)
        }
        let notes: [String] = [insights.forecastLine, insights.modelLine].compactMap {
            guard let text = $0?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                AtelierKicker(text: insights.title)
                Spacer(minLength: 6)
                if let updated = insights.updatedLine {
                    Text(updated)
                        .font(RunicAtelier.mono(9.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { AtelierHairline() }
                        if let pair = RunicAtelier.keyValue(row.line) {
                            AtelierSpecRow(label: pair.key, value: pair.value, detail: row.detail)
                        } else {
                            AtelierSpecRow(label: row.line, value: "", detail: row.detail)
                        }
                    }
                }
            }
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                HStack(alignment: .top, spacing: 6) {
                    Text("\u{21B3}")
                        .font(RunicAtelier.mono(10))
                        .foregroundStyle(self.runicTheme.accent)
                    Text(note)
                        .font(RunicAtelier.sans(10.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay { ClickToCopyOverlay(copyText: note) }
                }
            }
            if let error = insights.errorLine?.trimmingCharacters(in: .whitespacesAndNewlines), !error.isEmpty {
                AtelierInlineError(text: error, copyText: error)
            }
        }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 10)
    }
}

// MARK: - Primary & Secondary Spec Sheets

private struct AtelierPrimarySpecSheet: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    let bankedResetsText: String?
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        let exhausted = RunicAtelier.isExhausted(self.metric)
        let usedShare = RunicAtelier.usedShare(self.metric) ?? 0
        let tint = exhausted
            ? self.runicTheme.warm
            : (usedShare >= 80 ? self.runicTheme.highlight : self.runicTheme.accent)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                AtelierKicker(text: self.metric.title)
                Spacer(minLength: 6)
                if exhausted {
                    AtelierPillBadge(text: "EXHAUSTED", tone: .critical)
                }
            }

            if let percent = self.metric.percent, self.displayMode.showsPercent {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(percent.rounded()))%")
                        .font(RunicAtelier.display(26, .regular))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                    Text(exhausted ? "exhausted" : self.metric.percentStyle.labelSuffix)
                        .font(RunicAtelier.display(20, .regular))
                        .skinFace()
                        .foregroundStyle(exhausted ? self.runicTheme.warm : self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            } else if self.metric.percent == nil, let text = self.metric.resetText, !text.isEmpty {
                Text(text)
                    .font(RunicAtelier.display(22, .regular))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
            }

            if let percent = self.metric.percent, self.displayMode.showsBars {
                AtelierGauge(
                    percent: percent,
                    tint: tint,
                    accessibilityLabel: "\(self.metric.title), \(self.metric.percentStyle.accessibilityLabel)",
                    marker: RunicAtelier.paceMarker(for: self.metric),
                    height: 6)
            }

            if self.metric.percent != nil {
                let cells = self.specCells
                if !cells.isEmpty {
                    AtelierHairline()
                        .padding(.top, 2)
                    HStack(spacing: 0) {
                        ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                            if index > 0 {
                                Rectangle()
                                    .fill(self.runicTheme.cardStroke)
                                    .frame(width: 1)
                                    .padding(.vertical, 2)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cell.label)
                                    .font(RunicAtelier.mono(8, .medium))
                                    .skinFace()
                                    .tracking(0.6)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                                    .lineLimit(1)
                                Text(cell.value)
                                    .font(RunicAtelier.mono(10.5, .medium))
                                    .skinFace()
                                    .foregroundStyle(cell.accent ?? self.runicTheme.primaryText)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, index == 0 ? 0 : 8)
                            .padding(.trailing, index == cells.count - 1 ? 0 : 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else if let detail = self.metric.detailText, !detail.isEmpty {
                Text(detail)
                    .font(RunicAtelier.sans(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(exhausted ? self.runicTheme.warm.opacity(dark ? 0.08 : 0.04) : Color.clear)
        .overlay { AtelierCornerReticles(armLength: 7) }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 10)
    }

    private var specCells: [(label: String, value: String, accent: Color?)] {
        var list: [(String, String, Color?)] = []
        if let reset = self.metric.resetText, !reset.isEmpty {
            let trimmed = reset
                .replacingOccurrences(of: "Resets in ", with: "")
                .replacingOccurrences(of: "Resets ", with: "")
            list.append(("NEXT RESET", trimmed, nil))
        }
        let hasBanked = !(self.bankedResetsText?.isEmpty ?? true)
        if let detail = self.metric.detailText, !detail.isEmpty {
            let duplicatesBanked = hasBanked && (
                detail == self.bankedResetsText
                    || detail.localizedCaseInsensitiveContains("banked reset"))
            if !duplicatesBanked {
                if detail.hasPrefix("Pace: ") {
                    list.append(("PACE", String(detail.dropFirst("Pace: ".count)), nil))
                } else {
                    list.append(("DETAIL", detail, nil))
                }
            }
        }
        if let banked = self.bankedResetsText, !banked.isEmpty {
            let compact = banked.replacingOccurrences(of: "usable until ", with: "until ")
            list.append(("BANKED", compact, self.runicTheme.tertiary))
        }
        return list
    }
}

private struct AtelierSecondarySpecSheet: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let exhausted = RunicAtelier.isExhausted(self.metric)
        let usedShare = RunicAtelier.usedShare(self.metric) ?? 0
        let tint = exhausted
            ? self.runicTheme.warm
            : (usedShare >= 80 ? self.runicTheme.highlight : self.runicTheme.accent)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                AtelierKicker(text: self.metric.title)
                    .layoutPriority(1)
                Spacer(minLength: 6)
                if self.metric.percent != nil, let reset = self.metric.resetText, !reset.isEmpty {
                    Text(reset)
                        .font(RunicAtelier.mono(9.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            if let percent = self.metric.percent, self.displayMode.showsPercent {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(percent.rounded()))%")
                        .font(RunicAtelier.display(20, .regular))
                        .skinFace()
                        .foregroundStyle(exhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                    Text(self.metric.percentStyle.labelSuffix)
                        .font(RunicAtelier.display(16, .regular))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Spacer(minLength: 0)
                    if exhausted {
                        AtelierPillBadge(text: "EXHAUSTED", tone: .critical)
                    }
                }
                .accessibilityElement(children: .combine)
            } else if self.metric.percent == nil, let text = self.metric.resetText, !text.isEmpty {
                Text(text)
                    .font(RunicAtelier.display(18, .regular))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
            }
            if let percent = self.metric.percent, self.displayMode.showsBars {
                AtelierGauge(
                    percent: percent,
                    tint: tint,
                    accessibilityLabel: "\(self.metric.title), \(self.metric.percentStyle.accessibilityLabel)",
                    marker: RunicAtelier.paceMarker(for: self.metric))
            }
            if let detail = self.metric.detailText, !detail.isEmpty {
                Text(detail)
                    .font(RunicAtelier.mono(9.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 10)
    }
}

// MARK: - Error Banners

private struct AtelierErrorBanner: View {
    let message: String
    let provider: UsageProvider
    let isAuth: Bool
    let isServedByCLIFallback: Bool
    var isAdvisory: Bool = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let text = self.message.trimmingCharacters(in: .whitespacesAndNewlines)
        let accent = self.isAdvisory ? self.runicTheme.highlight : self.runicTheme.warm
        AtelierSheet(padding: 10, tint: accent) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: self.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(self.title)
                            .font(RunicAtelier.sans(12, .medium))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.primaryText)
                        if !text.isEmpty {
                            Text(text)
                                .font(RunicAtelier.sans(10.5))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .lineLimit(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .layoutPriority(1)
                    if !text.isEmpty, !self.isAdvisory {
                        AtelierCopyButton(copyText: text)
                    }
                }
                HStack(spacing: 6) {
                    if self.isAuth || self.isServedByCLIFallback {
                        self.recoveryButton
                    }
                    if !self.isAdvisory {
                        AtelierButton(title: "Retry", arrow: "\u{21BB}") {
                            NotificationCenter.default.post(
                                name: .runicReloadProvider,
                                object: nil,
                                userInfo: ["provider": self.provider.rawValue])
                        }
                        .accessibilityLabel("Retry refreshing this provider")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        if self.isAdvisory { return "Limited data" }
        return self.isAuth ? "Sign-in needed" : "Couldn't refresh"
    }

    private var symbol: String {
        if self.isAdvisory { return "info.circle.fill" }
        return self.isAuth ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle.fill"
    }

    @ViewBuilder
    private var recoveryButton: some View {
        if self.provider == .claude {
            AtelierButton(title: "Reconnect Claude", arrow: "\u{2197}", prominent: true) {
                NotificationCenter.default.post(
                    name: .runicReloadProvider,
                    object: nil,
                    userInfo: ["provider": UsageProvider.claude.rawValue])
            }
            .help(self.isServedByCLIFallback
                ? "Runic's copy of the Claude login has expired, so usage is read through the Claude CLI."
                : "Re-reads the Claude CLI's login from Keychain; macOS may ask once.")
            .accessibilityLabel("Reconnect Claude from the CLI's Keychain login")
        } else {
            AtelierButton(title: "Add account", arrow: "\u{2197}", prominent: true) {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }
}

private struct AtelierInlineError: View {
    let text: String
    let copyText: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        AtelierSheet(padding: 8, tint: self.runicTheme.warm) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(self.runicTheme.warm)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                Text(self.text)
                    .font(RunicAtelier.sans(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                AtelierCopyButton(copyText: self.copyText)
            }
        }
    }
}
