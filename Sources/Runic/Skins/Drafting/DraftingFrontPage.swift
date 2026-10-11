import AppKit
import RunicCore
import SwiftUI

/// The overview as the general arrangement sheet: the masthead with the
/// day's average as a large dimension, every provider as a numbered hatched
/// bar with its reset as a mono callout, and the week's activity as
/// "Fig. 1" on ruled paper with a scale note.
struct DraftingFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    private let inset: CGFloat = 14

    var body: some View {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        let exhausted = self.view.summaries.count(where: { $0.hasQuota && $0.usedPercent >= 99.5 })
        VStack(alignment: .leading, spacing: 0) {
            self.masthead(average: average, exhausted: exhausted)
                .padding(.top, 10)
                .padding(.bottom, 14)
            DraftingRule(dashed: true, opacity: 0.5)

            if self.view.summaries.isEmpty {
                Text("NO ACTIVE PROVIDERS")
                    .font(RunicDrafting.mono(11))
                    .skinFace()
                    .tracking(1.2)
                    .foregroundStyle(self.runicTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, RunicSpacing.md)
            } else {
                ForEach(Array(self.view.summaries.enumerated()), id: \.element.id) { index, summary in
                    DraftingFrontRow(
                        index: index,
                        summary: summary,
                        showsUsed: self.view.showsUsed,
                        numberStyle: self.view.numberStyle)
                        .padding(.top, 18)
                }
                if let onAddRegion = self.view.onAddRegion {
                    ForEach(OverviewMenuView.brandGroups(self.view.summaries)) { group in
                        if let missing = group.missingSlot {
                            DraftingButton(title: "Add \(missing.region.displayName) account", compact: true) {
                                onAddRegion(missing)
                            }
                            .padding(.top, 10)
                            .padding(.leading, 26)
                            .accessibilityLabel("Add \(missing.region.displayName) account")
                        }
                    }
                }
            }

            if !self.view.chartPoints.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    DraftingCap(text: "Fig. 1 \u{00B7} 7-day activity")
                    Spacer(minLength: 8)
                    DraftingCap(text: "Scale \u{00B7} tokens / day", size: 9, tracking: 1)
                }
                .padding(.top, 20)
                .padding(.bottom, 6)
                self.view.activityChart
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .overlay(Rectangle().stroke(self.runicTheme.primary.opacity(0.6), lineWidth: 1))
            }
        }
        .skinFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(.horizontal, self.inset)
        .padding(.bottom, 14)
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
        .overlay(DraftingCropMarks(inset: 4))
    }

    // MARK: Masthead

    private func masthead(average: Double?, exhausted: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                DraftingCap(text: "General arrangement")
                Text("ALL PROVIDERS")
                    .font(RunicDrafting.title(26))
                    .skinFace()
                    .tracking(-0.3)
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text(self.statusLine(exhausted: exhausted))
                    .font(RunicDrafting.mono(10.5))
                    .skinFace()
                    .foregroundStyle(exhausted > 0 ? self.runicTheme.warm : self.runicTheme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                DraftingCap(text: "Avg \(self.view.showsUsed ? "used" : "left") today")
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(average.map { "\(Int($0.rounded()))" } ?? "\u{2014}")
                        .font(RunicDrafting.numeral(34))
                        .skinFace()
                        .tracking(-1)
                    if average != nil {
                        Text("%")
                            .font(RunicDrafting.mono(16, .medium))
                            .skinFace()
                    }
                }
                .foregroundStyle(self.runicTheme.primaryText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(self.view.averagePercentText)
        }
    }

    /// "2 OF 2 ACTIVE · 1 EXHAUSTED · 1.2M TODAY".
    private func statusLine(exhausted: Int) -> String {
        var parts = ["\(self.view.summaries.count) OF \(self.view.totalProviders) ACTIVE"]
        if exhausted > 0 { parts.append("\(exhausted) EXHAUSTED") }
        if self.view.totalTodayTokens > 0 {
            let tokens = UsageFormatter.tokenCountString(self.view.totalTodayTokens, style: self.view.numberStyle)
            parts.append("\(tokens.uppercased()) TODAY")
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}

// MARK: - Provider row

/// One provider on the sheet: the callout number, the name, the window as
/// a cap, the reset and context as a mono callout, then the hatched bar
/// with its percent dimension to the right.
struct DraftingFrontRow: View {
    let index: Int
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                DraftingCallout(number: self.index + 1)
                Text(self.summary.name)
                    .font(RunicDrafting.strong(13))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .layoutPriority(1)
                if let window = self.summary.windowLabel, !window.isEmpty {
                    DraftingCap(text: "\u{00B7} \(window)")
                }
                Spacer(minLength: 6)
                if let callout = self.callout {
                    Text(callout)
                        .font(RunicDrafting.mono(10.5))
                        .skinFace()
                        .foregroundStyle(self.isExhausted ? self.runicTheme.warm : self.runicTheme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            if self.summary.hasQuota {
                HStack(spacing: 10) {
                    DraftingHatchBar(
                        percent: self.summary.usedPercent,
                        accessibilityLabel: "\(self.summary.name) \(self.showsUsed ? "used" : "remaining")",
                        height: 14,
                        isWarm: self.isExhausted)
                    Text("\(Int(self.summary.usedPercent.rounded()))%")
                        .font(RunicDrafting.numeral(15))
                        .skinFace()
                        .foregroundStyle(self.isExhausted ? self.runicTheme.warm : self.runicTheme.primaryText)
                        .frame(width: 52, alignment: .trailing)
                        .accessibilityHidden(true)
                }
            } else {
                Text(self.summary.resetDescription ?? "NO QUOTA WINDOW")
                    .font(RunicDrafting.mono(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondary)
                    .lineLimit(1)
                    .padding(.leading, 26)
            }
        }
    }

    /// "RESET 2h 14m · CTX ~272K", or "EXHAUSTED · RESET 18m" in red.
    private var callout: String? {
        var parts: [String] = []
        if self.isExhausted { parts.append("EXHAUSTED") }
        if let reset = self.summary.resetDescription, !reset.isEmpty {
            parts.append(RunicDrafting.resetCallout(reset))
        }
        if let banked = self.summary.bankedResetsText, !banked.isEmpty {
            parts.append(banked.uppercased())
        }
        if let context = self.summary.topModelContext, !context.isEmpty, parts.count < 2 {
            parts.append(context.uppercased())
        }
        if self.summary.todayTokens > 0, parts.count < 2 {
            parts.append(UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle)
                .uppercased() + " TODAY")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private var isExhausted: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent >= 99.5 : self.summary.usedPercent <= 0.5
    }
}
