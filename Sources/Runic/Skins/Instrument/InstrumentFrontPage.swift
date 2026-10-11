import AppKit
import RunicCore
import SwiftUI

/// The overview as the master section of the instrument: "MASTER · ALL
/// CHANNELS" over RUNIC with an LCD channel count, a master VU meter for the
/// day's average beside a big LCD, a channels plate with a 20-segment level
/// bar per provider, and a 7-day activity plate of LED columns.
struct InstrumentFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        let exhausted = self.view.summaries.count(where: { $0.hasQuota && $0.usedPercent >= 99.5 })
        VStack(alignment: .leading, spacing: 12) {
            self.masthead(exhausted: exhausted)
                .padding(.top, 6)
                .padding(.horizontal, 2)

            InstrumentGroove()

            self.mainMeterPlate(average: average, exhausted: exhausted)

            if self.view.summaries.isEmpty {
                InstrumentPlate {
                    Text("No active channels.")
                        .font(RunicInstrument.copy())
                        .skinFace()
                        .foregroundStyle(RunicInstrument.Paint.engrave)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, RunicSpacing.xs)
                }
            } else {
                self.channelsPlate
            }

            if !self.view.chartPoints.isEmpty {
                InstrumentActivityPlate(points: self.view.chartPoints, numberStyle: self.view.numberStyle)
            }
        }
        .skinFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(.bottom, 4)
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Masthead

    private func masthead(exhausted: Int) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                InstrumentEngraved(text: "Master \u{00B7} all channels")
                Text("RUNIC")
                    .font(RunicInstrument.name(30))
                    .skinFace()
                    .tracking(1.8)
                    .foregroundStyle(self.runicTheme.primary)
                    .shadow(color: Color.white.opacity(0.7), radius: 0, y: 1)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            InstrumentLCD {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("CH \(self.view.summaries.count)/\(self.view.totalProviders) ON")
                        .font(RunicInstrument.lcd(11))
                        .skinFace()
                    Text(exhausted > 0 ? "\(exhausted) CLIP" : "NO CLIP")
                        .font(RunicInstrument.lcd(11))
                        .skinFace()
                        .foregroundStyle(exhausted > 0
                            ? RunicInstrument.Paint.lcdAlert
                            : RunicInstrument.Paint.lcdText)
                        .opacity(exhausted > 0 ? 1 : 0.75)
                }
                .lineLimit(1)
                .frame(minWidth: 84, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(self.view.summaries.count) of \(self.view.totalProviders) channels on, \(exhausted) exhausted")
        }
    }

    // MARK: Main meter

    private func mainMeterPlate(average: Double?, exhausted: Int) -> some View {
        let used = self.view.showsUsed
        return InstrumentPlate(padding: .init(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            HStack(alignment: .center, spacing: 14) {
                InstrumentVUMeter(
                    title: "Avg today",
                    percent: average,
                    redZoneLow: !used,
                    accessibilityLabel: self.view.averagePercentText)
                VStack(alignment: .trailing, spacing: 8) {
                    InstrumentLCDText(
                        text: average.map { "\(Int($0.rounded()))%" } ?? "--%",
                        size: 22,
                        bold: true,
                        dim: average == nil)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    InstrumentEngraved(text: "\(used ? "Used" : "Left") \u{00B7} avg")
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(self.view.summaries.count) of \(self.view.totalProviders) active")
                        if exhausted > 0 {
                            Text(exhausted == 1 ? "1 exhausted" : "\(exhausted) exhausted")
                                .foregroundStyle(self.runicTheme.accent)
                        }
                        if self.view.totalTodayTokens > 0 {
                            let tokens = UsageFormatter.tokenCountString(
                                self.view.totalTodayTokens,
                                style: self.view.numberStyle)
                            Text("\(tokens) today")
                        }
                    }
                    .font(RunicInstrument.copy(12))
                    .skinFace()
                    .foregroundStyle(RunicInstrument.Paint.engrave)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: Channels

    private var channelsPlate: some View {
        InstrumentPlate(padding: .init(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(self.view.summaries.enumerated()), id: \.element.id) { index, summary in
                    InstrumentChannelRow(summary: summary, channel: index + 1, showsUsed: self.view.showsUsed)
                }
                if let onAddRegion = self.view.onAddRegion {
                    ForEach(OverviewMenuView.brandGroups(self.view.summaries)) { group in
                        if let missing = group.missingSlot {
                            InstrumentKey(
                                title: "Add \(missing.region.displayName) account",
                                systemImage: "plus",
                                height: 24,
                                size: 9.5,
                                horizontalPadding: 9)
                            {
                                onAddRegion(missing)
                            }
                            .accessibilityLabel("Add \(missing.region.displayName) account")
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Channels")
    }
}

// MARK: - Channel row

/// One provider on the channels plate: its name in bold caps over "CH n",
/// a 20-segment level bar in the brand's reading, the percent on an LCD —
/// or CLIP in red when the window is spent.
struct InstrumentChannelRow: View {
    let summary: OverviewMenuView.ProviderSummary
    let channel: Int
    let showsUsed: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let clipped = self.summary.hasQuota && (self.showsUsed
            ? self.summary.usedPercent >= 99.5
            : self.summary.usedPercent <= 0.5)
        let level = self.showsUsed ? self.summary.usedPercent : 100 - self.summary.usedPercent
        let lit = self.summary.hasQuota ? Int((min(100, max(0, level)) / 100 * 20).rounded()) : 0
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.summary.name.uppercased())
                        .font(RunicInstrument.narrow(14, .bold))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    InstrumentEngraved(text: "CH \(self.channel)", size: 8.5)
                }
                .frame(width: 64, alignment: .leading)
                InstrumentSegmentBar(count: 20, lit: lit, height: 7, spacing: 2) { index in
                    if self.showsUsed {
                        return RunicInstrument.levelLamp(index: index, count: 20)
                    }
                    // Reading what is left: the low end is the danger zone.
                    return RunicInstrument.levelLamp(index: 19 - index, count: 20)
                }
                .frame(maxWidth: .infinity)
                if self.summary.hasQuota {
                    InstrumentLCDText(
                        text: clipped ? "CLIP" : "\(Int(self.summary.usedPercent))%",
                        alert: clipped,
                        minWidth: 44)
                } else {
                    InstrumentLCDText(text: "----", dim: true, minWidth: 44)
                }
            }
            let byline = [
                self.summary.windowLabel,
                self.summary.resetDescription,
                self.summary.bankedResetsText,
                self.summary.topModelContext,
            ].compactMap(\.self)
            if !byline.isEmpty {
                Text(byline.joined(separator: " \u{00B7} "))
                    .font(RunicInstrument.copy(10.5))
                    .skinFace()
                    .foregroundStyle(clipped ? self.runicTheme.accent : RunicInstrument.Paint.engrave)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.leading, 74)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText(clipped: clipped))
    }

    private func accessibilityText(clipped: Bool) -> String {
        var parts = ["Channel \(self.channel), \(self.summary.name)"]
        if self.summary.hasQuota {
            parts.append(clipped
                ? "exhausted"
                : "\(Int(self.summary.usedPercent)) percent \(self.showsUsed ? "used" : "left")")
        }
        if let reset = self.summary.resetDescription { parts.append(reset) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Activity plate

/// Seven LED columns, one per day, ten segments each, scaled to the week's
/// peak; the peak day is named on the LCD and its label turns red.
struct InstrumentActivityPlate: View {
    let points: [OverviewMenuView.DailyPoint]
    let numberStyle: UsageFormatter.NumberStyle
    @Environment(\.runicTheme) private var runicTheme

    private struct Day: Identifiable {
        let id: Int
        let date: Date
        let tokens: Int
    }

    var body: some View {
        let days = self.days
        let peak = days.max(by: { $0.tokens < $1.tokens })
        let peakTokens = peak?.tokens ?? 0
        InstrumentPlate {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    InstrumentEngraved(text: "7-day activity")
                    Spacer(minLength: 8)
                    InstrumentLCDText(
                        text: self.peakReadout(peak, tokens: peakTokens),
                        size: 10,
                        dim: peakTokens == 0)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days) { day in
                        InstrumentSegmentColumn(
                            count: 10,
                            lit: peakTokens > 0 ? Int((Double(day.tokens) / Double(peakTokens) * 10).rounded()) : 0)
                    }
                }
                .frame(height: 78)
                HStack(spacing: 8) {
                    ForEach(days) { day in
                        InstrumentEngraved(
                            text: day.date.formatted(.dateTime.weekday(.abbreviated)),
                            size: 8,
                            color: day.id == peak?.id && peakTokens > 0 ? self.runicTheme.accent : nil)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText(peak: peak, tokens: peakTokens))
    }

    /// The last seven days, oldest first, every provider's tokens summed.
    private var days: [Day] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var totals: [Date: Int] = [:]
        for point in self.points {
            totals[calendar.startOfDay(for: point.date), default: 0] += point.tokens
        }
        return (0..<7).compactMap { offset -> Day? in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            return Day(id: offset, date: date, tokens: totals[date] ?? 0)
        }
    }

    private func peakReadout(_ peak: Day?, tokens: Int) -> String {
        guard let peak, tokens > 0 else { return "NO DATA" }
        let day = peak.date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        return "PEAK \(day) \(UsageFormatter.tokenCountString(tokens, style: self.numberStyle).uppercased())"
    }

    private func accessibilityText(peak: Day?, tokens: Int) -> String {
        guard let peak, tokens > 0 else { return "Seven day activity, no data" }
        let day = peak.date.formatted(.dateTime.weekday(.wide))
        return "Seven day activity, peak on \(day) at \(UsageFormatter.tokenCountString(tokens)) tokens"
    }
}
