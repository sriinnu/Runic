import AppKit
import Charts
import RunicCore
import SwiftUI

/// Overview dashboard showing all enabled providers at a glance.
/// Inspired by Apple Activity app rings, Awwwards dashboard layouts, and Tokex stat cards.
@MainActor
struct OverviewMenuView: View {
    @Environment(\.runicFonts) private var fonts
    struct ProviderSummary: Identifiable {
        let id: String
        let provider: UsageProvider
        let name: String
        let icon: NSImage?
        /// Percent to display, already resolved against the used/left toggle.
        let usedPercent: Double
        let todayTokens: Int
        let brandColor: Color
        let resetDescription: String?
        let windowLabel: String? // e.g. "5h" or "Weekly"
        let topModelContext: String? // e.g. "200K ctx"
        /// Whether the provider's primary window tracks a real, measured
        /// quota. Providers without one (balance/counter stubs) show "—" and
        /// are excluded from the cross-provider average.
        var hasQuota: Bool = true
        /// "2 resets" when the provider banks manual limit resets.
        var bankedResetsText: String?
        /// Compact subscription tier badge ("Ultra", "Max", "Pro", ...).
        var planBadge: String?

        /// Brand-level provider (the international slot for a two-region
        /// brand, else the provider itself). Rows sharing a root stack
        /// under one brand header.
        var brandRoot: UsageProvider {
            self.provider.brandRoot
        }

        var region: ProviderRegion {
            self.provider.region
        }
    }

    /// One brand in the overview: every visible region row plus, for a
    /// two-region brand with one side unconfigured, the slot to offer.
    struct BrandGroup: Identifiable {
        let id: String
        let root: UsageProvider
        let rows: [ProviderSummary]
        let missingSlot: UsageProvider?

        var isStacked: Bool {
            self.rows.count > 1 || self.missingSlot != nil
        }
    }

    /// Group summaries by brand, preserving first-appearance order. A brand
    /// with a China sibling whose other slot isn't visible gets that slot as
    /// `missingSlot` so the row can offer to add it.
    static func brandGroups(_ summaries: [ProviderSummary]) -> [BrandGroup] {
        var order: [UsageProvider] = []
        var rows: [UsageProvider: [ProviderSummary]] = [:]
        for summary in summaries {
            let root = summary.brandRoot
            if rows[root] == nil { order.append(root) }
            rows[root, default: []].append(summary)
        }
        return order.map { root in
            let brandRows = rows[root] ?? []
            var missing: UsageProvider?
            if let china = root.chinaSibling {
                let present = Set(brandRows.map(\.provider))
                if !present.contains(china) {
                    missing = china
                } else if !present.contains(root) {
                    missing = root
                }
            }
            return BrandGroup(id: root.rawValue, root: root, rows: brandRows, missingSlot: missing)
        }
    }

    struct DailyPoint: Identifiable {
        let id: String
        let date: Date
        let tokens: Int
        let provider: String
        let color: Color
    }

