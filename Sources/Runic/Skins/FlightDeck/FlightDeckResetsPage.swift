import RunicCore
import SwiftUI

/// Resets as waypoints: "WP1 CLAUDE SES 15:39 00:18" rows under a tracked
/// label — the waypoint in cyan, or magenta once the window is exhausted —
/// and banked resets as a bordered HELD row.
struct FlightDeckResetsPage: View {
    let resets: RunicSkinResets
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    FlightDeckLabel(text: "Waypoints \u{00B7} Resets")
                    Spacer(minLength: 8)
                    if let summary = ResetScheduleMenuView.headerSummary(
                        entries: self.resets.entries,
                        credits: self.resets.credits,
                        now: now)
                    {
                        FlightDeckLabel(
                            text: summary,
                            color: summary.contains("exhausted") ? self.runicTheme.warm : self.runicTheme.secondaryText,
                            tracking: 0.6)
                    }
                }
                .padding(.bottom, 4)

                ForEach(Array(self.resets.entries.enumerated()), id: \.element.id) { index, entry in
                    FlightDeckWaypointRow(
                        index: index + 1,
                        entry: entry,
                        now: now,
                        showsProvider: self.resets.showsProvider,
                        isLast: index == self.resets.entries.count - 1)
                }

                if !self.resets.credits.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(self.resets.credits) { credit in
                            FlightDeckHeldRow(entry: credit, now: now, showsProvider: self.resets.showsProvider)
                        }
                    }
                    .padding(.top, self.resets.entries.isEmpty ? 2 : 8)
                }
            }
            .skinFace()
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: self.resets.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
    }
}

private struct FlightDeckWaypointRow: View {
    let index: Int
    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool
    let isLast: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let tone = self.entry.isExhausted ? self.runicTheme.warm : self.runicTheme.accent
        HStack(alignment: .center, spacing: 10) {
            Text("WP\(self.index)")
                .font(RunicFlightDeck.mono(10.5))
                .skinFace()
                .foregroundStyle(tone)
                .frame(width: 32, alignment: .leading)
            Text(self.name)
                .font(RunicFlightDeck.mono(10.5))
                .skinFace()
                .foregroundStyle(self.runicTheme.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            Text(self.remainingText)
                .font(RunicFlightDeck.mono(9))
                .skinFace()
                .foregroundStyle(self.entry.isExhausted ? self.runicTheme.warm : self.runicTheme.secondaryText)
                .lineLimit(1)
            Text(self.atText)
                .font(RunicFlightDeck.mono(10))
                .skinFace()
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(1)
                .frame(minWidth: 40, alignment: .trailing)
            Text(self.etaText)
                .font(RunicFlightDeck.mono(11, .bold))
                .skinFace()
                .foregroundStyle(self.etaColor)
                .lineLimit(1)
                .frame(minWidth: 46, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            if !self.isLast { FlightDeckRule() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    /// "CLAUDE SES" or just "SES".
    private var name: String {
        let code = RunicFlightDeck.windowCode(self.entry.windowTitle)
        return self.showsProvider ? "\(RunicFlightDeck.callsign(self.entry.providerName)) \(code)" : code
    }

    private var remainingText: String {
        if let remaining = self.entry.remainingPercent {
            return self.entry.isExhausted ? "EXH" : "\(Int(remaining.rounded()))%"
        }
        return ""
    }

    private var atText: String {
        guard let date = self.entry.resetsAt else { return self.entry.fallbackText?.uppercased() ?? "----" }
        return RunicFlightDeck.wallClock(date, now: self.now)
    }

    private var etaText: String {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return "----" }
        if seconds <= 0 { return "NOW" }
        return RunicFlightDeck.eta(seconds)
    }

    private var etaColor: Color {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return RunicFlightDeck.dim }
        if self.entry.isExhausted { return self.runicTheme.warm }
        if seconds <= 30 * 60 { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }

    private var accessibilityText: String {
        var parts = ["Waypoint \(self.index)"]
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

private struct FlightDeckHeldRow: View {
    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            FlightDeckTag(text: "HELD \u{00D7}\(self.entry.availableCount)", tone: .amber)
            Text(self.text)
                .font(RunicFlightDeck.mono(10))
                .skinFace()
                .foregroundStyle(self.runicTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            if let latest = self.entry.latestExpiry {
                Text(RunicFlightDeck.eta(max(0, latest.timeIntervalSince(self.now))))
                    .font(RunicFlightDeck.mono(11, .bold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.highlight)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .overlay(Rectangle().stroke(self.runicTheme.cardStroke, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.entry.providerName), \(self.entry.summaryText)")
    }

    private var text: String {
        let who = self.showsProvider ? "\(RunicFlightDeck.callsign(self.entry.providerName)) " : ""
        return "\(who)BANKED RESETS \u{00B7} REDEEM AT PROVIDER"
    }
}
