import RunicCore
import SwiftUI

/// The departures table: a header row, every window as a departure with
/// its time and remaining on flaps and its status word, banked resets as
/// HELD rows, and the board ticker under it all.
struct DeparturesResetsPage: View {
    let resets: RunicSkinResets
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    DeparturesHeader(text: "Departures")
                    Spacer(minLength: 8)
                    if let summary = ResetScheduleMenuView.headerSummary(
                        entries: self.resets.entries,
                        credits: self.resets.credits,
                        now: now)
                    {
                        Text(summary.uppercased())
                            .font(RunicDepartures.condensed(11))
                            .skinFace()
                            .tracking(1.3)
                            .foregroundStyle(summary.contains("exhausted") ? self.runicTheme.warm : self.runicTheme
                                .secondary)
                            .lineLimit(1)
                    }
                }
                DeparturesTableHeader(width: self.resets.width)

                ForEach(Array(self.resets.entries.enumerated()), id: \.element.id) { index, entry in
                    self.row(for: entry, now: now)
                    if index < self.resets.entries.count - 1 || !self.resets.credits.isEmpty {
                        DeparturesHairline()
                    }
                }

                ForEach(Array(self.resets.credits.enumerated()), id: \.element.id) { index, credit in
                    self.heldRow(for: credit, now: now)
                    if index < self.resets.credits.count - 1 {
                        DeparturesHairline()
                    }
                }

                DeparturesTicker(text: self.ticker(now: now))
                    .padding(.top, 10)
            }
            .skinFace()
            .frame(width: self.resets.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
    }

    // MARK: Rows

    private func row(for entry: ResetScheduleEntry, now: Date) -> some View {
        let seconds = entry.secondsUntilReset(now: now)
        var subtitle: [String] = []
        if self.resets.showsProvider { subtitle.append(entry.windowTitle) }
        subtitle.append("Gate \(RunicDepartures.gate(for: entry.provider))")
        if let used = entry.usedPercent { subtitle.append("\(Int(used.rounded()))%") }
        if seconds == nil, let text = entry.fallbackText, !text.isEmpty { subtitle.append(text) }
        let status: DeparturesStatus? = entry.usedPercent == nil && seconds == nil
            ? nil
            : DeparturesStatus.forWindow(
                exhausted: entry.isExhausted,
                secondsUntilReset: seconds,
                palette: self.runicTheme)
        return DeparturesRow(
            width: self.resets.width,
            time: entry.resetsAt.map { RunicDepartures.boardTime($0, now: now) },
            title: self.resets.showsProvider ? entry.providerName : entry.windowTitle,
            subtitle: subtitle.joined(separator: " \u{00B7} "),
            remaining: seconds.map(RunicDepartures.boardRemaining),
            status: status,
            accessibilityLabel: self.accessibilityText(for: entry, now: now))
    }

    private func heldRow(for credit: ResetCreditEntry, now: Date) -> some View {
        let latest = credit.latestExpiry.map { max(0, $0.timeIntervalSince(now)) }
        var subtitle = "Banked \u{00D7} \(credit.availableCount) \u{00B7} redeem"
        if self.resets
            .showsProvider { subtitle = "Gate \(RunicDepartures.gate(for: credit.provider)) \u{00B7} " + subtitle }
        return DeparturesRow(
            width: self.resets.width,
            time: credit.latestExpiry.map { RunicDepartures.boardTime($0, now: now) },
            title: self.resets.showsProvider ? credit.providerName : (credit.title ?? "Banked"),
            subtitle: subtitle,
            remaining: latest.map(RunicDepartures.boardRemaining),
            status: .held(self.runicTheme),
            accessibilityLabel: "\(credit.providerName), \(credit.summaryText)")
    }

    private func accessibilityText(for entry: ResetScheduleEntry, now: Date) -> String {
        var parts: [String] = []
        if self.resets.showsProvider { parts.append(entry.providerName) }
        parts.append(entry.windowTitle)
        if let remaining = entry.remainingPercent {
            parts.append(entry.isExhausted ? "exhausted" : "\(Int(remaining.rounded())) percent left")
        }
        if let seconds = entry.secondsUntilReset(now: now) {
            parts.append("resets in \(ResetScheduleMenuView.compactDuration(seconds))")
        } else if let text = entry.fallbackText {
            parts.append(text)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Ticker

    /// "BOARD UPDATED 15:21 · NEXT FLIP 15:39 CLAUDE SESSION · 2 HELD"
    private func ticker(now: Date) -> String {
        var parts = ["Board updated \(RunicDepartures.clock(now))"]
        let dated = self.resets.entries.filter { $0.resetsAt != nil }
        if let next = dated.min(by: { ($0.resetsAt ?? .distantFuture) < ($1.resetsAt ?? .distantFuture) }),
           let at = next.resetsAt
        {
            let when = Calendar.current.isDate(at, inSameDayAs: now)
                ? RunicDepartures.clock(at)
                : RunicDepartures.boardTime(at, now: now)
            parts.append("Next flip \(when) \(next.providerName) \(next.windowTitle)")
        }
        let held = self.resets.credits.reduce(0) { $0 + $1.availableCount }
        if held > 0 { parts.append("\(held) held") }
        return parts.joined(separator: " \u{00B7} ")
    }
}