    let summaries: [ProviderSummary]
    let chartPoints: [DailyPoint]
    let totalTodayTokens: Int
    let totalProviders: Int
    let width: CGFloat
    /// Mirrors the `usageBarsShowUsed` setting so the overview reads the same
    /// direction (used vs left) as the cards and menubar.
    var showsUsed: Bool = true
    /// Mirrors the number-format preference (abbreviated vs full).
    var numberStyle: UsageFormatter.NumberStyle = .abbreviated
    /// "Add China" / "Add International" for a two-region brand with one
    /// side unconfigured. Nil hides the offer.
    var onAddRegion: ((UsageProvider) -> Void)?
    var onSelectProvider: ((UsageProvider) -> Void)?
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.runicSkin) private var skin

    var body: some View {
        if let page = self.skin.frontPage(self) {
            page
        } else {
            self.standardBody
        }
    }

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            // MARK: - Hero header

            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                // Ring indicator showing overall usage
                ZStack {
                    Circle()
                        .stroke(self.runicTheme.menuTrackColor, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: min(1, (self.averagePercent ?? 0) / 100))
                        .stroke(
                            AngularGradient(
                                colors: [self.runicTheme.highlight, self.runicTheme.accent],
                                center: .center),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 0) {
                    Text(UsageFormatter.tokenCountString(self.totalTodayTokens, style: self.numberStyle))
                        .font(self.fonts.system(size: 22, weight: .bold))
                    Text("\(self.summaries.count) of \(self.totalProviders) active")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("today")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Text(self.averagePercentText)
                        .font(self.fonts.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(self.runicTheme.primaryText)
                }
            }

            Divider().overlay(self.runicTheme.cardStroke.opacity(0.5))

            // MARK: - Provider cards

            if self.summaries.isEmpty {
                Text("No active providers.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, RunicSpacing.md)
            } else {
                VStack(spacing: RunicSpacing.compact) {
                    ForEach(Self.brandGroups(self.summaries)) { group in
                        if group.isStacked {
                            BrandStackView(
                                group: group,
                                showsUsed: self.showsUsed,
                                numberStyle: self.numberStyle,
                                onAddRegion: self.onAddRegion)
                        } else if let summary = group.rows.first {
                            ProviderRow(summary: summary, showsUsed: self.showsUsed, numberStyle: self.numberStyle)
                        }
                    }
                }
            }

            // MARK: - Combined 7-day chart

            if !self.chartPoints.isEmpty {
                Divider().overlay(self.runicTheme.cardStroke.opacity(0.5))

                HStack {
                    Text("7-day activity")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Spacer()
                    // Mini legend dots — same domain/order as the chart scale
                    // so dot colors always match the bars.
                    HStack(spacing: RunicSpacing.xxs) {
                        ForEach(self.chartLegendEntries.prefix(4), id: \.name) { entry in
                            Circle()
                                .fill(entry.color)
                                .frame(width: 5, height: 5)
                        }
                        if self.chartLegendEntries.count > 4 {
                            Text("+\(self.chartLegendEntries.count - 4)")
                                .font(self.fonts.system(size: 8))
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.75))
                        }
                    }
                }

                self.activityChart
            }
        }
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.sm)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    /// The combined 7-day bar chart, shared by the standard and newsprint
    /// layouts.
    var activityChart: some View {
        Chart {
            ForEach(self.chartPoints) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Tokens", point.tokens))
                    .foregroundStyle(by: .value("Provider", point.provider))
                    .cornerRadius(self.runicTheme.shape.cornerRadius(2))
            }
        }
        .chartForegroundStyleScale(
            domain: self.chartLegendEntries.map(\.name),
            range: self.chartLegendEntries.map(\.color))
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3, 3]))
                    .foregroundStyle(self.runicTheme.chartGridColor)
                AxisValueLabel {
                    if let tokens = value.as(Int.self) {
                        Text(UsageFormatter.tokenCountString(tokens))
                            .font(self.fonts.system(size: 8))
                            .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
                    .font(self.fonts.system(size: 8, weight: .medium))
                    .foregroundStyle(self.runicTheme.chartAxisLabelColor)
            }
        }
        .frame(height: 80)
    }

    private var averagePercent: Double? {
        Self.averagePercent(self.summaries)
    }

    /// Header text for the average; "—" when no provider has a measurable
    /// quota so it never reads as everything-depleted.
    var averagePercentText: String {
        guard let averagePercent = self.averagePercent else { return "—" }
        return "\(Int(averagePercent))% \(self.showsUsed ? "used" : "left") avg"
    }

    /// Average of the display percents across providers with a real quota
    /// window. Stub providers (permanent 0% placeholders without a limit) are
    /// excluded so the average only mixes comparable percentages; when no
    /// provider is comparable there is no average at all (`nil`), not 0.
    static func averagePercent(_ summaries: [ProviderSummary]) -> Double? {
        let comparable = summaries.filter(\.hasQuota)
        guard !comparable.isEmpty else { return nil }
        return comparable.reduce(0) { $0 + $1.usedPercent } / Double(comparable.count)
    }

    /// Display percent for a primary window, resolved against the used/left
    /// toggle the cards and menubar honor.
    static func displayPercent(for window: RateWindow?, showsUsed: Bool) -> Double {
        guard let window else { return 0 }
        guard Self.windowHasQuota(window) else { return 0 }
        return min(100, max(0, showsUsed ? window.usedPercent : window.remainingPercent))
    }

    /// Whether a primary window represents a real, measured quota that can be
    /// shown as (and averaged with) a percentage. `hasRealQuota` already
    /// treats `hasKnownLimit` as the primary signal, so this is a straight
    /// delegation.
    static func windowHasQuota(_ window: RateWindow?) -> Bool {
        guard let window else { return false }
        return SessionQuotaNotificationLogic.hasRealQuota(window)
    }

    /// Pill text for the overview row: a live countdown when the window
    /// knows its reset moment, otherwise the provider's own phrase.
    /// Pill text for banked resets: "2 resets" / "1 reset".
    static func bankedResetsPill(for credits: UsageResetCredits?, now: Date = .init()) -> String? {
        guard let credits else { return nil }
        let count = credits.effectiveAvailableCount(now: now)
        guard count > 0 else { return nil }
        return count == 1 ? "1 reset" : "\(count) resets"
    }

    static func resetPill(for window: RateWindow?, now: Date = .init()) -> String? {
        guard let window else { return nil }
        if let date = window.resetsAt ?? UsageResetParsing.date(fromRelative: window.resetDescription, now: now) {
            return "↻ \(UsageFormatter.resetCountdownDescription(from: date, now: now))"
        }
        return window.resetDescription
    }

    /// One entry per provider present in the chart data, in first-appearance
    /// order, colored by the provider's brand color so bars, legend dots, and
    /// the provider rows all agree on identity.
    var chartLegendEntries: [(name: String, color: Color)] {
        var seen: Set<String> = []
        var entries: [(name: String, color: Color)] = []
        for point in self.chartPoints where !seen.contains(point.provider) {
            seen.insert(point.provider)
            entries.append((name: point.provider, color: point.color))
        }
        return entries
    }
}

