import RunicCore
import SwiftUI

/// Resets as the schedule table of a drawing: ITEM / WINDOW / LEFT / RESET
/// under a ruled header, items numbered per provider (1.1, 1.2, 2.1), and
/// banked resets as a row with the count in an amber outlined cell.
struct DraftingResetsPage: View {
    let resets: RunicSkinResets
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let ink = self.runicTheme.primary
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    DraftingCap(text: "Schedule of resets")
                    Spacer(minLength: 8)
                    if let summary = ResetScheduleMenuView.headerSummary(
                        entries: self.resets.entries,
                        credits: self.resets.credits,
                        now: now)
                    {
                        Text(summary.uppercased())
                            .font(RunicDrafting.mono(9.5))
                            .skinFace()
                            .tracking(1)
                            .foregroundStyle(summary.contains("exhausted") ? self.runicTheme.warm : self.runicTheme
                                .secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, 6)

                if !self.resets.entries.isEmpty {
                    let items = self.itemNumbers
                    VStack(spacing: 0) {
                        DraftingScheduleHeader()
                            .draftingEdges(.bottom, color: ink)
                        ForEach(Array(self.resets.entries.enumerated()), id: \.element.id) { index, entry in
                            DraftingScheduleRow(
                                item: items[index],
                                entry: entry,
                                now: now,
                                showsProvider: self.resets.showsProvider)
                                .draftingEdges(
                                    index < self.resets.entries.count - 1 ? .bottom : [],
                                    color: ink.opacity(0.35))
                        }
                    }
                    .overlay(Rectangle().stroke(ink, lineWidth: 1))
                }

                ForEach(self.resets.credits) { credit in
                    DraftingCreditRow(entry: credit, now: now, showsProvider: self.resets.showsProvider)
                        .padding(.top, 12)
                }
            }
            .skinFace()
            .frame(width: self.resets.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
    }

    /// "1.1", "1.2", "2.1": the provider's order of first appearance, then
    /// the window's order within it.
    private var itemNumbers: [String] {
        var providerOrder: [UsageProvider] = []
        var windowCounts: [UsageProvider: Int] = [:]
        return self.resets.entries.map { entry in
            if !providerOrder.contains(entry.provider) { providerOrder.append(entry.provider) }
            let provider = (providerOrder.firstIndex(of: entry.provider) ?? 0) + 1
            let window = (windowCounts[entry.provider] ?? 0) + 1
            windowCounts[entry.provider] = window
            return "\(provider).\(window)"
        }
    }
}

// MARK: - Columns

private enum DraftingScheduleColumns {
    static let item: CGFloat = 34
    static let left: CGFloat = 40
    static let reset: CGFloat = 104
}

private struct DraftingScheduleHeader: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 6) {
            Text("ITEM").frame(width: DraftingScheduleColumns.item, alignment: .leading)
            Text("WINDOW").frame(maxWidth: .infinity, alignment: .leading)
            Text("LEFT").frame(width: DraftingScheduleColumns.left, alignment: .leading)
            Text("RESET").frame(width: DraftingScheduleColumns.reset, alignment: .trailing)
        }
        .font(RunicDrafting.mono(9, .medium))
        .skinFace()
        .tracking(1.2)
        .foregroundStyle(self.runicTheme.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }
}

