import RunicCore
import SwiftUI

// MARK: - Gazette Resets Page

/// Broadsheet reset schedule table: flush-left condensed kicker, tabular
/// countdowns (`18m`, `5d`, `25d`) with hairline gauges, and `[count]` banked
/// credit rows separated by fine horizontal rules.
struct GazetteResetsPage: View {
    let resets: RunicSkinResets
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    GazetteKicker(text: "Resets")
                    Spacer(minLength: 8)
                    if let summary = ResetScheduleMenuView.headerSummary(
                        entries: self.resets.entries,
                        credits: self.resets.credits,
                        now: now)
                    {
                        Text(summary.uppercased())
                            .font(RunicGazette.sans(9, .medium))
                            .gazetteFace()
                            .tracking(0.6)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, 6)

                GazetteRule(weight: .single)

                ForEach(Array(self.resets.entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        GazetteRule(weight: .hair)
                    }
                    GazetteResetRow(
                        entry: entry,
                        now: now,
                        showsProvider: self.resets.showsProvider)
                }

                ForEach(Array(self.resets.credits.enumerated()), id: \.element.id) { index, credit in
                    if !self.resets.entries.isEmpty || index > 0 {
                        GazetteRule(weight: .hair)
                    }
                    GazetteCreditRow(
                        entry: credit,
                        now: now,
                        showsProvider: self.resets.showsProvider)
                }
            }
            .gazetteFace()
            .frame(width: self.resets.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
    }
}

private struct GazetteResetRow: View {
    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    self.title
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let remaining = self.entry.remainingPercent {
                        Text(self.entry.isExhausted ? "EXHAUSTED" : "\(Int(remaining.rounded()))% LEFT")
                            .font(RunicGazette.sans(9, .medium))
                            .gazetteFace()
                            .tracking(0.5)
                            .foregroundStyle(
                                self.entry.isExhausted ? self.runicTheme.warm : self.runicTheme.secondaryText)
                    } else if let text = self.entry.fallbackText {
                        Text(text.uppercased())
                            .font(RunicGazette.sans(9, .medium))
                            .gazetteFace()
                            .tracking(0.5)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                HStack(alignment: .center, spacing: 6) {
                    Text(self.countdownText)
                        .font(RunicGazette.sans(12, .bold))
                        .monospacedDigit()
                        .gazetteFace()
                        .foregroundStyle(self.countdownColor)
                        .lineLimit(1)
                    if let resetsAt = self.entry.resetsAt {
                        GazetteColumnRule().frame(height: 10)
                        Text(UsageFormatter.resetExpiryString(from: resetsAt, now: self.now))
                            .font(RunicGazette.sans(10.5, .medium))
                            .monospacedDigit()
                            .gazetteFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)
            }

            if let elapsed = self.entry.elapsedFraction(now: self.now) {
                GazetteBar(
                    percent: elapsed * 100,
                    tint: self.entry.isExhausted ? self.runicTheme.warm : self.runicTheme.primaryText,
                    accessibilityLabel: "Window elapsed",
                    height: 3)
            }
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private var title: Text {
        if self.showsProvider {
            return Text(self.entry.providerName)
                .font(RunicGazette.headline(12))
                .fontDesign(nil)
                + Text(" \u{00B7} \(self.entry.windowTitle)")
                .font(RunicGazette.body(11.5))
                .fontDesign(nil)
        }
        return Text(self.entry.windowTitle)
            .font(RunicGazette.headline(12))
            .fontDesign(nil)
    }

    private var countdownText: String {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return "\u{2014}" }
        if seconds <= 0 { return "now" }
        return ResetScheduleMenuView.compactDuration(seconds)
    }

    private var countdownColor: Color {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return self.runicTheme.secondaryText }
        if self.entry.isExhausted { return self.runicTheme.warm }
        if seconds <= 30 * 60 { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if self.showsProvider { parts.append(self.entry.providerName) }
        parts.append(self.entry.windowTitle)
        if let remaining = self.entry.remainingPercent {
            parts.append(self.entry.isExhausted ? "exhausted" : "\(Int(remaining.rounded())) percent left")
        }
        if let seconds = self.entry.secondsUntilReset(now: self.now) {
            parts.append("resets in \(ResetScheduleMenuView.compactDuration(seconds))")
        }
        return parts.joined(separator: ", ")
    }
}

private struct GazetteCreditRow: View {
    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 6) {
                    let noun = self.entry.availableCount == 1 ? "Banked reset" : "Banked resets"
                    Text(self.showsProvider ? "\(noun) \u{00B7} \(self.entry.providerName)" : noun)
                        .font(RunicGazette.headline(12))
                        .gazetteFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                    GazetteHairlineBadge(
                        text: "[\(self.entry.availableCount)]",
                        textColor: self.runicTheme.tertiary,
                        borderColor: self.runicTheme.tertiary.opacity(0.45),
                        fillColor: self.runicTheme.tertiary.opacity(dark ? 0.14 : 0.08),
                        size: 9)
                }
                Text(self.detailText.uppercased())
                    .font(RunicGazette.sans(9, .medium))
                    .gazetteFace()
                    .tracking(0.5)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let deadline = self.entry.nearestExpiry ?? self.entry.latestExpiry {
                let remaining = deadline.timeIntervalSince(self.now)
                Text(remaining <= 0 ? "now" : ResetScheduleMenuView.compactDuration(remaining))
                    .font(RunicGazette.sans(12, .bold))
                    .monospacedDigit()
                    .gazetteFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.entry.providerName), \(self.entry.summaryText)")
    }

    private var detailText: String {
        let dates = self.entry.expiries.map { $0.formatted(.dateTime.month(.abbreviated).day()) }
        let distinct = Array(NSOrderedSet(array: dates)) as? [String] ?? dates
        if !distinct.isEmpty {
            return "redeem at the provider \u{00B7} expires " + distinct.joined(separator: " \u{00B7} ")
        }
        return "redeem at the provider"
    }
}