// MARK: - Brand stack (two-region brands)

/// A brand with International and China slots as one block: the brand mark
/// and name once, then a row per region tagged INTL / CN, and an "Add …"
/// offer when one side has no account yet.
private struct BrandStackView: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let group: OverviewMenuView.BrandGroup
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    let onAddRegion: ((UsageProvider) -> Void)?

    var body: some View {
        let radius = self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm)
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            HStack(spacing: RunicSpacing.xs) {
                if let icon = self.group.rows.first?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
                Text(self.brandName)
                    .font(self.fonts.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(self.group.rows.count == 2 ? "2 regions" : "1 of 2 regions")
                    .font(self.fonts.system(size: 8, weight: .medium))
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
            }
            ForEach(self.group.rows) { summary in
                ProviderRow(
                    summary: summary,
                    showsUsed: self.showsUsed,
                    numberStyle: self.numberStyle,
                    regionTag: summary.region == .china ? "CN" : "INTL")
            }
            if let missing = self.group.missingSlot, let onAddRegion = self.onAddRegion {
                Button {
                    onAddRegion(missing)
                } label: {
                    HStack(spacing: RunicSpacing.xxs) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 9, weight: .semibold))
                        Text(OverviewMenuView.addRegionLabel(for: missing))
                            .font(self.fonts.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(self.runicTheme.iconColor(for: .navigation, hovered: true))
                    .padding(.leading, 14 + RunicSpacing.xs)
                    .padding(.vertical, 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(OverviewMenuView.addRegionLabel(for: missing))
            }
        }
        .padding(RunicSpacing.compact)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(self.runicTheme.menuSubtleFill.opacity(0.6)))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(self.runicTheme.cardStroke.opacity(0.35), lineWidth: 0.7))
    }

    private var brandName: String {
        let name = self.group.rows.first(where: { $0.region == .international })?.name
            ?? self.group.rows.first?.name ?? ""
        return name.hasSuffix(" CN") ? String(name.dropLast(3)) : name
    }
}

