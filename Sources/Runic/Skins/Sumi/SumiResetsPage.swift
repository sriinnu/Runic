import RunicCore
import SwiftUI

/// Resets as a list under a tracked label: the window and what is left on
/// the left, the countdown as a Mincho numeral on the right; banked resets
/// under a rule with the count on a seal.
struct SumiResetsPage: View {
    let resets: RunicSkinResets
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    SumiLabel(text: "Resets")
                    Spacer(minLength: 8)
                    if let summary = ResetScheduleMenuView.headerSummary(
                        entries: self.resets.entries,
                        credits: self.resets.credits,
                        now: now)
                    {
                        Text(summary)
                            .font(RunicSumi.copy(11))
                            .skinFace()
                            .foregroundStyle(summary.contains("exhausted") ? self.runicTheme.accent : self.runicTheme
                                .secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, 2)

                ForEach(Array(self.resets.entries.enumerated()), id: \.element.id) { index, entry in
                    SumiResetRow(entry: entry, now: now, showsProvider: self.resets.showsProvider)
                        .padding(.vertical, 9)
                    if index < self.resets.entries.count - 1 {
                        Rectangle()
                            .fill(self.runicTheme.primaryText.opacity(0.1))
                            .frame(height: 1)
                    }
                }

                if !self.resets.credits.isEmpty {
                    Rectangle()
                        .fill(self.runicTheme.primaryText.opacity(0.25))
                        .frame(height: 1)
                        .padding(.top, self.resets.entries.isEmpty ? 4 : 6)
                    ForEach(self.resets.credits) { credit in
                        SumiCreditRow(entry: credit, now: now, showsProvider: self.resets.showsProvider)
                            .padding(.top, 10)
                    }
                }
            }
            .skinFace()
            .frame(width: self.resets.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
    }
}

private struct SumiResetRow: View {
    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                self.title
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let remaining = self.entry.remainingPercent {
                    Text(self.entry.isExhausted ? "exhausted" : "\(Int(remaining.rounded()))% left")
                        .font(RunicSumi.copy(11))
                        .skinFace()
                        .foregroundStyle(self.entry.isExhausted ? self.runicTheme.accent : self.runicTheme
                            .secondaryText)
                } else if let text = self.entry.fallbackText {
                    Text(text)
                        .font(RunicSumi.copy(11))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(self.countdownText)
                    .font(RunicSumi.numeral(18))
                    .skinFace()
                    .foregroundStyle(self.countdownColor)
                    .lineLimit(1)
                if let expiry = self.entry.resetsAt.map({ UsageFormatter.resetExpiryString(from: $0, now: self.now) }) {
                    Text(expiry)
                        .font(RunicSumi.copy(10.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private var title: Text {
        // Runs of a concatenated `Text` resolve their own design, so the
        // pin goes on each run (see `skinFace()`).
        if self.showsProvider {
            return Text(self.entry.providerName).font(RunicSumi.strong(13)).fontDesign(nil)
                + Text(" \u{00B7} \(self.entry.windowTitle)").font(RunicSumi.copy(13)).fontDesign(nil)
        }
        return Text(self.entry.windowTitle).font(RunicSumi.strong(13)).fontDesign(nil)
    }

    private var countdownText: String {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return "\u{2014}" }
        if seconds <= 0 { return "now" }
        return ResetScheduleMenuView.compactDuration(seconds)
    }

    private var countdownColor: Color {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return self.runicTheme.secondaryText }
        if self.entry.isExhausted { return self.runicTheme.accent }
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

private struct SumiCreditRow: View {
    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SumiSeal(text: "\(self.entry.availableCount)", size: 32, rotation: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(self.showsProvider
                    ? "Banked resets \u{00B7} \(self.entry.providerName)"
                    : (self.entry.availableCount == 1 ? "Banked reset" : "Banked resets"))
                    .font(RunicSumi.strong(13))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                Text(self.detailText)
                    .font(RunicSumi.copy(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let latest = self.entry.latestExpiry {
                Text(ResetScheduleMenuView.compactDuration(max(0, latest.timeIntervalSince(self.now))))
                    .font(RunicSumi.numeral(18))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
            }
        }
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
