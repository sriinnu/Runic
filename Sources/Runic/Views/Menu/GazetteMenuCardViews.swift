import AppKit
import RunicCore
import SwiftUI

// MARK: - Masthead

/// The provider header set as a newspaper masthead: a folio line (edition,
/// date, freshness), the provider's name as the nameplate, a deck of the
/// headline numbers, and the double rule that closes a masthead. Account
/// notes and recovery actions sit under the deck. Gazette only.
struct GazetteMasthead: View {
    let model: UsageMenuCardView.Model
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GazetteFolio(trailing: self.folioNote, trailingColor: self.folioNoteColor)

            HStack(alignment: .center, spacing: 8) {
                Spacer(minLength: 0)
                if let icon = ProviderBrandIcon.image(for: self.model.provider, size: 22) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                }
                Text(self.model.providerName)
                    .font(RunicGazette.nameplate(30))
                    .tracking(-0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            .padding(.top, 6)
            .padding(.bottom, 4)

            if !self.deckItems.isEmpty {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    ForEach(Array(self.deckItems.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            GazetteLabel(text: "\u{00B7}", color: self.runicTheme.secondaryText)
                        }
                        GazetteLabel(
                            text: item,
                            color: index == 0 ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 4)
            }

            if !self.model.email.isEmpty {
                Text(self.model.email)
                    .font(RunicGazette.copy(9.5))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)
            }

            if let topModelLine = self.model.topModelLine {
                Text(topModelLine)
                    .font(RunicGazette.copy(10))
                    .foregroundStyle(RunicGazette.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }

            if self.model.subtitleStyle == .error, !self.model.subtitleText.isEmpty {
                Text(self.model.subtitleText)
                    .font(RunicGazette.copy())
                    .foregroundStyle(self.runicTheme.warm)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                    .overlay { ClickToCopyOverlay(copyText: self.model.subtitleText) }
            }

            if self.isAuthError || self.model.isServedByCLIFallback {
                HStack {
                    Spacer(minLength: 0)
                    if self.model.provider == .claude {
                        GazetteButton(title: "Reconnect Claude\u{2026}", filled: true) {
                            NotificationCenter.default.post(
                                name: .runicReloadProvider,
                                object: nil,
                                userInfo: ["provider": UsageProvider.claude.rawValue])
                        }
                        .help(self.model.isServedByCLIFallback
                            ? "Runic's copy of the Claude login has expired, so usage is read through the Claude CLI "
                            + "(no cost or reset credits). Reconnect re-reads the login from Keychain; "
                            + "macOS may ask once."
                            : "Re-reads the Claude CLI's login from Keychain. macOS may ask once.")
                        .accessibilityLabel("Reconnect Claude from the CLI's Keychain login")
                    } else {
                        GazetteButton(title: "Add account\u{2026}", filled: true) {
                            SettingsWindowBridge.open(tab: .providers, selection: nil)
                        }
                        .accessibilityLabel("Add account in provider settings")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
            }

            GazetteRule(weight: .double)
                .padding(.top, 8)
        }
    }

    /// The folio's right-hand note: how fresh the numbers are.
    private var folioNote: String? {
        switch self.model.subtitleStyle {
        case .error:
            return "Error"
        case .loading, .info:
            let text = self.model.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            if text.lowercased().hasPrefix("updated ") {
                return String(text.dropFirst("updated ".count))
            }
            return text.count <= 18 ? text : nil
        }
    }

    private var folioNoteColor: Color? {
        self.model.subtitleStyle == .error ? self.runicTheme.warm : self.runicTheme.secondaryText
    }

    /// "62% session · 20% weekly · Pro" — the numbers worth a glance before
    /// the stories.
    private var deckItems: [String] {
        var items: [String] = []
        for metric in self.model.metrics {
            guard let percent = metric.percent else { continue }
            items.append("\(Int(percent.rounded()))% \(metric.title)")
        }
        if let plan = self.model.planText, !plan.isEmpty { items.append(plan) }
        if let badge = self.model.headerBadge { items.append(badge.text) }
        return items
    }

    private var isAuthError: Bool {
        self.model.subtitleStyle == .error && MenuCardErrorClassifier.isAuthLike(self.model.subtitleText)
    }
}

// MARK: - Page

/// The provider card as a page: masthead, the primary window as the lead
/// story, the remaining windows and the balance as two-column briefs with
/// a hairline between them, the cost ledger, and the insights as an
/// In-brief column with a pull quote. Rules divide every section; nothing
/// is boxed. Gazette only — `UsageMenuCardView` switches to this body.
struct GazetteUsageCard: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private enum Column {
        case story(UsageMenuCardView.Model.Metric, Int)
        case money
        case cost(UsageMenuCardView.Model.ProviderCostSection)
    }

    private enum Section {
        case empty(String)
        case lead(UsageMenuCardView.Model.Metric)
        case row([Column])
        case ledger(UsageMenuCardView.Model.TokenUsageSection)
        case briefs(UsageMenuCardView.Model.InsightsSection)
    }

    var body: some View {
        let sections = self.sections
        VStack(alignment: .leading, spacing: 0) {
            GazetteMasthead(model: self.model)
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                if index > 0 {
                    GazetteRule()
                }
                self.view(for: section)
                    .padding(.vertical, 10)
            }
        }
        .gazetteFace()
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
        .frame(width: self.width, alignment: .leading)
    }