// MARK: - Provider row

private struct ProviderRow: View {
    @Environment(\.runicFonts) private var fonts
    let summary: OverviewMenuView.ProviderSummary
    var showsUsed: Bool = true
    var numberStyle: UsageFormatter.NumberStyle = .abbreviated
    /// Inside a brand stack the name column becomes a region tag.
    var regionTag: String?
    @Environment(\.runicTheme) private var runicTheme

    /// Emphasize rows needing attention: heavy usage in "used" mode, low
    /// headroom in "left" mode.
    private var emphasizesPercent: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent > 80 : self.summary.usedPercent < 20
    }

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
            if let tag = self.regionTag {
                // Region tag stands in for icon + name inside a brand stack.
                Text(tag)
                    .font(self.fonts.system(size: 8, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(width: 14 + 84 + RunicSpacing.xs, alignment: .leading)
                    .padding(.leading, 14 + RunicSpacing.xs)
            } else {
                // Icon with brand tint
                if let icon = self.summary.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }

                // Name
                Text(self.summary.name)
                    .font(self.fonts.caption)
                    .fontWeight(.medium)
                    .frame(width: 84, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            // Progress bar with gradient fill
            GeometryReader { geo in
                let fillWidth = max(0, geo.size.width * min(1, self.summary.usedPercent / 100))
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(self.runicTheme.menuTrackColor)

                    // Fill with gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    self.summary.brandColor.opacity(0.9),
                                    self.summary.brandColor,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing))
                        .frame(width: fillWidth)

                    // Gloss overlay on fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.2), location: 0),
                                    .init(color: .clear, location: 0.5),
                                ],
                                startPoint: .top,
                                endPoint: .bottom))
                        .frame(width: fillWidth)
                }
            }
            .frame(height: 7)

            // Percentage ("—" for providers without a real quota window)
            Text(self.summary.hasQuota ? "\(Int(self.summary.usedPercent))%" : "—")
                .font(self.fonts.system(size: 9, weight: .semibold))
                .foregroundStyle(self.emphasizesPercent
                    ? self.runicTheme.primaryText
                    : self.runicTheme.secondaryText)
                .frame(width: 28, alignment: .trailing)

            // Today's tokens (if any)
            if self.summary.todayTokens > 0 {
                Text(UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle))
                    .font(self.fonts.system(size: 8))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(width: 32, alignment: .trailing)
            }
        }

        // Second line: plan tier + window + reset + context
        let hasSecondLine = self.summary.planBadge != nil ||
            self.summary.windowLabel != nil ||
            self.summary.resetDescription != nil ||
            self.summary.bankedResetsText != nil ||
            self.summary.topModelContext != nil

        if hasSecondLine {
            HStack(spacing: RunicSpacing.xxs) {
                // Spacer for icon + name width
                Color.clear.frame(width: 14 + 84 + RunicSpacing.xs * 2, height: 0)

                if let plan = self.summary.planBadge {
                    PlanTierPill(text: plan)
                }
                if let window = self.summary.windowLabel {
                    InfoPill(text: window)
                }
                if let reset = self.summary.resetDescription {
                    InfoPill(text: reset)
                }
                if let banked = self.summary.bankedResetsText {
                    InfoPill(text: banked)
                }
                if let ctx = self.summary.topModelContext {
                    InfoPill(text: ctx)
                }
                Spacer()
            }
        }
    }
}

private struct PlanTierPill: View {
    @Environment(\.runicFonts) private var fonts
    let text: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let elevated = OverviewMenuView.isElevatedPlanBadge(self.text)
        Text(self.text.uppercased())
            .font(self.fonts.system(size: 7.5, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(elevated ? self.runicTheme.accent : self.runicTheme.secondaryText)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1)
            .background(
                Capsule(style: .continuous)
                    .fill(elevated ? self.runicTheme.accent.opacity(0.14) : self.runicTheme.menuSubtleFill))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        (elevated ? self.runicTheme.accent : self.runicTheme.cardStroke).opacity(0.45),
                        lineWidth: 0.5))
    }
}

