import AppKit
import RunicCore
import SwiftUI

/// The overview as the instrument's master face: the day's average as a
/// large tabular readout over a full trough gauge, every provider as a
/// module with its mark on a keycap, a slim trough in its brand colour and
/// a byline, the region offers as keys, and the week's activity in a
/// recessed well.
struct ReliefFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        VStack(alignment: .leading, spacing: 0) {
            self.hero(average: average)
                .padding(.top, 14)
                .padding(.bottom, 14)

            ReliefGroove()

            if self.view.summaries.isEmpty {
                Text("No active providers.")
                    .font(RunicRelief.face(12))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, RunicSpacing.md)
            } else {
                ForEach(Array(self.view.summaries.enumerated()), id: \.element.id) { index, summary in
                    ReliefProviderRow(
                        summary: summary,
                        showsUsed: self.view.showsUsed,
                        numberStyle: self.view.numberStyle)
                        .padding(.vertical, 12)
                    if index < self.view.summaries.count - 1 {
                        ReliefGroove()
                    }
                }
                self.regionOffers
            }

            if !self.view.chartPoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 6) {
                        ReliefLabel(text: "7-day activity")
                        Spacer(minLength: 8)
                        HStack(spacing: 5) {
                            ForEach(self.view.chartLegendEntries.prefix(5), id: \.name) { entry in
                                ReliefLED(color: entry.color, size: 7)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                    self.view.activityChart
                        .padding(8)
                        .reliefWell(radius: 9, depth: 0.7)
                }
                .padding(.top, 14)
            }
        }
        .skinFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Hero

    private func hero(average: Double?) -> some View {
        let exhausted = self.view.summaries.count(where: { Self.isExhausted($0, showsUsed: self.view.showsUsed) })
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    ReliefLabel(text: "Average \u{00B7} \(self.view.showsUsed ? "used" : "left")")
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(average.map { "\(Int($0.rounded()))" } ?? "\u{2014}")
                            .font(RunicRelief.numeral(44, .medium))
                            .skinFace()
                            .tracking(-1)
                            .foregroundStyle(self.runicTheme.primaryText)
                        if average != nil {
                            Text("%")
                                .font(RunicRelief.face(22, .medium))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.primaryText)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(self.view.averagePercentText)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 5) {
                        ReliefLED(
                            color: RunicRelief.ledGreen,
                            isLit: !self.view.summaries.isEmpty,
                            size: 6)
                        Text("\(self.view.summaries.count) of \(self.view.totalProviders) active")
                            .font(RunicRelief.face(11, .medium))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }
                    if exhausted > 0 {
                        HStack(spacing: 5) {
                            ReliefLED(color: RunicRelief.ledRed, size: 6)
                            Text(exhausted == 1 ? "1 exhausted" : "\(exhausted) exhausted")
                                .font(RunicRelief.face(11, .semibold))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.warm)
                        }
                    }
                    if self.view.totalTodayTokens > 0 {
                        let tokens = UsageFormatter.tokenCountString(
                            self.view.totalTodayTokens,
                            style: self.view.numberStyle)
                        ReliefCapsule(text: "\(tokens) today")
                    }
                }
                .lineLimit(1)
            }
            if let average {
                ReliefGauge(
                    percent: average,
                    accessibilityLabel: self.view.showsUsed ? "Average used" : "Average remaining",
                    nib: RunicRelief.signal)
            }
        }
    }

    // MARK: Region offers

    @ViewBuilder
    private var regionOffers: some View {
        if let onAddRegion = self.view.onAddRegion {
            let missing = OverviewMenuView.brandGroups(self.view.summaries).compactMap(\.missingSlot)
            if !missing.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(missing, id: \.rawValue) { slot in
                        let label = OverviewMenuView.addRegionLabel(for: slot)
                        ReliefOfferKey(title: label) { onAddRegion(slot) }
                            .accessibilityLabel(label)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
        }
    }

    static func isExhausted(_ summary: OverviewMenuView.ProviderSummary, showsUsed: Bool) -> Bool {
        summary.hasQuota && (showsUsed ? summary.usedPercent >= 99.5 : summary.usedPercent <= 0.5)
    }
}

/// A full-width keycap offering to add the other region. The title wraps
/// rather than clipping.
private struct ReliefOfferKey: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(self.runicTheme.accent)
                Text(self.title)
                    .font(RunicRelief.face(11.5, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReliefKeycapBackground(isPressed: false, isHovered: self.isHovered))
            .contentShape(RoundedRectangle(cornerRadius: RunicRelief.keyRadius, style: .continuous))
        }
        .buttonStyle(ReliefPressStyle())
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

/// One provider on the master face: its mark on a keycap, the name and a
/// tabular readout on one line, a slim trough tinted in the brand colour,
/// and the window, reset and banked resets as a byline.
struct ReliefProviderRow: View {
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                ReliefKeycapBackground(isPressed: false, radius: 7)
                if let icon = self.summary.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                } else {
                    Text(String(self.summary.name.prefix(1)).uppercased())
                        .font(RunicRelief.face(12, .bold))
                        .skinFace()
                        .foregroundStyle(self.summary.brandColor)
                }
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(self.summary.name)
                        .font(RunicRelief.face(13.5, .semibold))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .layoutPriority(1)
                    if let plan = self.summary.planBadge {
                        Text(plan.uppercased())
                            .font(RunicRelief.label(8.5))
                            .skinFace()
                            .tracking(0.6)
                            .foregroundStyle(OverviewMenuView.isElevatedPlanBadge(plan)
                                ? self.runicTheme.accent
                                : self.runicTheme.secondaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ReliefKeycapBackground(isPressed: false, radius: 5))
                    }
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(self.summary.hasQuota ? "\(Int(self.summary.usedPercent.rounded()))" : "\u{2014}")
                            .font(RunicRelief.numeral(19, .medium))
                            .skinFace()
                            .foregroundStyle(self.isExhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                        if self.summary.hasQuota {
                            Text("%")
                                .font(RunicRelief.face(11, .medium))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }
                    }
                }
                if self.summary.hasQuota {
                    ReliefGauge(
                        percent: self.summary.usedPercent,
                        accessibilityLabel:
                        "\(self.summary.name), \(self.showsUsed ? "usage used" : "usage remaining")",
                        nib: self.isExhausted ? RunicRelief.ledRed : RunicRelief.signal,
                        fillTint: self.summary.brandColor,
                        troughHeight: 9,
                        showsScale: false)
                }
                if let byline = self.byline {
                    Text(byline)
                        .font(RunicRelief.face(10.5))
                        .skinFace()
                        .foregroundStyle(self.isExhausted ? self.runicTheme.warm : self.runicTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var byline: String? {
        let parts = [
            self.summary.windowLabel,
            self.summary.resetDescription,
            self.summary.bankedResetsText,
            self.summary.topModelContext,
            self.summary.todayTokens > 0
                ? UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle) + " today"
                : nil,
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private var isExhausted: Bool {
        ReliefFrontPage.isExhausted(self.summary, showsUsed: self.showsUsed)
    }
}
