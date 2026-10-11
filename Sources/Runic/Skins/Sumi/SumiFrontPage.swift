import AppKit
import RunicCore
import SwiftUI

/// The overview as the front of the scroll: the day's average inside an
/// ensō with a one-line read beside it, every provider under its seal with
/// a Mincho numeral and a brush gauge, and the week's activity last.
struct SumiFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        let exhausted = self.view.summaries.count(where: { $0.hasQuota && $0.usedPercent >= 99.5 })
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    SumiEnso(percent: average, size: 124)
                    VStack(spacing: 4) {
                        Text(average.map { "\(Int($0.rounded()))" } ?? "\u{2014}")
                            .font(RunicSumi.numeral(38))
                            .skinFace()
                            .tracking(-1.2)
                            .foregroundStyle(self.runicTheme.primaryText)
                        SumiLabel(text: "% \(self.view.showsUsed ? "used" : "left")", size: 9)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(self.view.averagePercentText)
                VStack(alignment: .leading, spacing: 6) {
                    SumiLabel(text: "Today")
                    Text(RunicSumi.headline(forAverage: average.map { self.view.showsUsed ? $0 : 100 - $0 }))
                        .font(RunicSumi.headline(24))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    VStack(alignment: .leading, spacing: 2) {
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
                    .font(RunicSumi.copy(12))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .padding(.bottom, 14)

            SumiRule()

            if self.view.summaries.isEmpty {
                Text("No active providers.")
                    .font(RunicSumi.copy(12.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, RunicSpacing.md)
            } else {
                ForEach(self.view.summaries) { summary in
                    SumiProviderRow(
                        summary: summary,
                        showsUsed: self.view.showsUsed,
                        numberStyle: self.view.numberStyle)
                        .padding(.top, 16)
                }
                if let onAddRegion = self.view.onAddRegion {
                    ForEach(OverviewMenuView.brandGroups(self.view.summaries)) { group in
                        if let missing = group.missingSlot {
                            Button {
                                onAddRegion(missing)
                            } label: {
                                Text("Add \(missing.region.displayName) account \u{2192}")
                                    .font(RunicSumi.strong(11.5))
                                    .skinFace()
                                    .foregroundStyle(self.runicTheme.accent)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 10)
                            .padding(.leading, 44)
                            .accessibilityLabel("Add \(missing.region.displayName) account")
                        }
                    }
                }
            }

            if !self.view.chartPoints.isEmpty {
                SumiRule()
                    .padding(.top, 16)
                HStack(alignment: .center) {
                    SumiLabel(text: "7-day activity")
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(self.view.chartLegendEntries.prefix(5), id: \.name) { entry in
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(entry.color)
                                .frame(width: 7, height: 7)
                                .rotationEffect(.degrees(-3))
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
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
    }
}

/// One provider on the front: its seal, the name and numeral on one line,
/// the brush gauge in the brand colour, the window and reset as a byline.
struct SumiProviderRow: View {
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SumiSeal(
                text: RunicSumi.initial(for: self.summary.name),
                color: self.summary.brandColor,
                size: 30,
                image: self.summary.icon)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(self.summary.name)
                        .font(RunicSumi.headline(20))
                        .skinFace()
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(self.summary.hasQuota ? "\(Int(self.summary.usedPercent))" : "\u{2014}")
                            .font(RunicSumi.numeral(22))
                            .skinFace()
                            .foregroundStyle(self.emphasizesPercent ? self.runicTheme.accent : self.runicTheme
                                .primaryText)
                        if self.summary.hasQuota {
                            Text("%")
                                .font(RunicSumi.copy(11))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }
                    }
                }
                if self.summary.hasQuota {
                    SumiBrushBar(
                        percent: self.summary.usedPercent,
                        tint: self.emphasizesPercent ? self.runicTheme.accent : self.summary.brandColor,
                        accessibilityLabel: self.showsUsed ? "Usage used" : "Usage remaining",
                        height: 12)
                }
                let byline = [
                    self.summary.windowLabel,
                    self.summary.resetDescription,
                    self.summary.bankedResetsText,
                    self.summary.topModelContext,
                    self.summary.todayTokens > 0
                        ? UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle) + " today"
                        : nil,
                ].compactMap(\.self)
                if !byline.isEmpty {
                    Text(byline.joined(separator: " \u{00B7} "))
                        .font(RunicSumi.copy(11.5))
                        .skinFace()
                        .foregroundStyle(self.emphasizesPercent ? self.runicTheme.accent : self.runicTheme
                            .secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    private var emphasizesPercent: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent > 80 : self.summary.usedPercent < 20
    }
}