private struct InfoPill: View {
    @Environment(\.runicFonts) private var fonts
    let text: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text)
            .font(self.fonts.system(size: 8, weight: .medium))
            .foregroundStyle(self.runicTheme.secondaryText)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule(style: .continuous)
                    .fill(self.runicTheme.menuSubtleFill))
    }
}

// MARK: - Newsprint Broadsheet

/// The overview as the Gazette's front page: folio dateline, "The Runic Gazette"
/// Baskerville nameplate, centered Georgia Italic editorial deck, classic heavy-
/// over-hairline double rule, Quota Ledger dotted-leader rows with regional
/// brand stacking and click-to-select, and 7-day activity chart. Mounted by `GazetteSkin`.
struct GazetteOverviewBody: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let groups = OverviewMenuView.brandGroups(self.view.summaries)

        VStack(alignment: .leading, spacing: 0) {
            GazetteFolio(trailing: "\(self.view.summaries.count) of \(self.view.totalProviders) active")

            Text("The Runic Gazette")
                .font(RunicGazette.nameplate(29))
                .tracking(-0.4)
                .foregroundStyle(self.runicTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.top, 7)
                .padding(.bottom, 3)
                .accessibilityAddTraits(.isHeader)

            Text(self.editorialDeck)
                .font(RunicGazette.deckItalic(11.5))
                .foregroundStyle(self.runicTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.bottom, 7)

            GazetteRule(weight: .double)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                GazetteKicker(text: "Quota ledger")
                Spacer(minLength: 6)
                Text(self.ledgerRightLabel.uppercased())
                    .font(RunicGazette.sans(9, .medium))
                    .tracking(0.6)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, 7)
            .padding(.bottom, 5)

            GazetteRule(weight: .single)

            if groups.isEmpty {
                Text("No active providers.")
                    .font(RunicGazette.body())
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, RunicSpacing.md)
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        GazetteRule(weight: .hair)
                    }
                    if group.isStacked {
                        GazetteBrandGroupRow(
                            group: group,
                            showsUsed: self.view.showsUsed,
                            numberStyle: self.view.numberStyle,
                            onAddRegion: self.view.onAddRegion,
                            onSelect: self.view.onSelectProvider)
                    } else if let summary = group.rows.first {
                        GazetteOverviewRow(
                            summary: summary,
                            showsUsed: self.view.showsUsed,
                            numberStyle: self.view.numberStyle,
                            onSelect: self.view.onSelectProvider)
                    }
                }
            }

            if !self.view.chartPoints.isEmpty {
                GazetteRule(weight: .heavy)
                    .padding(.top, 2)
                HStack(alignment: .center) {
                    GazetteKicker(text: "7-day activity")
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(self.view.chartLegendEntries.prefix(5), id: \.name) { entry in
                            Rectangle()
                                .fill(entry.color)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .padding(.top, 8)
                .padding(.bottom, 6)
                self.view.activityChart
            }
        }
        .gazetteFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(.horizontal, RunicGazette.pageHorizontalInset)
        .padding(.bottom, 4)
        .frame(width: self.view.width, alignment: .leading)
    }

    private var editorialDeck: String {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        let exhausted = self.view.summaries.count(where: { summary in
            guard summary.hasQuota else { return false }
            return self.view.showsUsed ? summary.usedPercent >= 99.5 : summary.usedPercent <= 0.5
        })
        let banked = self.view.summaries.count(where: { $0.bankedResetsText != nil })
        if let average {
            let count = self.view.summaries.count
            let unit = count == 1 ? "provider" : "providers"
            let direction = self.view.showsUsed ? "used" : "left"
            var sentence = "\(Int(average.rounded()))% average \(direction) across \(count) \(unit)"
            var notes: [String] = []
            if exhausted > 0 { notes.append("\(exhausted) exhausted") }
            if banked > 0 { notes.append("\(banked) banked") }
            if !notes.isEmpty {
                sentence += " \u{2014} " + notes.joined(separator: ", ")
            }
            return sentence
        }
        if self.view.totalTodayTokens > 0 {
            let today = UsageFormatter.tokenCountString(self.view.totalTodayTokens, style: self.view.numberStyle)
            return "\(today) used today across \(self.view.summaries.count) providers"
        }
        return self.view.averagePercentText
    }

    private var ledgerRightLabel: String {
        var parts: [String] = []
        if self.view.totalTodayTokens > 0 {
            let today = UsageFormatter.tokenCountString(self.view.totalTodayTokens, style: self.view.numberStyle)
            parts.append("\(today) today")
        }
        if let average = OverviewMenuView.averagePercent(self.view.summaries) {
            parts.append("SESSION \u{00B7} AVG \(Int(average.rounded()))%")
        } else {
            parts.append(self.view.averagePercentText)
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}

/// Shared helpers for overview provider rows across skins.
extension OverviewMenuView {
    static func addRegionLabel(for slot: UsageProvider) -> String {
        let displayName = ProviderDefaults.metadata[slot]?.displayName ?? slot.rawValue
        return "Add \(displayName)"
    }

    static func planBadge(
        for provider: UsageProvider,
        snapshot: UsageSnapshot?,
        account: AccountInfo,
        metadata: ProviderMetadata) -> String?
    {
        if let plan = snapshot?.loginMethod(for: provider),
           let badge = UsageFormatter.planTierBadge(plan)
        {
            return badge
        }
        if metadata.usesAccountFallback,
           let plan = account.plan,
           let badge = UsageFormatter.planTierBadge(plan)
        {
            return badge
        }
        return nil
    }

    static func isElevatedPlanBadge(_ badge: String) -> Bool {
        let lower = badge.lowercased()
        return lower.contains("ultra")
            || lower.contains("max")
            || lower.contains("pro")
            || lower.contains("plus")
            || lower.contains("enterprise")
            || lower.contains("team")
            || lower.contains("business")
    }
}

private struct GazetteOverviewRow: View {
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    var onSelect: ((UsageProvider) -> Void)?
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        let icon = ProviderBrandIcon.image(for: self.summary.provider, size: 14, prefersDark: dark)
            ?? self.summary.icon

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1.5 }
                        .accessibilityHidden(true)
                }
                Text(self.summary.name)
                    .font(RunicGazette.headline(13.5))
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .layoutPriority(1)
                if let plan = self.summary.planBadge {
                    GazetteHairlineBadge(text: plan, size: 8)
                }
                GazetteLeader()
                if self.summary.todayTokens > 0 {
                    Text(UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle))
                        .font(RunicGazette.copy(9.5))
                        .monospacedDigit()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
                Text(self.summary.hasQuota ? "\(Int(self.summary.usedPercent.rounded()))%" : "\u{2014}")
                    .font(RunicGazette.numeral(13.5))
                    .monospacedDigit()
                    .foregroundStyle(self.percentColor)
                    .layoutPriority(1)
            }

            if self.summary.hasQuota {
                GazetteBar(
                    percent: self.summary.usedPercent,
                    tint: self.barTint,
                    accessibilityLabel: self.showsUsed ? "Usage used" : "Usage remaining",
                    height: 3.5)
            }

            GazetteRowByline(summary: self.summary)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 2)
        .background(self.isHovered ? self.runicTheme.surfaceAlt.opacity(0.65) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            self.onSelect?(self.summary.provider)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(self.onSelect != nil ? .isButton : [])
    }

    private var isExhausted: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent >= 99.5 : self.summary.usedPercent <= 0.5
    }

    private var isElevated: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent > 80 : self.summary.usedPercent < 20
    }

    private var percentColor: Color {
        if self.isExhausted { return self.runicTheme.warm }
        if self.isElevated { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }

    private var barTint: Color {
        if self.isExhausted { return self.runicTheme.warm }
        if self.isElevated { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }
}

private struct GazetteBrandGroupRow: View {
    let group: OverviewMenuView.BrandGroup
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    let onAddRegion: ((UsageProvider) -> Void)?
    var onSelect: ((UsageProvider) -> Void)?
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        let brandName = UsageProvider.compactDisplayName(self.group.rows.first?.name ?? self.group.root.rawValue)
        let icon = self.group.rows.first.flatMap {
            ProviderBrandIcon.image(for: $0.provider, size: 14, prefersDark: dark) ?? $0.icon
        }

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1.5 }
                        .accessibilityHidden(true)
                }
                Text(brandName)
                    .font(RunicGazette.headline(13.5))
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(self.group.rows.count == 2 ? "2 REGIONS" : "1 OF 2 REGIONS")
                    .font(RunicGazette.sans(8.5, .medium))
                    .tracking(0.6)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }

            ForEach(self.group.rows) { summary in
                GazetteRegionSubRow(
                    summary: summary,
                    showsUsed: self.showsUsed,
                    numberStyle: self.numberStyle,
                    onSelect: self.onSelect)
                    .padding(.leading, 18)
            }

            if let missing = self.group.missingSlot, let onAddRegion = self.onAddRegion {
                let label = OverviewMenuView.addRegionLabel(for: missing)
                HStack {
                    GazetteLink(text: "\(label) \u{2192}") {
                        onAddRegion(missing)
                    }
                    .padding(.leading, 18)
                    .accessibilityLabel(label)
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 2)
    }
}

