import AppKit
import RunicCore
import SwiftUI

// MARK: - Masthead

/// The provider header set as a newspaper masthead: folio dateline, brand mark +
/// Baskerville nameplate, condensed uppercase summary deck, Georgia Italic
/// account line, advisory/recovery banner when needed, and a classic heavy-over-
/// hairline double rule closing the masthead.
struct GazetteMasthead: View {
    let model: UsageMenuCardView.Model
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        VStack(alignment: .leading, spacing: 0) {
            GazetteFolio(trailing: self.folioNote, trailingColor: self.folioNoteColor)

            HStack(alignment: .center, spacing: 8) {
                Spacer(minLength: 0)
                if let icon = ProviderBrandIcon.image(for: self.model.provider, size: 22, prefersDark: dark) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                }
                Text(self.model.providerName)
                    .font(RunicGazette.nameplate(28))
                    .tracking(-0.4)
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            .padding(.top, 7)
            .padding(.bottom, 3)

            if !self.deckItems.isEmpty {
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    ForEach(Array(self.deckItems.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            GazetteLabel(text: "\u{00B7}", size: 9, color: self.runicTheme.secondaryText)
                        }
                        GazetteLabel(
                            text: item,
                            size: 9.5,
                            color: index == 0 ? self.runicTheme.primaryText : self.runicTheme.secondaryText,
                            tracking: 0.7)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 3)
            }

            if !self.model.email.isEmpty {
                Text(self.model.email)
                    .font(RunicGazette.deckItalic(11))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)
            }

            if let topModelLine = self.model.topModelLine, !topModelLine.isEmpty {
                Text(topModelLine)
                    .font(RunicGazette.copy(9.5))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }

