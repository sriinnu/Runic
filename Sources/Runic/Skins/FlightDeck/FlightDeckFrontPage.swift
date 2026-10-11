import AppKit
import RunicCore
import SwiftUI

/// The overview as a navigation display: annunciators across the top, the
/// day's average as a large cyan readout, one horizontal tape per provider
/// with its callsign, and the week's activity framed as a weather radar.
struct FlightDeckFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        VStack(alignment: .leading, spacing: 10) {
            self.annunciators
            self.readout(average: average)

            if self.view.summaries.isEmpty {
                Text("NO ACTIVE PROVIDERS")
                    .font(RunicFlightDeck.mono(11))
                    .skinFace()
                    .foregroundStyle(RunicFlightDeck.dim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, RunicSpacing.md)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(self.view.summaries) { summary in
                        FlightDeckProviderTapeRow(
                            summary: summary,
                            showsUsed: self.view.showsUsed,
                            numberStyle: self.view.numberStyle)
                    }
                }
                if let onAddRegion = self.view.onAddRegion {
                    ForEach(OverviewMenuView.brandGroups(self.view.summaries)) { group in
                        if let missing = group.missingSlot {
                            FlightDeckButton(title: "Add \(missing.region.displayName) account") {
                                onAddRegion(missing)
                            }
                            .accessibilityLabel("Add \(missing.region.displayName) account")
                        }
                    }
                }
            }

            if !self.view.chartPoints.isEmpty {
                self.radar
            }
        }
        .skinFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Annunciators

    private var annunciators: some View {
        let exhausted = self.view.summaries.filter { $0.hasQuota && $0.usedPercent >= 99.5 }
        let held = self.view.summaries.filter { $0.bankedResetsText != nil }
        return FlightDeckWrap(spacing: 5) {
            if !exhausted.isEmpty {
                FlightDeckTag(text: "MASTER CAUT", tone: .caution)
            }
            FlightDeckTag(
                text: "LINK \(self.view.summaries.count)/\(self.view.totalProviders)",
                tone: self.view.summaries.isEmpty ? .off : .cyan)
            ForEach(exhausted) { summary in
                FlightDeckTag(text: "\(RunicFlightDeck.callsign(summary.name)) EXH", tone: .magenta)
            }
            ForEach(held) { summary in
                FlightDeckTag(text: "\(RunicFlightDeck.callsign(summary.name)) HELD", tone: .amber)
            }
            if self.view.totalTodayTokens > 0 {
                let tokens = UsageFormatter.tokenCountString(self.view.totalTodayTokens, style: self.view.numberStyle)
                FlightDeckTag(text: "\(tokens) TKN", tone: .cyan)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Annunciators")
    }

    // MARK: Readout

    private func readout(average: Double?) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            FlightDeckLabel(text: "AVG", size: 10)
            Text(average.map { "\(Int($0.rounded()))" } ?? "----")
                .font(RunicFlightDeck.mono(38, .bold))
                .skinFace()
                .foregroundStyle(average == nil ? RunicFlightDeck.dim : self.runicTheme.accent)
                .lineLimit(1)
            FlightDeckLabel(text: "% \(self.view.showsUsed ? "used" : "left")", size: 10)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                FlightDeckLabel(text: "\(self.view.summaries.count) of \(self.view.totalProviders) active", size: 9)
                FlightDeckLabel(
                    text: "ND \u{00B7} nav display",
                    size: 9,
                    color: self.runicTheme.secondaryText.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlay(Rectangle().stroke(self.runicTheme.cardStroke, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.view.averagePercentText)
    }

    // MARK: Radar

    private var radar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                FlightDeckLabel(text: "WX \u{00B7} 7-day activity")
                Spacer()
                HStack(spacing: 4) {
                    ForEach(self.view.chartLegendEntries.prefix(5), id: \.name) { entry in
                        Rectangle()
                            .fill(entry.color)
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
            self.view.activityChart
        }
        .padding(8)
        .background(Rectangle().fill(self.runicTheme.surfaceAlt))
        .overlay(Rectangle().stroke(self.runicTheme.cardStroke, lineWidth: 1))
        .overlay(alignment: .topLeading) { self.cornerTick }
        .overlay(alignment: .topTrailing) { self.cornerTick.rotationEffect(.degrees(90)) }
        .overlay(alignment: .bottomTrailing) { self.cornerTick.rotationEffect(.degrees(180)) }
        .overlay(alignment: .bottomLeading) { self.cornerTick.rotationEffect(.degrees(270)) }
    }

    private var cornerTick: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 8))
            path.addLine(to: .zero)
            path.addLine(to: CGPoint(x: 8, y: 0))
        }
        .stroke(self.runicTheme.accent, lineWidth: 1.5)
        .frame(width: 8, height: 8)
        .padding(2)
        .accessibilityHidden(true)
    }
}

/// One provider on the navigation display: its mark and callsign on the
/// left, the horizontal tape in the brand colour, the window and reset as
/// a mono byline.
struct FlightDeckProviderTapeRow: View {
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if let icon = self.summary.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                    }
                    Text(RunicFlightDeck.callsign(self.summary.name))
                        .font(RunicFlightDeck.sans(11, .bold))
                        .skinFace()
                        .tracking(0.6)
                        .foregroundStyle(self.isExhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if let byline = self.byline {
                    Text(byline)
                        .font(RunicFlightDeck.mono(8))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: 92, alignment: .leading)
            FlightDeckHorizontalTape(
                percent: self.summary.hasQuota ? self.summary.usedPercent : nil,
                showsUsed: self.showsUsed,
                tint: self.isExhausted ? self.runicTheme.warm : self.summary.brandColor,
                accessibilityLabel: "\(self.summary.name), \(self.showsUsed ? "usage used" : "usage remaining")")
        }
    }

    private var byline: String? {
        let parts = [
            self.summary.windowLabel,
            self.summary.resetDescription,
            self.summary.bankedResetsText,
            self.summary.topModelContext,
            self.summary.todayTokens > 0
                ? UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle)
                : nil,
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ").uppercased()
    }

    private var isExhausted: Bool {
        self.summary.hasQuota && (self.showsUsed ? self.summary.usedPercent >= 99.5 : self.summary.usedPercent <= 0.5)
    }
}