    private var sections: [Section] {
        var sections: [Section] = []
        if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
            sections.append(.empty(placeholder))
        }
        if let lead = self.model.metrics.first {
            sections.append(.lead(lead))
        }
        var columns: [Column] = []
        for (index, metric) in self.model.metrics.dropFirst().enumerated() {
            columns.append(.story(metric, index + 1))
        }
        if self.model.creditsText != nil { columns.append(.money) }
        if let cost = self.model.providerCost { columns.append(.cost(cost)) }
        var start = 0
        while start < columns.count {
            let end = min(start + 2, columns.count)
            sections.append(.row(Array(columns[start..<end])))
            start = end
        }
        if self.model.menuMode != .glance, let tokenUsage = self.model.tokenUsage {
            sections.append(.ledger(tokenUsage))
        }
        if self.model.menuMode == .operator, let insights = self.model.insights {
            sections.append(.briefs(insights))
        }
        return sections
    }

    @ViewBuilder
    private func view(for section: Section) -> some View {
        switch section {
        case let .empty(placeholder):
            MenuEmptyStateView(
                providerName: self.model.providerName,
                placeholder: placeholder,
                needsCredentials: self.model.needsCredentials,
                isHighlighted: self.isHighlighted)
        case let .lead(metric):
            GazetteStory(
                metric: metric,
                index: 0,
                tint: self.model.progressColor,
                displayMode: self.model.usageMetricDisplayMode,
                isLead: true)
        case let .row(columns):
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                    if index > 0 {
                        GazetteColumnRule()
                    }
                    self.view(for: column)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case let .ledger(section):
            GazetteLedger(section: section)
        case let .briefs(section):
            GazetteBriefs(section: section)
        }
    }

    @ViewBuilder
    private func view(for column: Column) -> some View {
        switch column {
        case let .story(metric, index):
            GazetteStory(
                metric: metric,
                index: index,
                tint: self.model.progressColor,
                displayMode: self.model.usageMetricDisplayMode)
        case .money:
            GazetteMoney(
                creditsText: self.model.creditsText ?? "",
                hintText: self.model.creditsHintText,
                hintCopyText: self.model.creditsHintCopyText)
        case let .cost(section):
            GazetteCostColumn(section: section, tint: self.model.progressColor)
        }
    }
}

// MARK: - Stories