            if self.model.menuMode != .glance, let peak = self.model.peakHoursText {
                Text("Peak hours: \(peak)")
                    .font(RunicGazette.copy(9.5))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 1)
            }

            if self.model.subtitleStyle == .error, !self.model.subtitleText.isEmpty {
                Text(self.model.subtitleText)
                    .font(RunicGazette.body(11))
                    .foregroundStyle(self.runicTheme.warm)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                    .overlay { ClickToCopyOverlay(copyText: self.model.subtitleText) }
            } else if self.model.isServedByCLIFallback {
                Text("Reading through Claude CLI fallback — cost and reset credits unavailable until reconnected.")
                    .font(RunicGazette.copy(9.5))
                    .foregroundStyle(self.runicTheme.highlight)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
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

/// Broadsheet provider page: masthead, primary lead story with upright bold
/// numeral + italic status word + 2-column stat band, full-width secondary
/// quota stories, Money / Cost columns, Token Ledger, and In-brief digest with
/// pull quote. Mounted by `GazetteSkin`.
struct GazetteUsageCard: View {
    let model: UsageMenuCardView.Model
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private enum Section {
        case empty(String)
        case lead(UsageMenuCardView.Model.Metric)
        case story(UsageMenuCardView.Model.Metric)
        case finance(hasMoney: Bool, cost: UsageMenuCardView.Model.ProviderCostSection?)
        case ledger(UsageMenuCardView.Model.TokenUsageSection)
        case briefs(UsageMenuCardView.Model.InsightsSection)
    }

    var body: some View {
        let sections = self.sections
        VStack(alignment: .leading, spacing: 0) {
            GazetteMasthead(model: self.model)
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                if index > 0 {
                    GazetteRule(weight: .hair)
                }
                self.view(for: section)
                    .padding(.vertical, 9)
            }
        }
        .gazetteFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(.horizontal, RunicGazette.pageHorizontalInset)
        .padding(.bottom, 2)
        .frame(width: self.width, alignment: .leading)
    }

    private var sections: [Section] {
        var list: [Section] = []
        if self.model.metrics.isEmpty, let placeholder = self.model.placeholder {
            list.append(.empty(placeholder))
        }
        if let lead = self.model.metrics.first {
            list.append(.lead(lead))
        }
        for metric in self.model.metrics.dropFirst() {
            list.append(.story(metric))
        }
        let hasMoney = self.model.creditsText != nil
        let cost = self.model.providerCost
        if hasMoney || cost != nil {
            list.append(.finance(hasMoney: hasMoney, cost: cost))
        }
        if self.model.menuMode != .glance, let tokenUsage = self.model.tokenUsage {
            list.append(.ledger(tokenUsage))
        }
        if self.model.menuMode == .operator, let insights = self.model.insights {
            list.append(.briefs(insights))
        }
        return list
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
            GazetteLeadStory(
                metric: metric,
                displayMode: self.model.usageMetricDisplayMode,
                bankedResetsText: self.model.bankedResetsText)
        case let .story(metric):
            GazetteSecondaryStory(
                metric: metric,
                displayMode: self.model.usageMetricDisplayMode)
        case let .finance(hasMoney, cost):
            if hasMoney, let cost {
                HStack(alignment: .top, spacing: 12) {
                    GazetteMoney(
                        creditsText: self.model.creditsText ?? "",
                        hintText: self.model.creditsHintText,
                        hintCopyText: self.model.creditsHintCopyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    GazetteColumnRule()
                    GazetteCostColumn(section: cost)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if hasMoney {
                GazetteMoney(
                    creditsText: self.model.creditsText ?? "",
                    hintText: self.model.creditsHintText,
                    hintCopyText: self.model.creditsHintCopyText)
            } else if let cost {
                GazetteCostColumn(section: cost)
            }
        case let .ledger(section):
            GazetteLedger(section: section)
        case let .briefs(section):
            GazetteBriefs(section: section)
        }
    }
}

// MARK: - Lead & Secondary Quota Stories

/// Primary quota window as the lead newspaper story: kicker, hero upright bold
/// numeral paired with italic status word, flat broadsheet rule bar, and 2-column
/// metadata strip (`NEXT RESET` | `BANKED` or `PACE`).
struct GazetteLeadStory: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    let bankedResetsText: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let exhausted = RunicGazette.isExhausted(self.metric)
        let used = RunicGazette.usedShare(self.metric)
        let tint = RunicGazette.gaugeTint(used: used, exhausted: exhausted, theme: self.runicTheme)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                GazetteKicker(text: self.metric.title)
                Spacer(minLength: 8)
                if exhausted {
                    GazetteKicker(
                        text: "Exhausted",
                        size: 9.5,
                        color: self.runicTheme.warm,
                        tracking: 0.8)
                } else if self.metric.percent != nil, let reset = self.metric.resetText, !reset.isEmpty {
                    GazetteLabel(
                        text: reset,
                        size: 8.5,
                        color: self.runicTheme.secondaryText,
                        tracking: 0.7)
                        .minimumScaleFactor(0.8)
                }
            }

            if let percent = self.metric.percent, self.displayMode.showsPercent {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(percent.rounded()))%")
                        .font(RunicGazette.numeral(30))
                        .monospacedDigit()
                        .tracking(-0.6)
                        .foregroundStyle(self.runicTheme.primaryText)
                    Text(exhausted ? "exhausted" : self.metric.percentStyle.labelSuffix)
                        .font(RunicGazette.statusItalic(22))
                        .foregroundStyle(exhausted ? self.runicTheme.warm : self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            } else if self.metric.percent == nil, let reset = self.metric.resetText, !reset.isEmpty {
                Text(reset)
                    .font(RunicGazette.headline(20))
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
            }

            if let percent = self.metric.percent, self.displayMode.showsBars {
                GazetteBar(
                    percent: percent,
                    tint: tint,
                    accessibilityLabel: "\(self.metric.title), \(self.metric.percentStyle.accessibilityLabel)",
                    marker: RunicGazette.paceMarker(for: self.metric),
                    height: 4.5)
            }

            if self.metric.percent != nil {
                let cells = self.statCells
                if !cells.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                            if index > 0 {
                                GazetteColumnRule()
                                    .padding(.vertical, 1)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                GazetteLabel(
                                    text: cell.label,
                                    size: 8.5,
                                    color: self.runicTheme.primaryText,
                                    tracking: 0.7)
                                Text(cell.value)
                                    .font(RunicGazette.copy(10.5))
                                    .foregroundStyle(cell.accent ?? self.runicTheme.secondaryText)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, index == 0 ? 0 : 10)
                            .padding(.trailing, index == cells.count - 1 ? 0 : 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 2)
                }
            } else if let detail = self.metric.detailText, !detail.isEmpty {
                Text(detail)
                    .font(RunicGazette.copy(10.5))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statCells: [(label: String, value: String, accent: Color?)] {
        var list: [(String, String, Color?)] = []
        if let reset = self.metric.resetText, !reset.isEmpty {
            let trimmed = reset
                .replacingOccurrences(of: "Resets in ", with: "")
                .replacingOccurrences(of: "Resets ", with: "")
            list.append(("Next reset", trimmed, nil))
        }
        let hasBanked = !(self.bankedResetsText?.isEmpty ?? true)
        if let detail = self.metric.detailText, !detail.isEmpty {
            let duplicatesBanked = hasBanked && (
                detail == self.bankedResetsText
                    || detail.localizedCaseInsensitiveContains("banked reset"))
            if !duplicatesBanked {
                if detail.hasPrefix("Pace: ") {
                    list.append(("Pace", String(detail.dropFirst("Pace: ".count)), nil))
                } else {
                    list.append(("Detail", detail, nil))
                }
            }
        }
        if let banked = self.bankedResetsText, !banked.isEmpty {
            let compact = banked.replacingOccurrences(of: "usable until ", with: "until ")
            list.append(("Banked", compact, self.runicTheme.tertiary))
        }
        return list
    }
}

