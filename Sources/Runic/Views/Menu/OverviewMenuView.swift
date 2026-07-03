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
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
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
                    ForEach(self.summaries) { summary in
                        ProviderRow(summary: summary, showsUsed: self.showsUsed, numberStyle: self.numberStyle)
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
        }
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.sm)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private var averagePercent: Double? {
        Self.averagePercent(self.summaries)
    }

    /// Header text for the average; "—" when no provider has a measurable
    /// quota so it never reads as everything-depleted.
    private var averagePercentText: String {
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

// MARK: - Provider row

private struct ProviderRow: View {
    @Environment(\.runicFonts) private var fonts
    let summary: OverviewMenuView.ProviderSummary
    var showsUsed: Bool = true
    var numberStyle: UsageFormatter.NumberStyle = .abbreviated
    @Environment(\.runicTheme) private var runicTheme

    /// Emphasize rows needing attention: heavy usage in "used" mode, low
    /// headroom in "left" mode.
    private var emphasizesPercent: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent > 80 : self.summary.usedPercent < 20
    }

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
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
                .frame(width: 58, alignment: .leading)
                .lineLimit(1)

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

        // Second line: window + reset + context
        let hasSecondLine = self.summary.windowLabel != nil ||
            self.summary.resetDescription != nil ||
            self.summary.topModelContext != nil

        if hasSecondLine {
            HStack(spacing: RunicSpacing.xxs) {
                // Spacer for icon + name width
                Color.clear.frame(width: 14 + 58 + RunicSpacing.xs * 2, height: 0)

                if let window = self.summary.windowLabel {
                    InfoPill(text: window)
                }
                if let reset = self.summary.resetDescription {
                    InfoPill(text: reset)
                }
                if let ctx = self.summary.topModelContext {
                    InfoPill(text: ctx)
                }
                Spacer()
            }
        }
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