/// One quota window as a story: category tag and reset byline, the
/// percentage as the headline numeral, a flat gauge, the pace as the deck.
struct GazetteStory: View {
    let metric: UsageMenuCardView.Model.Metric
    let index: Int
    let tint: Color
    let displayMode: UsageMetricDisplayMode
    var isLead = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: self.isLead ? 6 : 4) {
            // The lead runs its byline beside the tag; a column is too narrow
            // for that, so the byline drops under the tag.
            if self.isLead {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    self.tag
                    self.byline
                }
            } else {
                self.tag
                self.byline
            }

            if let percent = self.metric.percent, self.displayMode.showsPercent {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(percent.rounded()))%")
                        .font(RunicGazette.numeral(self.isLead ? 30 : 20))
                        .tracking(self.isLead ? -0.8 : -0.3)
                        .foregroundStyle(self.isExhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                    GazetteLabel(
                        text: self.metric.percentStyle.labelSuffix,
                        size: self.isLead ? 9.5 : 9,
                        color: self.runicTheme.secondaryText)
                }
            }

            if let percent = self.metric.percent, self.displayMode.showsBars {
                GazetteBar(
                    percent: percent,
                    tint: self.isExhausted ? self.runicTheme.warm : self.tint,
                    accessibilityLabel: self.metric.percentStyle.accessibilityLabel,
                    height: self.isLead ? 6 : 5)
            }

            if let detail = self.metric.detailText, !detail.isEmpty {
                Text(detail)
                    .font(self.isLead ? RunicGazette.body() : RunicGazette.copy())
                    .foregroundStyle(RunicGazette.inkSoft)
                    .lineSpacing(self.isLead ? 3 : 1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var tag: some View {
        GazettePill(text: self.metric.title, color: RunicGazette.sectionColor(self.index, theme: self.runicTheme))
    }

    @ViewBuilder
    private var byline: some View {
        if let reset = self.metric.resetText {
            GazetteLabel(text: reset, color: self.runicTheme.secondaryText)
                .minimumScaleFactor(0.75)
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

/// The balance as the Money column: a dotted leader from the label to the
/// amount, the note beneath.
struct GazetteMoney: View {
    let creditsText: String
    let hintText: String?
    let hintCopyText: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GazettePill(text: "Money", color: RunicGazette.green)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Balance")
                    .font(RunicGazette.headline(14))
                    .lineLimit(1)
                    .layoutPriority(1)
                GazetteLeader()
                Text(self.creditsText)
                    .font(RunicGazette.numeral(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
            }
            if let hint = self.hintText, !hint.isEmpty {
                Text(hint)
                    .font(RunicGazette.copy())
                    .foregroundStyle(RunicGazette.inkSoft)
                    .lineSpacing(1.5)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay { ClickToCopyOverlay(copyText: self.hintCopyText ?? hint) }
            }
        }
    }
}

/// Extra-usage spend as a column: tag, the spend line as a headline, a
/// gauge against the limit when there is one.
struct GazetteCostColumn: View {
    let section: UsageMenuCardView.Model.ProviderCostSection
    let tint: Color
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GazettePill(text: self.section.title, color: RunicGazette.amber)
            Text(self.section.spendLine)
                .font(RunicGazette.headline(13))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
            if let percentUsed = self.section.percentUsed {
                GazetteBar(percent: percentUsed, tint: self.tint, accessibilityLabel: "Extra usage spent", height: 5)
                GazetteLabel(
                    text: String(format: "%.0f%% used", min(100, max(0, percentUsed))),
                    color: self.runicTheme.secondaryText)
            }
        }
    }
}

/// The token-cost section as a ledger: session and month lines in the
/// headline face, their details beneath, the timestamp as a byline.
struct GazetteLedger: View {
    let section: UsageMenuCardView.Model.TokenUsageSection
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GazettePill(text: "Ledger", color: self.runicTheme.primaryText)
            self.entry(self.section.sessionLine, detail: self.section.sessionDetailLine)
            self.entry(self.section.monthLine, detail: self.section.monthDetailLine)
            GazetteLabel(text: self.section.updatedLine, color: self.runicTheme.secondaryText, tracking: 1)
                .padding(.top, 2)
            if let hint = self.section.hintLine, !hint.isEmpty {
                Text(hint)
                    .font(RunicGazette.copy())
                    .foregroundStyle(RunicGazette.inkSoft)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = self.section.errorLine, !error.isEmpty {
                Text(error)
                    .font(RunicGazette.copy())
                    .foregroundStyle(self.runicTheme.warm)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay { ClickToCopyOverlay(copyText: self.section.errorCopyText ?? error) }
            }
        }
    }

    @ViewBuilder
    private func entry(_ line: String, detail: String?) -> some View {
        Text(line)
            .font(RunicGazette.headline(12.5))
            .fixedSize(horizontal: false, vertical: true)
        if let detail, !detail.isEmpty {
            Text(detail)
                .font(RunicGazette.copy())
                .foregroundStyle(self.runicTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Insights as the In-brief column: coloured bullets with a bold lead, and
/// the forecast pulled out as a quote beside them.
struct GazetteBriefs: View {
    let section: UsageMenuCardView.Model.InsightsSection
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let lines = self.lines
        let quote = self.quote
        VStack(alignment: .leading, spacing: 6) {
            GazettePill(text: "In brief", color: self.runicTheme.primaryText)
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        let parts = RunicGazette.briefParts(line.text)
                        GazetteBullet(
                            color: RunicGazette.bulletColor(index, theme: self.runicTheme),
                            lead: parts.lead,
                            text: parts.rest,
                            detail: line.detail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let quote {
                    GazetteQuote(text: quote.text, attribution: quote.attribution)
                        .frame(width: 120)
                }
            }
            if let updated = self.section.updatedLine, !updated.isEmpty {
                GazetteLabel(text: updated, size: 8.5, color: self.runicTheme.secondaryText, tracking: 1)
                    .padding(.top, 2)
            }
            if let error = self.section.errorLine, !error.isEmpty {
                Text(error)
                    .font(RunicGazette.copy())
                    .foregroundStyle(self.runicTheme.warm)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var lines: [(text: String, detail: String?)] {
        let pairs: [(String?, String?)] = [
            (self.section.connectionLine, self.section.connectionDetail),
            (self.section.contextLine, self.section.contextDetail),
            (self.section.compactionLine, self.section.compactionDetail),
            (self.section.todayLine, self.section.todayDetail),
            (self.section.blockLine, self.section.blockDetail),
            (self.section.modelLine, nil),
            (self.section.projectLine, self.section.projectDetail),
            (self.section.reliabilityLine, self.section.reliabilityDetail),
            (self.section.routingLine, self.section.routingDetail),
        ]
        return pairs.compactMap { line, detail in
            guard let line, !line.isEmpty else { return nil }
            return (line, detail)
        }
    }

    /// The forecast (or an anomaly) is the line worth pulling out. Kept to
    /// a quote's length so the column stays a column.
    private var quote: (text: String, attribution: String)? {
        if let forecast = self.section.forecastLine, !forecast.isEmpty, forecast.count <= 120 {
            return (forecast, "Forecast")
        }
        if let anomaly = self.section.anomalyLine, !anomaly.isEmpty, anomaly.count <= 120 {
            return (anomaly, self.section.anomalyDetail ?? "Anomaly")
        }
        return nil
    }
}
