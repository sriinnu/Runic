import RunicCore
import SwiftUI

/// Resets on a ceramic chassis: countdown windows in machined recessed troughs
/// paired with dark slate countdown pills and calibration progress bars, plus
/// banked reset tiles set into recessed wells with held/expiry metadata.
struct ReliefResetsPage: View {
    let resets: RunicSkinResets
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    ReliefLabel(text: "Resets")
                    Spacer(minLength: 8)
                    if let summary = ResetScheduleMenuView.headerSummary(
                        entries: self.resets.entries,
                        credits: self.resets.credits,
                        now: now)
                    {
                        Text(summary)
                            .font(RunicRelief.numeral(10.5, .medium))
                            .skinFace()
                            .foregroundStyle(
                                summary.contains("exhausted")
                                    ? self.runicTheme.warm
                                    : self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                }

                ForEach(self.resets.entries) { entry in
                    ReliefResetWell(entry: entry, now: now, showsProvider: self.resets.showsProvider)
                }

                ForEach(self.resets.credits) { credit in
                    ReliefCreditWell(entry: credit, now: now, showsProvider: self.resets.showsProvider)
                }
            }
            .skinFace()
            .frame(width: self.resets.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
    }
}

private struct ReliefResetWell: View {
    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                ReliefLED(color: self.ledColor, size: 6)
                VStack(alignment: .leading, spacing: 2) {
                    self.title
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let remaining = self.entry.remainingPercent {
                        Text(self.entry.isExhausted ? "EXHAUSTED" : "\(Int(remaining.rounded()))% LEFT")
                            .font(RunicRelief.numeral(10, .semibold))
                            .skinFace()
                            .foregroundStyle(
                                self.entry.isExhausted
                                    ? self.runicTheme.warm
                                    : self.runicTheme.secondaryText)
                    } else if let text = self.entry.fallbackText {
                        Text(text)
                            .font(RunicRelief.face(10.5))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    ReliefCapsule(text: self.countdownText, tone: self.capsuleTone)
                    if let resetsAt = self.entry.resetsAt {
                        Text(UsageFormatter.resetExpiryString(from: resetsAt, now: self.now))
                            .font(RunicRelief.face(10))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            if let elapsed = self.entry.elapsedFraction(now: self.now) {
                ReliefGauge(
                    percent: elapsed * 100,
                    accessibilityLabel: "Window elapsed",
                    nib: self.entry.isExhausted ? RunicRelief.ledRed : RunicRelief.signal,
                    fillTint: self.entry.isExhausted ? self.runicTheme.warm : self.entry.brandColor,
                    troughHeight: 8,
                    showsScale: false)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .reliefWell(radius: 9, depth: 0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private var title: Text {
        if self.showsProvider {
            return Text(self.entry.providerName).font(RunicRelief.face(12.5, .semibold)).fontDesign(nil)
                + Text(" \u{00B7} \(self.entry.windowTitle)").font(RunicRelief.face(12)).fontDesign(nil)
        }
        return Text(self.entry.windowTitle).font(RunicRelief.face(12.5, .semibold)).fontDesign(nil)
    }

    private var ledColor: Color {
        if self.entry.isExhausted { return RunicRelief.ledRed }
        if let seconds = self.entry.secondsUntilReset(now: self.now), seconds <= 30 * 60 {
            return RunicRelief.ledAmber
        }
        return RunicRelief.ledGreen
    }

    private var capsuleTone: Color? {
        if self.entry.isExhausted { return self.runicTheme.warm }
        if let seconds = self.entry.secondsUntilReset(now: self.now), seconds <= 30 * 60 {
            return self.runicTheme.highlight
        }
        return nil
    }

    private var countdownText: String {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return "\u{2014}" }
        if seconds <= 0 { return "now" }
        return ResetScheduleMenuView.compactDuration(seconds)
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

private struct ReliefCreditWell: View {
    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ReliefCapsule(text: "\(self.entry.availableCount)", tone: self.runicTheme.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                let noun = self.entry.availableCount == 1 ? "Banked reset" : "Banked resets"
                Text(self.showsProvider ? "\(noun) \u{00B7} \(self.entry.providerName)" : noun)
                    .font(RunicRelief.face(12.5, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                Text(self.detailText)
                    .font(RunicRelief.face(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            if let deadline = self.entry.nearestExpiry ?? self.entry.latestExpiry {
                let remaining = deadline.timeIntervalSince(self.now)
                Text(remaining <= 0 ? "now" : ResetScheduleMenuView.compactDuration(remaining))
                    .font(RunicRelief.numeral(14, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .reliefWell(radius: 9, depth: 0.75)
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