/// Secondary quota window set full-width beneath a hairline rule: flush-left
/// kicker, right-aligned reset schedule, upright numeral + italic suffix,
/// flat rule bar with pace marker, and pace / detail line.
struct GazetteSecondaryStory: View {
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let exhausted = RunicGazette.isExhausted(self.metric)
        let used = RunicGazette.usedShare(self.metric)
        let tint = RunicGazette.gaugeTint(used: used, exhausted: exhausted, theme: self.runicTheme)

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                GazetteKicker(text: self.metric.title)
                Spacer(minLength: 8)
                if self.metric.percent != nil, let reset = self.metric.resetText, !reset.isEmpty {
                    GazetteLabel(
                        text: reset,
                        size: 8.5,
                        color: self.runicTheme.secondaryText,
                        tracking: 0.7)
                        .minimumScaleFactor(0.8)
                }
            }

            if let percent = self.metric.percent, self.displayMode.showsPercent {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(percent.rounded()))%")
                        .font(RunicGazette.numeral(21))
                        .monospacedDigit()
                        .tracking(-0.3)
                        .foregroundStyle(self.runicTheme.primaryText)
                    Text(exhausted ? "exhausted" : self.metric.percentStyle.labelSuffix)
                        .font(RunicGazette.statusItalic(16))
                        .foregroundStyle(exhausted ? self.runicTheme.warm : self.runicTheme.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if exhausted {
                        GazetteKicker(
                            text: "Exhausted",
                            size: 8.5,
                            color: self.runicTheme.warm,
                            tracking: 0.7)
                    }
                }
                .accessibilityElement(children: .combine)
            } else if self.metric.percent == nil, let reset = self.metric.resetText, !reset.isEmpty {
                Text(reset)
                    .font(RunicGazette.headline(16))
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
            }

            if let percent = self.metric.percent, self.displayMode.showsBars {
                GazetteBar(
                    percent: percent,
                    tint: tint,
                    accessibilityLabel: "\(self.metric.title), \(self.metric.percentStyle.accessibilityLabel)",
                    marker: RunicGazette.paceMarker(for: self.metric),
                    height: 4)
            }

            if let detail = self.metric.detailText, !detail.isEmpty {
                Text(detail)
                    .font(RunicGazette.copy(10))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineSpacing(1.5)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Finance, Ledger & Briefs

/// Balance / Credits block: flush-left kicker, dotted leader to numeral.
struct GazetteMoney: View {
    let creditsText: String
    let hintText: String?
    let hintCopyText: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GazetteKicker(text: "Credits", color: self.runicTheme.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Balance")
                    .font(RunicGazette.headline(13.5))
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .layoutPriority(1)
                GazetteLeader()
                Text(self.creditsText)
                    .font(RunicGazette.numeral(13.5))
                    .monospacedDigit()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
            }
            if let hint = self.hintText, !hint.isEmpty {
                Text(hint)
                    .font(RunicGazette.copy(9.5))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineSpacing(1.5)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay { ClickToCopyOverlay(copyText: self.hintCopyText ?? hint) }
            }
        }
    }
}