private struct GazetteRegionSubRow: View {
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    var onSelect: ((UsageProvider) -> Void)?
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                GazetteHairlineBadge(text: self.summary.region == .china ? "CN" : "INTL", size: 8)
                if let plan = self.summary.planBadge {
                    GazetteHairlineBadge(text: plan, size: 8)
                }
                GazetteLeader()
                if self.summary.todayTokens > 0 {
                    Text(UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle))
                        .font(RunicGazette.copy(9.5))
                        .monospacedDigit()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
                Text(self.summary.hasQuota ? "\(Int(self.summary.usedPercent.rounded()))%" : "\u{2014}")
                    .font(RunicGazette.numeral(12.5))
                    .monospacedDigit()
                    .foregroundStyle(self.percentColor)
                    .layoutPriority(1)
            }

            if self.summary.hasQuota {
                GazetteBar(
                    percent: self.summary.usedPercent,
                    tint: self.barTint,
                    accessibilityLabel: "\(self.summary.name) usage",
                    height: 3.5)
            }

            GazetteRowByline(summary: self.summary)
        }
        .padding(.vertical, 2)
        .background(self.isHovered ? self.runicTheme.surfaceAlt.opacity(0.65) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            self.onSelect?(self.summary.provider)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(self.onSelect != nil ? .isButton : [])
    }

    private var isExhausted: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent >= 99.5 : self.summary.usedPercent <= 0.5
    }

    private var isElevated: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent > 80 : self.summary.usedPercent < 20
    }

    private var percentColor: Color {
        if self.isExhausted { return self.runicTheme.warm }
        if self.isElevated { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }

    private var barTint: Color {
        if self.isExhausted { return self.runicTheme.warm }
        if self.isElevated { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }
}

private struct GazetteRowByline: View {
    let summary: OverviewMenuView.ProviderSummary
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let leftParts = [
            self.summary.resetDescription,
            self.summary.topModelContext,
        ].compactMap(\.self).filter { !$0.isEmpty }
        let banked = self.summary.bankedResetsText
        if !leftParts.isEmpty || banked != nil {
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                if !leftParts.isEmpty {
                    Text(leftParts.joined(separator: " \u{00B7} ").uppercased())
                        .font(RunicGazette.sans(8.5, .medium))
                        .tracking(0.5)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let banked, !banked.isEmpty {
                    if !leftParts.isEmpty {
                        Text("\u{00B7}")
                            .font(RunicGazette.sans(8.5, .bold))
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }
                    Text(banked.uppercased())
                        .font(RunicGazette.sans(8.5, .bold))
                        .tracking(0.5)
                        .foregroundStyle(self.runicTheme.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}
