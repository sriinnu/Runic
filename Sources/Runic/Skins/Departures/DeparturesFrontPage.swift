import AppKit
import RunicCore
import SwiftUI

/// The front of the board, all gates: the kicker, a flap row with the next
/// reset across every provider, the status line, the yellow rule, then one
/// gate card per provider and the week's traffic. The departures table
/// itself is the Resets panel beneath (`DeparturesResetsPage`).
struct DeparturesFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        let exhausted = self.view.summaries.count(where: self.isExhausted)
        let open = self.view.summaries.count - exhausted
        VStack(alignment: .leading, spacing: 0) {
            DeparturesHeader(text: "Runic \u{00B7} departures")
                .padding(.top, 4)
            FlapRow(segments: self.mastheadSegments, scale: .masthead, fit: self.view.width - 4)
                .padding(.top, 10)
            HStack(spacing: 18) {
                self.statusWord(open == 1 ? "1 gate open" : "\(open) gates open")
                if exhausted > 0 {
                    self.statusWord(
                        exhausted == 1 ? "1 exhausted" : "\(exhausted) exhausted",
                        color: self.runicTheme.warm)
                }
                if let average {
                    self.statusWord("avg \(Int(average.rounded()))% \(self.view.showsUsed ? "used" : "left")")
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(self.statusAccessibility(open: open, exhausted: exhausted))
            DeparturesRule()

            if self.view.summaries.isEmpty {
                Text("NO GATES OPEN")
                    .font(RunicDepartures.condensed(13, .medium))
                    .skinFace()
                    .tracking(1.5)
                    .foregroundStyle(self.runicTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, RunicSpacing.md)
            } else {
                DeparturesHeader(text: "Gates")
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                self.gateGrid
                if let onAddRegion = self.view.onAddRegion {
                    ForEach(OverviewMenuView.brandGroups(self.view.summaries)) { group in
                        if let missing = group.missingSlot {
                            Button {
                                onAddRegion(missing)
                            } label: {
                                Text("Add \(missing.region.displayName) account \u{2192}".uppercased())
                                    .font(RunicDepartures.caps(11.5))
                                    .skinFace()
                                    .tracking(1.4)
                                    .foregroundStyle(self.runicTheme.accent)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 10)
                            .accessibilityLabel("Add \(missing.region.displayName) account")
                        }
                    }
                }
            }

            if !self.view.chartPoints.isEmpty {
                DeparturesHairline(opacity: 0.14)
                    .padding(.top, 14)
                HStack(alignment: .center) {
                    DeparturesHeader(text: "7-day traffic")
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(self.view.chartLegendEntries.prefix(5), id: \.name) { entry in
                            Rectangle()
                                .fill(entry.color)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .padding(.top, 12)
                .padding(.bottom, 6)
                self.view.activityChart
            }
        }
        .skinFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(.horizontal, 2)
        .padding(.bottom, 6)
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Masthead

    /// "NEXT · 18M · CLAUDE": the soonest countdown the overview carries,
    /// the provider in red when it has nothing left. "BOARD · 3 GATES" when
    /// no provider names a time.
    private var mastheadSegments: [FlapRow.Segment] {
        let soonest = self.view.summaries
            .compactMap { summary -> (OverviewMenuView.ProviderSummary, TimeInterval)? in
                RunicDepartures.countdownSeconds(in: summary.resetDescription).map { (summary, $0) }
            }
            .min { $0.1 < $1.1 }
        if let (summary, seconds) = soonest {
            return [
                FlapRow.Segment(text: "NEXT"),
                FlapRow.Segment(text: RunicDepartures.flapCountdown(seconds), tint: self.runicTheme.accent),
                FlapRow.Segment(
                    text: String(summary.name.prefix(10)),
                    tint: self.isExhausted(summary) ? self.runicTheme.warm : nil),
            ]
        }
        let count = self.view.summaries.count
        guard count > 0 else { return [FlapRow.Segment(text: "NO GATES")] }
        return [
            FlapRow.Segment(text: "BOARD"),
            FlapRow.Segment(text: count == 1 ? "1 GATE" : "\(count) GATES", tint: self.runicTheme.accent),
        ]
    }

    private func statusWord(_ text: String, color: Color? = nil) -> some View {
        Text(text.uppercased())
            .font(RunicDepartures.condensed(12))
            .skinFace()
            .tracking(1.2)
            .foregroundStyle(color ?? self.runicTheme.secondary)
            .lineLimit(1)
    }

    private func statusAccessibility(open: Int, exhausted: Int) -> String {
        var parts = ["\(open) gates open"]
        if exhausted > 0 { parts.append("\(exhausted) exhausted") }
        parts.append(self.view.averagePercentText)
        return parts.joined(separator: ", ")
    }

    /// Exhausted whichever way the overview counts.
    private func isExhausted(_ summary: OverviewMenuView.ProviderSummary) -> Bool {
        guard summary.hasQuota else { return false }
        return self.view.showsUsed ? summary.usedPercent >= 99.5 : summary.usedPercent <= 0.5
    }

    // MARK: Gates

    /// Two cards to a row.
    private var gateGrid: some View {
        let rows = stride(from: 0, to: self.view.summaries.count, by: 2).map { start in
            Array(self.view.summaries[start..<min(start + 2, self.view.summaries.count)])
        }
        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .top, spacing: 10) {
                    ForEach(pair) { summary in
                        self.gateCard(summary)
                    }
                    if pair.count == 1 {
                        Color.clear.frame(maxWidth: .infinity, minHeight: 1)
                    }
                }
            }
        }
    }

    private func gateCard(_ summary: OverviewMenuView.ProviderSummary) -> some View {
        let exhausted = self.isExhausted(summary)
        let used = self.view.showsUsed ? summary.usedPercent : 100 - summary.usedPercent
        let percentText = summary.hasQuota ? "\(Int(summary.usedPercent.rounded()))%" : "\u{2014}"
        var detail: [String] = []
        if let window = summary.windowLabel, !window.isEmpty { detail.append(window) }
        if let reset = summary.resetDescription, !reset.isEmpty {
            detail.append(RunicDepartures.boardCopy(reset).replacingOccurrences(of: "IN ", with: "FLIPS IN "))
        }
        if let context = summary.topModelContext, !context.isEmpty {
            detail.append(context.hasSuffix(" ctx") ? "ctx \(context.dropLast(4))" : context)
        }
        if let banked = summary.bankedResetsText, !banked.isEmpty {
            detail.append(banked.replacingOccurrences(of: "resets", with: "held")
                .replacingOccurrences(of: "reset", with: "held"))
        }
        return DeparturesGateCard(
            letter: RunicDepartures.gate(for: summary.provider),
            name: summary.name,
            percentText: percentText,
            percent: summary.hasQuota ? used : nil,
            tint: exhausted ? self.runicTheme.warm : self.runicTheme.accent,
            detail: detail.isEmpty ? nil : detail.joined(separator: " \u{00B7} "),
            accessibilityLabel: "\(summary.name) \(percentText) \(self.view.showsUsed ? "used" : "left")")
    }
}
