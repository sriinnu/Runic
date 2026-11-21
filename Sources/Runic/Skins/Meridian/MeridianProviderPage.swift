import AppKit
import RunicCore
import SwiftUI

// MARK: - Meridian Provider Page

/// Single-caliber chronometer view: provider bezel medallion and plan plaque in
/// the masthead, primary quota rendered with a 200° power-reserve arc dial (plus
/// sub-meters as calibrated railway-track gauges), and credits/cost/insights in
/// chamfered specification plates.
struct MeridianProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            self.header

            if self.model.subtitleStyle == .error {
                MeridianErrorBanner(
                    message: self.model.subtitleText,
                    provider: self.model.provider,
                    isAuth: self.isAuthError,
                    isServedByCLIFallback: self.model.isServedByCLIFallback)
            } else if self.model.isServedByCLIFallback {
                MeridianErrorBanner(
                    message: "Read through the Claude CLI: Runic's copy of the login expired, "
                        + "so cost and reset credits are unavailable.",
                    provider: self.model.provider,
                    isAuth: true,
                    isServedByCLIFallback: true,
                    isAdvisory: true)
            }

            if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                MeridianDialPlate(padding: 12) {
                    MenuEmptyStateView(
                        providerName: self.model.providerName,
                        placeholder: placeholder,
                        needsCredentials: self.model.needsCredentials,
                        isHighlighted: self.isHighlighted)
                }
            }

            if let primary = self.model.metrics.first {
                MeridianPrimaryChronometerPlate(
                    metric: primary,
                    displayMode: self.model.usageMetricDisplayMode)
            }

            ForEach(Array(self.model.metrics.dropFirst())) { metric in
                MeridianSubMeterPlate(metric: metric, displayMode: self.model.usageMetricDisplayMode)
            }

            if let banked = self.model.bankedResetsText, !banked.isEmpty {
                self.bankedResets(banked)
            }

            if let credits = self.model.creditsText {
                self.creditsSection(credits)
            }

            if let cost = self.model.providerCost {
                self.providerCostSection(cost)
            }

            if self.model.menuMode != .glance, let ledger = self.model.tokenUsage {
                self.ledgerSection(ledger)
            }

            if self.model.menuMode == .operator, let insights = self.model.insights {
                self.insightsSection(insights)
            }
        }
        .skinFace()
        .padding(RunicMeridian.panelInset)
        .frame(width: self.width, alignment: .leading)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                MeridianBrandMedallion(
                    image: ProviderBrandIcon.image(for: self.model.provider, size: 22),
                    name: self.model.providerName,
                    tint: self.brandColor,
                    size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(self.model.providerName)
                        .font(RunicMeridian.display(17, weight: .semibold))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .accessibilityAddTraits(.isHeader)
                    if self.model.subtitleStyle != .error, !self.statusLine.isEmpty {
                        Text(self.statusLine)
                            .font(RunicMeridian.body(11))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 6)
                if let badge = self.model.headerBadge {
                    MeridianJewelPill(
                        text: badge.text.uppercased(),
                        jewel: true,
                        tone: Self.badgeTone(badge.style))
                }
            }

            if !self.model.email.isEmpty || self.model.planText?.isEmpty == false {
                HStack(spacing: 6) {
                    if !self.model.email.isEmpty {
                        MeridianJewelPill(text: self.model.email)
                            .layoutPriority(1)
                    }
                    if let plan = self.model.planText, !plan.isEmpty {
                        MeridianJewelPill(text: plan.uppercased(), jewel: true, tone: .accent)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(2)
                    }
                    Spacer(minLength: 0)
                }
            }

            if let topModel = self.model.topModelLine, !topModel.isEmpty {
                Text(topModel)
                    .font(RunicMeridian.body(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if self.model.menuMode != .glance, let peak = self.model.peakHoursText {
                Text("Peak hours: \(peak)")
                    .font(RunicMeridian.body(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private var statusLine: String {
        let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if let connection = self.model.insights?.connectionLine,
           let value = RunicMeridian.keyValue(connection)?.value
        {
            parts.append(value.prefix(1).uppercased() + value.dropFirst())
        }
        if !subtitle.isEmpty { parts.append(parts.isEmpty ? subtitle : subtitle.lowercased()) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }

    private var brandColor: Color {
        let color = ProviderDescriptorRegistry.descriptor(for: self.model.provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private static func badgeTone(_ style: UsageMenuCardView.Model.HeaderBadgeStyle) -> MeridianJewelPill.Tone {
        switch style {
        case .info: .accent
        case .warning: .caution
        case .error: .critical
        }
    }

    // MARK: Sections

    private func bankedResets(_ text: String) -> some View {
        MeridianDialPlate(padding: 10, tint: self.runicTheme.tertiary) {
            HStack(spacing: 8) {
                Circle()
                    .fill(self.runicTheme.tertiary)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                MeridianLabel(text: "Banked resets")
                Spacer(minLength: 8)
                Text(text)
                    .font(RunicMeridian.mono(12, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func creditsSection(_ credits: String) -> some View {
        let hint = self.model.creditsHintText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return VStack(alignment: .leading, spacing: 6) {
            MeridianSectionTitle(title: "Credits", systemImage: "creditcard")
            MeridianDialPlate(padding: 10) {
                MeridianSpecRow(
                    label: "Balance",
                    value: credits,
                    detail: hint.isEmpty ? nil : hint,
                    numeric: true,
                    copyText: hint.isEmpty ? nil : (self.model.creditsHintCopyText ?? hint))
            }
        }
    }

    private func providerCostSection(_ cost: UsageMenuCardView.Model.ProviderCostSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MeridianSectionTitle(
                title: cost.title,
                systemImage: "dollarsign.circle",
                trailing: cost.percentUsed.map { String(format: "%.0f%% used", min(100, max(0, $0))) })
            MeridianDialPlate(padding: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    if let percent = cost.percentUsed {
                        MeridianRailwayGauge(
                            percent: percent,
                            tint: RunicMeridian.dialTint(used: percent, theme: self.runicTheme),
                            accessibilityLabel: "Extra usage spent")
                    }
                    MeridianSpecRow(label: "Spend", value: cost.primarySpendLine ?? cost.spendLine, numeric: true)
                    if cost.primarySpendLine != nil, let apiCredits = cost.apiCreditsLine {
                        MeridianHairline()
                        MeridianSpecRow(label: "API credits", value: apiCredits, numeric: true)
                    }
                }
            }
        }
    }

    private func ledgerSection(_ ledger: UsageMenuCardView.Model.TokenUsageSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MeridianSectionTitle(title: "Caliber log", systemImage: "chart.bar.xaxis", trailing: ledger.updatedLine)
            MeridianDialPlate(padding: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    MeridianSpecRow(label: "Session", value: ledger.sessionLine, detail: ledger.sessionDetailLine)
                    MeridianHairline()
                    MeridianSpecRow(label: "This month", value: ledger.monthLine, detail: ledger.monthDetailLine)
                    if let hint = ledger.hintLine, !hint.isEmpty {
                        Text(hint)
                            .font(RunicMeridian.body(11))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let error = ledger.errorLine?.trimmingCharacters(in: .whitespacesAndNewlines), !error.isEmpty {
                MeridianInlineError(text: error, copyText: ledger.errorCopyText ?? error)
            }
        }
    }

    private func insightsSection(_ insights: UsageMenuCardView.Model.InsightsSection) -> some View {
        let pairs: [(String?, String?)] = [
            (insights.contextLine, insights.contextDetail),
            (insights.compactionLine, insights.compactionDetail),
            (insights.todayLine, insights.todayDetail),
            (insights.blockLine, insights.blockDetail),
            (insights.modelLine, nil),
            (insights.projectLine, insights.projectDetail),
            (insights.reliabilityLine, insights.reliabilityDetail),
            (insights.routingLine, insights.routingDetail),
        ]
        let rows = pairs.compactMap { line, detail -> (line: String, detail: String?)? in
            guard let line, !line.isEmpty else { return nil }
            return (line, detail)
        }
        let notes = [insights.forecastLine, insights.anomalyLine, insights.anomalyDetail]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 6) {
            MeridianSectionTitle(title: insights.title, systemImage: "scope", trailing: insights.updatedLine)
            if !rows.isEmpty {
                MeridianDialPlate(padding: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { MeridianHairline() }
                            if let pair = RunicMeridian.keyValue(row.line) {
                                MeridianSpecRow(label: pair.key, value: pair.value, detail: row.detail)
                            } else {
                                MeridianSpecRow(label: row.line, value: "", detail: row.detail)
                            }
                        }
                    }
                }
            }
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                HStack(alignment: .top, spacing: 8) {
                    Rectangle()
                        .fill(self.runicTheme.accent)
                        .frame(width: 5, height: 5)
                        .rotationEffect(.degrees(45))
                        .padding(.top, 5)
                        .accessibilityHidden(true)
                    Text(note)
                        .font(RunicMeridian.body(11))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay { ClickToCopyOverlay(copyText: note) }
                }
                .padding(.horizontal, 2)
            }
            if let error = insights.errorLine?.trimmingCharacters(in: .whitespacesAndNewlines), !error.isEmpty {
                MeridianInlineError(text: error, copyText: error)
            }
        }
    }
}

// MARK: - Primary Chronometer & Sub-Meters

private struct MeridianPrimaryChronometerPlate: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let exhausted = RunicMeridian.isExhausted(self.metric)
        let usedShare = RunicMeridian.usedShare(self.metric) ?? 0
        let tint = RunicMeridian.dialTint(used: usedShare, theme: self.runicTheme)
        MeridianDialPlate(padding: 12, tint: exhausted ? self.runicTheme.warm : nil) {
            if let percent = self.metric.percent, self.displayMode.showsBars {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        MeridianPowerReserveArc(
                            percent: percent,
                            usedPercent: usedShare,
                            isUsedMode: self.metric.percentStyle == .used,
                            caption: self.metric.percentStyle == .used ? "used" : "reserve",
                            accessibilityLabel:
                            "\(self.metric.title), \(self.metric.percentStyle.accessibilityLabel)",
                            diameter: 108)
                            .frame(width: 108)

                        VStack(alignment: .leading, spacing: 5) {
                            MeridianLabel(text: self.metric.title)
                            if let reset = self.metric.resetText, !reset.isEmpty {
                                Text(reset)
                                    .font(RunicMeridian.mono(12, .semibold))
                                    .skinFace()
                                    .foregroundStyle(self.runicTheme.primaryText)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let detail = self.metric.detailText, !detail.isEmpty {
                                Text(detail)
                                    .font(RunicMeridian.body(11))
                                    .skinFace()
                                    .foregroundStyle(self.runicTheme.secondaryText)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if exhausted {
                                MeridianJewelPill(text: "EXHAUSTED", jewel: true, tone: .critical)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if let marker = RunicMeridian.paceMarker(for: self.metric) {
                        MeridianRailwayGauge(
                            percent: percent,
                            tint: tint,
                            accessibilityLabel: "\(self.metric.title) pace scale",
                            marker: marker,
                            height: 6)
                    }
                }
            } else {
                MeridianSubMeterContent(metric: self.metric, displayMode: self.displayMode)
            }
        }
    }
}

private struct MeridianSubMeterPlate: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let exhausted = RunicMeridian.isExhausted(self.metric)
        MeridianDialPlate(padding: 10, tint: exhausted ? self.runicTheme.warm : nil) {
            MeridianSubMeterContent(metric: self.metric, displayMode: self.displayMode)
        }
    }
}

private struct MeridianSubMeterContent: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let exhausted = RunicMeridian.isExhausted(self.metric)
        let tint = RunicMeridian.dialTint(
            used: RunicMeridian.usedShare(self.metric) ?? 0,
            theme: self.runicTheme)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MeridianLabel(text: self.metric.title)
                    .layoutPriority(1)
                Spacer(minLength: 6)
                if self.metric.percent != nil, let reset = self.metric.resetText, !reset.isEmpty {
                    Text(reset)
                        .font(RunicMeridian.mono(10.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            if let percent = self.metric.percent, self.displayMode.showsPercent {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(percent.rounded()))")
                        .font(RunicMeridian.display(24, weight: .semibold))
                        .skinFace()
                        .foregroundStyle(exhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                    Text("%")
                        .font(RunicMeridian.mono(11))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Text(self.metric.percentStyle.labelSuffix)
                        .font(RunicMeridian.body(11, .medium))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .padding(.leading, 2)
                    Spacer(minLength: 0)
                    if exhausted {
                        MeridianJewelPill(text: "EXHAUSTED", jewel: true, tone: .critical)
                    }
                }
                .accessibilityElement(children: .combine)
            } else if self.metric.percent == nil, let text = self.metric.resetText, !text.isEmpty {
                Text(text)
                    .font(RunicMeridian.display(22, weight: .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
            }
            if let percent = self.metric.percent, self.displayMode.showsBars {
                MeridianRailwayGauge(
                    percent: percent,
                    tint: tint,
                    accessibilityLabel: "\(self.metric.title), \(self.metric.percentStyle.accessibilityLabel)",
                    marker: RunicMeridian.paceMarker(for: self.metric))
            }
            if let detail = self.metric.detailText, !detail.isEmpty {
                Text(detail)
                    .font(RunicMeridian.body(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Error Banners

private struct MeridianErrorBanner: View {
    let message: String
    let provider: UsageProvider
    let isAuth: Bool
    let isServedByCLIFallback: Bool
    var isAdvisory = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let tone = self.isAdvisory ? self.runicTheme.highlight : self.runicTheme.warm
        let text = self.message.trimmingCharacters(in: .whitespacesAndNewlines)
        MeridianDialPlate(padding: 10, tint: tone) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: self.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tone)
                        .padding(.top, 1)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(self.title)
                            .font(RunicMeridian.body(12, .semibold))
                            .skinFace()
                            .foregroundStyle(tone)
                            .lineLimit(1)
                        Text(text.isEmpty ? "Refresh failed." : text)
                            .font(RunicMeridian.body(11))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.primaryText)
                            .lineLimit(6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .layoutPriority(1)
                    if !text.isEmpty, !self.isAdvisory {
                        MeridianCopyButton(copyText: text)
                    }
                }
                HStack(spacing: 6) {
                    if self.isAuth || self.isServedByCLIFallback {
                        self.recoveryButton
                    }
                    if !self.isAdvisory {
                        MeridianButton(title: "Retry", systemImage: "arrow.clockwise") {
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
            MeridianButton(title: "Reconnect Claude\u{2026}", systemImage: "key.horizontal", prominent: true) {
                NotificationCenter.default.post(
                    name: .runicReloadProvider,
                    object: nil,
                    userInfo: ["provider": UsageProvider.claude.rawValue])
            }
            .help(self.isServedByCLIFallback
                ? "Runic's copy of the Claude login has expired, so usage is read through the Claude CLI "
                + "(no cost or reset credits). Reconnect re-reads the login from Keychain; macOS may ask once."
                : "Re-reads the Claude CLI's login from Keychain. macOS may ask once.")
            .accessibilityLabel("Reconnect Claude from the CLI's Keychain login")
        } else {
            MeridianButton(title: "Add account\u{2026}", systemImage: "person.badge.key", prominent: true) {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }
}

private struct MeridianInlineError: View {
    let text: String
    let copyText: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        MeridianDialPlate(padding: 8, tint: self.runicTheme.warm) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(self.runicTheme.warm)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                Text(self.text)
                    .font(RunicMeridian.body(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MeridianCopyButton(copyText: self.copyText)
            }
        }
    }
}
