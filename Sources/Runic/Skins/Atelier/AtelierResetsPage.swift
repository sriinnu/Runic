import RunicCore
import SwiftUI

// MARK: - Atelier Resets Page

/// Architectural reset schedule table: single `0px` specification ledger
/// divided by `1px` rules with prioritized non-truncating mono countdowns
/// and crisp elapsed hairline gauges.
struct AtelierResetsPage: View {
    let resets: RunicSkinResets
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    AtelierKicker(text: "Resets")
                    Spacer(minLength: 6)
                    if let summary = ResetScheduleMenuView.headerSummary(
                        entries: self.resets.entries,
                        credits: self.resets.credits,
                        now: now)
                    {
                        Text(summary)
                            .font(RunicAtelier.mono(9.5, .medium))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, RunicAtelier.panelInset)
                .padding(.vertical, 8)
                .background(self.runicTheme.surfaceAlt.opacity(0.6))

                ForEach(self.resets.entries) { entry in
                    AtelierHairline()
                    AtelierResetRow(
                        entry: entry,
                        now: now,
                        showsProvider: self.resets.showsProvider)
                }

                ForEach(self.resets.credits) { credit in
                    AtelierHairline()
                    AtelierCreditRow(
                        entry: credit,
                        now: now,
                        showsProvider: self.resets.showsProvider)
                }
            }
            .skinFace()
            .background(self.runicTheme.cardFill)
            .frame(width: self.resets.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
    }
}

private struct AtelierResetRow: View {
    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    self.title
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let remaining = self.entry.remainingPercent {
                        Text(self.entry.isExhausted ? "exhausted" : "\(Int(remaining.rounded()))% left")
                            .font(RunicAtelier.mono(9.5))
                            .skinFace()
                            .foregroundStyle(self.entry.isExhausted
                                ? self.runicTheme.warm
                                : self.runicTheme.secondaryText)
                    } else if let text = self.entry.fallbackText {
                        Text(text)
                            .font(RunicAtelier.mono(9.5))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(self.countdownText)
                        .font(RunicAtelier.mono(13.5, .semibold))
                        .skinFace()
                        .foregroundStyle(self.countdownColor)
                        .lineLimit(1)
                    if let resetsAt = self.entry.resetsAt {
                        Text(UsageFormatter.resetExpiryString(from: resetsAt, now: self.now))
                            .font(RunicAtelier.mono(9.5))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)
            }
            if let elapsed = self.entry.elapsedFraction(now: self.now) {
                AtelierGauge(
                    percent: elapsed * 100,
                    tint: self.entry.isExhausted ? self.runicTheme.warm : self.runicTheme.accent,
                    accessibilityLabel: "Window elapsed",
                    height: 4)
            }
        }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private var title: Text {
        if self.showsProvider {
            return Text(self.entry.providerName).font(RunicAtelier.sans(12, .medium)).fontDesign(nil)
                + Text(" \u{00B7} \(self.entry.windowTitle)").font(RunicAtelier.sans(12, .regular)).fontDesign(nil)
        }
        return Text(self.entry.windowTitle).font(RunicAtelier.sans(12, .medium)).fontDesign(nil)
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

private struct AtelierCreditRow: View {
    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(self.entry.availableCount)")
                .font(RunicAtelier.mono(13, .semibold))
                .skinFace()
                .foregroundStyle(self.runicTheme.tertiary)
                .frame(minWidth: 28, minHeight: 24)
                .background(self.runicTheme.tertiary.opacity(0.10))
                .overlay(Rectangle().strokeBorder(self.runicTheme.tertiary.opacity(0.4), lineWidth: 0.75))

            VStack(alignment: .leading, spacing: 2) {
                let noun = self.entry.availableCount == 1 ? "Banked reset" : "Banked resets"
                Text(self.showsProvider ? "\(noun) \u{00B7} \(self.entry.providerName)" : noun)
                    .font(RunicAtelier.sans(12, .medium))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                Text(self.detailText)
                    .font(RunicAtelier.mono(9.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
            if let deadline = self.entry.nearestExpiry ?? self.entry.latestExpiry {
                let remaining = deadline.timeIntervalSince(self.now)
                Text(remaining <= 0 ? "now" : ResetScheduleMenuView.compactDuration(remaining))
                    .font(RunicAtelier.mono(13.5, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 9)
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
