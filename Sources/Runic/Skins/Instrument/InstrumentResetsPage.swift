import RunicCore
import SwiftUI

/// Resets as the instrument's timer plate: "RESET TIMERS" engraved with the
/// summary beside it, every window as a row on one LCD list ("CLAUDE
/// SESSION  EXH  00:18  15:39"), and banked resets under a groove with the
/// count on an LCD counter.
struct InstrumentResetsPage: View {
    let resets: RunicSkinResets
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let summary = ResetScheduleMenuView.headerSummary(
                entries: self.resets.entries,
                credits: self.resets.credits,
                now: now)
            InstrumentPlate(padding: .init(top: 10, leading: 12, bottom: 10, trailing: 12)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        InstrumentEngraved(text: "Reset timers")
                        Spacer(minLength: 8)
                        if let summary {
                            InstrumentEngraved(
                                text: summary,
                                color: summary.contains("exhausted") ? RunicInstrument.Paint.lcdAlert : nil)
                        }
                    }

                    if !self.resets.entries.isEmpty {
                        InstrumentLCD(padding: .init(top: 2, leading: 10, bottom: 2, trailing: 10)) {
                            VStack(spacing: 0) {
                                ForEach(Array(self.resets.entries.enumerated()), id: \.element.id) { index, entry in
                                    InstrumentResetRow(entry: entry, now: now, showsProvider: self.resets.showsProvider)
                                        .padding(.vertical, 7)
                                    if index < self.resets.entries.count - 1 {
                                        Rectangle()
                                            .fill(RunicInstrument.Paint.lcdText.opacity(0.25))
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                    }

                    if !self.resets.credits.isEmpty {
                        if !self.resets.entries.isEmpty {
                            InstrumentGroove()
                                .padding(.vertical, 2)
                        }
                        ForEach(self.resets.credits) { credit in
                            InstrumentCreditRow(entry: credit, now: now, showsProvider: self.resets.showsProvider)
                        }
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

/// One line on the LCD list: channel and window, what is left, the
/// countdown and the wall-clock moment.
private struct InstrumentResetRow: View {
    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(self.title)
                .font(RunicInstrument.lcd(11))
                .skinFace()
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
            Spacer(minLength: 6)
            Text(self.remainingText)
                .font(RunicInstrument.lcd(11))
                .skinFace()
                .foregroundStyle(self.entry.isExhausted ? RunicInstrument.Paint.lcdAlert : RunicInstrument.Paint
                    .lcdText)
                .opacity(self.entry.isExhausted ? 1 : 0.7)
                .lineLimit(1)
            Text(self.timeText)
                .font(RunicInstrument.lcd(11, bold: true))
                .skinFace()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(RunicInstrument.Paint.lcdText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private var title: String {
        let window = self.entry.windowTitle.uppercased()
        guard self.showsProvider else { return window }
        return "\(self.entry.providerName.uppercased())  \(window)"
    }

    private var remainingText: String {
        if let remaining = self.entry.remainingPercent {
            return self.entry.isExhausted ? "EXH" : "\(Int(remaining.rounded()))%"
        }
        return "--"
    }

    private var timeText: String {
        guard let seconds = self.entry.secondsUntilReset(now: self.now), let resetsAt = self.entry.resetsAt else {
            return self.entry.fallbackText.map { RunicInstrument.lcdReset($0) } ?? "--:--"
        }
        return "\(RunicInstrument.lcdCountdown(seconds))  \(RunicInstrument.lcdClock(resetsAt, now: self.now))"
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
        } else if let text = self.entry.fallbackText {
            parts.append(text)
        }
        return parts.joined(separator: ", ")
    }
}

/// Banked resets: the count on an LCD counter, "BANKED · CLAUDE" engraved
/// with the redeem line beneath, the bank's life on a second LCD.
private struct InstrumentCreditRow: View {
    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            InstrumentLCDText(
                text: String(format: "%02d", self.entry.availableCount),
                size: 18,
                bold: true,
                alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                InstrumentEngraved(text: self.showsProvider
                    ? "Banked \u{00B7} \(self.entry.providerName)"
                    : (self.entry.availableCount == 1 ? "Banked reset" : "Banked resets"))
                Text(self.detailText)
                    .font(RunicInstrument.copy(12))
                    .skinFace()
                    .foregroundStyle(RunicInstrument.Paint.engrave)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let latest = self.entry.latestExpiry {
                InstrumentLCDText(text: RunicInstrument.lcdCountdown(latest.timeIntervalSince(self.now)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.entry.providerName), \(self.entry.summaryText)")
    }

    private var detailText: String {
        let dates = self.entry.expiries.map { $0.formatted(.dateTime.month(.abbreviated).day()) }
        let distinct = Array(NSOrderedSet(array: dates)) as? [String] ?? dates
        if !distinct.isEmpty {
            return "redeem at the provider \u{00B7} exp " + distinct.joined(separator: " \u{00B7} ")
        }
        return "redeem at the provider"
    }
}