private struct DraftingScheduleRow: View {
    let item: String
    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(self.item)
                .font(RunicDrafting.mono(10.5))
                .skinFace()
                .foregroundStyle(self.runicTheme.secondary)
                .frame(width: DraftingScheduleColumns.item, alignment: .leading)
            Text(self.windowText)
                .font(RunicDrafting.copy(11.5))
                .skinFace()
                .foregroundStyle(self.runicTheme.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(self.leftText)
                .font(RunicDrafting.mono(10.5))
                .skinFace()
                .foregroundStyle(self.entry.isExhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                .lineLimit(1)
                .frame(width: DraftingScheduleColumns.left, alignment: .leading)
            self.resetText
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: DraftingScheduleColumns.reset, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private var windowText: String {
        self.showsProvider ? "\(self.entry.providerName) \u{00B7} \(self.entry.windowTitle)" : self.entry.windowTitle
    }

    private var leftText: String {
        if let remaining = self.entry.remainingPercent { return "\(Int(remaining.rounded()))%" }
        return "\u{2014}"
    }

    /// Countdown in bold with the wall-clock moment after it, each run
    /// pinned to its face (see `skinFace()`).
    private var resetText: Text {
        let countdown = Text(self.countdownText)
            .font(RunicDrafting.mono(11, .bold))
            .fontDesign(nil)
            .foregroundColor(self.countdownColor)
        guard let date = self.entry.resetsAt else {
            if let fallback = self.entry.fallbackText, self.entry.secondsUntilReset(now: self.now) == nil {
                return Text(fallback).font(RunicDrafting.mono(10)).fontDesign(nil)
                    .foregroundColor(self.runicTheme.secondary)
            }
            return countdown
        }
        let expiry = Text(" \(UsageFormatter.resetExpiryString(from: date, now: self.now))")
            .font(RunicDrafting.mono(10))
            .fontDesign(nil)
            .foregroundColor(self.runicTheme.secondary)
        return countdown + expiry
    }

    private var countdownText: String {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return "\u{2014}" }
        if seconds <= 0 { return "now" }
        return ResetScheduleMenuView.compactDuration(seconds)
    }

    private var countdownColor: Color {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return self.runicTheme.secondary }
        if self.entry.isExhausted { return self.runicTheme.warm }
        if seconds <= 30 * 60 { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }

    private var accessibilityText: String {
        var parts = ["Item \(self.item)"]
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

// MARK: - Banked

private struct DraftingCreditRow: View {
    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let amber = self.runicTheme.highlight
        HStack(alignment: .center, spacing: 12) {
            Text("\(self.entry.availableCount)")
                .font(RunicDrafting.numeral(18))
                .skinFace()
                .foregroundStyle(amber)
                .frame(width: 40, height: 40)
                .overlay(Rectangle().stroke(amber, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(self.showsProvider
                    ? "Banked resets \u{00B7} \(self.entry.providerName)"
                    : (self.entry.availableCount == 1 ? "Banked reset" : "Banked resets"))
                    .font(RunicDrafting.strong(12.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                Text(self.detailText)
                    .font(RunicDrafting.mono(10))
                    .skinFace()
                    .tracking(0.8)
                    .foregroundStyle(self.runicTheme.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let latest = self.entry.latestExpiry {
                Text(ResetScheduleMenuView.compactDuration(max(0, latest.timeIntervalSince(self.now))))
                    .font(RunicDrafting.numeral(14))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.entry.providerName), \(self.entry.summaryText)")
    }

    /// "REDEEM AT PROVIDER · EXP NOV 5–6": expiries in one month collapse
    /// to a day range; across months they are listed.
    private var detailText: String {
        let expiries = self.entry.expiries.sorted()
        guard let first = expiries.first, let last = expiries.last else { return "REDEEM AT PROVIDER" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let calendar = Calendar.current
        let sameMonth = calendar.isDate(first, equalTo: last, toGranularity: .month)
        let range: String
        if sameMonth {
            formatter.dateFormat = "MMM"
            let month = formatter.string(from: first).uppercased()
            let firstDay = calendar.component(.day, from: first)
            let lastDay = calendar.component(.day, from: last)
            range = firstDay == lastDay ? "\(month) \(firstDay)" : "\(month) \(firstDay)\u{2013}\(lastDay)"
        } else {
            formatter.dateFormat = "MMM d"
            range = "\(formatter.string(from: first))\u{2013}\(formatter.string(from: last))".uppercased()
        }
        return "REDEEM AT PROVIDER \u{00B7} EXP \(range)"
    }
}