/// Extra-usage spend block: kicker, spend headline, gauge against limit.
struct GazetteCostColumn: View {
    let section: UsageMenuCardView.Model.ProviderCostSection
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let percent = self.section.percentUsed
        let exhausted = (percent ?? 0) >= 99.5
        let tint = RunicGazette.gaugeTint(used: percent, exhausted: exhausted, theme: self.runicTheme)

        VStack(alignment: .leading, spacing: 5) {
            GazetteKicker(text: self.section.title, color: self.runicTheme.highlight)
            Text(self.section.primarySpendLine ?? self.section.spendLine)
                .font(RunicGazette.headline(13))
                .foregroundStyle(self.runicTheme.primaryText)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
            if let apiCredits = self.section.apiCreditsLine, !apiCredits.isEmpty, self.section.primarySpendLine != nil {
                Text(apiCredits)
                    .font(RunicGazette.copy(9.5))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
            }
            if let percentUsed = percent {
                GazetteBar(
                    percent: percentUsed,
                    tint: tint,
                    accessibilityLabel: "Extra usage spent",
                    height: 4)
                GazetteLabel(
                    text: String(format: "%.0f%% used", min(100, max(0, percentUsed))),
                    size: 8.5,
                    color: self.runicTheme.secondaryText)
            }
        }
    }
}

/// Local token ledger section.
struct GazetteLedger: View {
    let section: UsageMenuCardView.Model.TokenUsageSection
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                GazetteKicker(text: "Local ledger")
                Spacer(minLength: 6)
                GazetteLabel(
                    text: self.section.updatedLine,
                    size: 8.5,
                    color: self.runicTheme.secondaryText,
                    tracking: 0.7)
            }
            self.entry(self.section.sessionLine, detail: self.section.sessionDetailLine)
            self.entry(self.section.monthLine, detail: self.section.monthDetailLine)
            if let hint = self.section.hintLine, !hint.isEmpty {
                Text(hint)
                    .font(RunicGazette.copy(9.5))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = self.section.errorLine, !error.isEmpty {
                Text(error)
                    .font(RunicGazette.copy(9.5))
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
            .font(RunicGazette.headline(12))
            .foregroundStyle(self.runicTheme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
        if let detail, !detail.isEmpty {
            Text(detail)
                .font(RunicGazette.copy(9.5))
                .foregroundStyle(self.runicTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Operator insights digest with pull quote.
struct GazetteBriefs: View {
    let section: UsageMenuCardView.Model.InsightsSection
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let lines = self.lines
        let quote = self.quote
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                GazetteKicker(text: self.section.title)
                Spacer(minLength: 6)
                if let updated = self.section.updatedLine, !updated.isEmpty {
                    GazetteLabel(
                        text: updated,
                        size: 8.5,
                        color: self.runicTheme.secondaryText,
                        tracking: 0.7)
                }
            }
            HStack(alignment: .top, spacing: 12) {
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
                        .frame(width: 122)
                }
            }
            if let error = self.section.errorLine, !error.isEmpty {
                Text(error)
                    .font(RunicGazette.copy(9.5))
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
