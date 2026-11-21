import AppKit
import RunicCore
import SwiftUI

/// The provider card as a glass instrument: brand tile, name and pills in
/// the header with the status badge; a full error banner when the refresh
/// failed; each window in a matte well with a 30pt tabular numeral and the
/// capillary bar; then balance, cost and insights as key-value wells.
/// Sections the model leaves empty are omitted.
struct LiquidGlassProviderPage: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            self.header

            if self.model.subtitleStyle == .error {
                LiquidGlassErrorBanner(
                    message: self.model.subtitleText,
                    provider: self.model.provider,
                    isAuth: self.isAuthError,
                    isServedByCLIFallback: self.model.isServedByCLIFallback)
            } else if self.model.isServedByCLIFallback {
                LiquidGlassErrorBanner(
                    message: "Read through the Claude CLI: Runic's copy of the login expired, "
                        + "so cost and reset credits are unavailable.",
                    provider: self.model.provider,
                    isAuth: true,
                    isServedByCLIFallback: true,
                    isAdvisory: true)
            }

            if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
                LiquidGlassWell(padding: 12) {
                    MenuEmptyStateView(
                        providerName: self.model.providerName,
                        placeholder: placeholder,
                        needsCredentials: self.model.needsCredentials,
                        isHighlighted: self.isHighlighted)
                }
            }

            ForEach(self.model.metrics) { metric in
                LiquidGlassWindowWell(metric: metric, displayMode: self.model.usageMetricDisplayMode)
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
        .padding(RunicLiquidGlass.panelInset)
        .frame(width: self.width, alignment: .leading)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                LiquidGlassProviderMark(
                    image: ProviderBrandIcon.image(for: self.model.provider, size: 22),
                    name: self.model.providerName,
                    tint: self.brandColor,
                    size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.model.providerName)
                        .font(RunicLiquidGlass.header())
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .accessibilityAddTraits(.isHeader)
                    if self.model.subtitleStyle != .error, !self.statusLine.isEmpty {
                        Text(self.statusLine)
                            .font(RunicLiquidGlass.body(11))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 6)
                if let badge = self.model.headerBadge {
                    LiquidGlassPill(
                        text: badge.text,
                        systemImage: Self.badgeIcon(badge.style),
                        tone: Self.badgeTone(badge.style))
                }
            }
            if !self.model.email.isEmpty || self.model.planText?.isEmpty == false {
                HStack(spacing: 6) {
                    if !self.model.email.isEmpty {
                        LiquidGlassPill(text: self.model.email, systemImage: "person.crop.circle")
                            .layoutPriority(1)
                    }
                    if let plan = self.model.planText, !plan.isEmpty {
                        LiquidGlassPill(text: plan, systemImage: "sparkles", tone: .accent)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(2)
                    }
                    Spacer(minLength: 0)
                }
            }
            if let topModel = self.model.topModelLine, !topModel.isEmpty {
                Text(topModel)
                    .font(RunicLiquidGlass.body(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if self.model.menuMode != .glance, let peak = self.model.peakHoursText {
                Text("Peak hours: \(peak)")
                    .font(RunicLiquidGlass.body(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    /// "Connected · updated 4m ago" — the connection and the refresh line.
    private var statusLine: String {
        let subtitle = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if let connection = self.model.insights?.connectionLine,
           let value = RunicLiquidGlass.keyValue(connection)?.value
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

    private static func badgeTone(_ style: UsageMenuCardView.Model.HeaderBadgeStyle) -> LiquidGlassPill.Tone {
        switch style {
        case .info: .accent
        case .warning: .caution
        case .error: .critical
        }
    }

    private static func badgeIcon(_ style: UsageMenuCardView.Model.HeaderBadgeStyle) -> String {
        switch style {
        case .info: "arrow.triangle.2.circlepath"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.circle.fill"
        }
    }

    // MARK: Sections

    private func bankedResets(_ text: String) -> some View {
        LiquidGlassWell(padding: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.runicTheme.tertiary)
                    .accessibilityHidden(true)
                LiquidGlassLabel(text: "Banked resets")
                Spacer(minLength: 8)
                Text(text)
                    .font(RunicLiquidGlass.numeric(12, .semibold))
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
            LiquidGlassSectionTitle(title: "Credits", systemImage: "creditcard")
            LiquidGlassWell {
                LiquidGlassKeyValue(
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
            LiquidGlassSectionTitle(
                title: cost.title,
                systemImage: "dollarsign.circle",
                trailing: cost.percentUsed.map { String(format: "%.0f%% used", min(100, max(0, $0))) })
            LiquidGlassWell {
                VStack(alignment: .leading, spacing: 8) {
                    if let percent = cost.percentUsed {
                        BorosilicateCapillaryBar(
                            percent: percent,
                            tint: Self.liquidTint(used: percent, theme: self.runicTheme),
                            accessibilityLabel: "Extra usage spent")
                    }
                    LiquidGlassKeyValue(
                        label: "Spend",
                        value: cost.primarySpendLine ?? cost.spendLine,
                        numeric: true)
                    if cost.primarySpendLine != nil, let apiCredits = cost.apiCreditsLine {
                        LiquidGlassHairline()
                        LiquidGlassKeyValue(label: "API credits", value: apiCredits, numeric: true)
                    }
                }
            }
        }
    }

    private func ledgerSection(_ ledger: UsageMenuCardView.Model.TokenUsageSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LiquidGlassSectionTitle(title: "Cost", systemImage: "chart.bar.xaxis", trailing: ledger.updatedLine)
            LiquidGlassWell {
                VStack(alignment: .leading, spacing: 4) {
                    LiquidGlassKeyValue(
                        label: "Session",
                        value: ledger.sessionLine,
                        detail: ledger.sessionDetailLine)
                    LiquidGlassHairline()
                    LiquidGlassKeyValue(
                        label: "This month",
                        value: ledger.monthLine,
                        detail: ledger.monthDetailLine)
                    if let hint = ledger.hintLine, !hint.isEmpty {
                        Text(hint)
                            .font(RunicLiquidGlass.body(11))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let error = ledger.errorLine?.trimmingCharacters(in: .whitespacesAndNewlines), !error.isEmpty {
                LiquidGlassInlineError(text: error, copyText: ledger.errorCopyText ?? error)
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
            LiquidGlassSectionTitle(title: insights.title, systemImage: "sparkle", trailing: insights.updatedLine)
            if !rows.isEmpty {
                LiquidGlassWell {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { LiquidGlassHairline() }
                            if let pair = RunicLiquidGlass.keyValue(row.line) {
                                LiquidGlassKeyValue(label: pair.key, value: pair.value, detail: row.detail)
                            } else {
                                LiquidGlassKeyValue(label: row.line, value: "", detail: row.detail)
                            }
                        }
                    }
                }
            }
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(self.runicTheme.secondary)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    Text(note)
                        .font(RunicLiquidGlass.body(11.5))
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
                LiquidGlassInlineError(text: error, copyText: error)
            }
        }
    }

    /// Sapphire while there is room, amber when running hot, red when spent.
    static func liquidTint(used: Double, theme: RunicThemePalette) -> Color {
        if used >= 99.5 { return theme.warm }
        if used >= 80 { return theme.highlight }
        return theme.accent
    }
}

// MARK: - Window well

/// One window: the label and reset on top, the hero numeral, the capillary
/// with its pace needle, and the pace detail beneath — all inside a matte
/// well so the digits never sit on blur.
struct LiquidGlassWindowWell: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let exhausted = RunicLiquidGlass.isExhausted(self.metric)
        let tint = LiquidGlassProviderPage.liquidTint(
            used: RunicLiquidGlass.usedShare(self.metric) ?? 0,
            theme: self.runicTheme)
        LiquidGlassWell(padding: 12, tint: exhausted ? self.runicTheme.warm : nil) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    LiquidGlassLabel(text: self.metric.title)
                        .layoutPriority(1)
                    Spacer(minLength: 6)
                    if let reset = self.metric.resetText, !reset.isEmpty {
                        Text(reset)
                            .font(RunicLiquidGlass.numeric(11, .medium))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if let percent = self.metric.percent, self.displayMode.showsPercent {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(percent.rounded()))")
                            .font(RunicLiquidGlass.hero())
                            .skinFace()
                            .foregroundStyle(exhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                        Text("%")
                            .font(RunicLiquidGlass.header())
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                        Text(self.metric.percentStyle.labelSuffix)
                            .font(RunicLiquidGlass.body(11.5, .medium))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .padding(.leading, 3)
                        Spacer(minLength: 0)
                        if exhausted {
                            LiquidGlassPill(text: "Exhausted", systemImage: "xmark.octagon.fill", tone: .critical)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if let percent = self.metric.percent, self.displayMode.showsBars {
                    BorosilicateCapillaryBar(
                        percent: percent,
                        tint: tint,
                        accessibilityLabel: "\(self.metric.title), \(self.metric.percentStyle.accessibilityLabel)",
                        marker: RunicLiquidGlass.paceMarker(for: self.metric))
                }
                if let detail = self.metric.detailText, !detail.isEmpty {
                    Text(detail)
                        .font(RunicLiquidGlass.body(11))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Errors

/// The refresh error in full: up to six wrapped lines, never clipped
/// sideways, with copy, retry and the sign-in recovery the error calls for.
struct LiquidGlassErrorBanner: View {
    let message: String
    let provider: UsageProvider
    let isAuth: Bool
    let isServedByCLIFallback: Bool
    /// A notice rather than a failure (Claude read through the CLI).
    var isAdvisory = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let tone = self.isAdvisory ? self.runicTheme.highlight : self.runicTheme.warm
        let text = self.message.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: self.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tone)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(self.title)
                        .font(RunicLiquidGlass.body(12, .semibold))
                        .skinFace()
                        .foregroundStyle(tone)
                        .lineLimit(1)
                    Text(text.isEmpty ? "Refresh failed." : text)
                        .font(RunicLiquidGlass.body(11.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .layoutPriority(1)
                if !text.isEmpty, !self.isAdvisory {
                    LiquidGlassCopyButton(copyText: text)
                }
            }
            HStack(spacing: 6) {
                if self.isAuth || self.isServedByCLIFallback {
                    self.recoveryButton
                }
                if !self.isAdvisory {
                    LiquidGlassButton(title: "Retry", systemImage: "arrow.clockwise") {
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
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: RunicLiquidGlass.tileRadius, style: .continuous)
            ZStack {
                LiquidGlassWellBackground(tint: tone)
                shape.strokeBorder(tone.opacity(0.35), lineWidth: 0.5)
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
            LiquidGlassButton(title: "Reconnect Claude\u{2026}", systemImage: "key.horizontal", prominent: true) {
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
            LiquidGlassButton(title: "Add account\u{2026}", systemImage: "person.badge.key", prominent: true) {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }
}

/// A compact error line inside a section (ledger, insights).
struct LiquidGlassInlineError: View {
    let text: String
    let copyText: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(self.runicTheme.warm)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(self.text)
                .font(RunicLiquidGlass.body(11))
                .skinFace()
                .foregroundStyle(self.runicTheme.primaryText)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            LiquidGlassCopyButton(copyText: self.copyText)
        }
        .padding(8)
        .background(LiquidGlassWellBackground(tint: self.runicTheme.warm))
    }
}
