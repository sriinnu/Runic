import AppKit
import RunicCore
import SwiftUI

// MARK: - Atelier Overview

/// Architectural studio overview: dot-grid Quota Skyline elevation at top,
/// 3-cell architectural stat strip (`EXHAUSTED | BANKED | ACTIVE`), and ONE
/// unified `0px` provider specification ledger divided by `1px` hairline rules.
struct AtelierFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let groups = OverviewMenuView.brandGroups(self.view.summaries)
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        let averageUsed = average.map { self.view.showsUsed ? $0 : 100 - $0 }
        let exhausted = self.view.summaries.count(where: { summary in
            guard summary.hasQuota else { return false }
            return self.view.showsUsed ? summary.usedPercent >= 99.5 : summary.usedPercent <= 0.5
        })
        let banked = self.view.summaries.count(where: { $0.bankedResetsText != nil })

        VStack(alignment: .leading, spacing: 0) {
            self.skylineHero(
                average: average,
                averageUsed: averageUsed,
                exhausted: exhausted,
                banked: banked)

            AtelierHairline()

            AtelierStatStrip(cells: [
                AtelierStatStrip.Cell(
                    label: "Exhausted",
                    value: "\(exhausted)",
                    accentColor: exhausted > 0 ? self.runicTheme.warm : nil),
                AtelierStatStrip.Cell(label: "Banked", value: "\(banked)"),
                AtelierStatStrip.Cell(
                    label: "Active",
                    value: "\(self.view.summaries.count)/\(self.view.totalProviders)"),
            ])

            AtelierHairline()

            if groups.isEmpty {
                Text("No active providers.")
                    .font(RunicAtelier.sans(12))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(16)
                    .background(self.runicTheme.cardFill)
            } else {
                self.providerLedger(groups: groups)
            }

            if !self.view.chartPoints.isEmpty {
                AtelierHairline()
                self.cadenceBand
            }
        }
        .skinFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Quota Skyline Hero

    private func skylineHero(
        average: Double?,
        averageUsed: Double?,
        exhausted _: Int,
        banked _: Int) -> some View
    {
        AtelierQuotaSkyline(
            summaries: self.view.summaries,
            showsUsed: self.view.showsUsed,
            average: average,
            averageUsed: averageUsed,
            onSelect: self.view.onSelectProvider)
            .padding(RunicAtelier.panelInset)
            .background(AtelierDotGridPaper())
    }

    // MARK: Numbered Provider Specification Ledger

    private func providerLedger(groups: [OverviewMenuView.BrandGroup]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                AtelierKicker(text: "Providers")
                Spacer(minLength: 6)
                Text(String(format: "01 \u{2014} %02d", groups.count))
                    .font(RunicAtelier.mono(9.5, .medium))
                    .skinFace()
                    .tracking(0.6)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            .padding(.horizontal, RunicAtelier.panelInset)
            .padding(.vertical, 8)
            .background(self.runicTheme.surfaceAlt.opacity(0.6))

            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                AtelierHairline()
                if group.isStacked {
                    AtelierBrandLedgerGroup(
                        index: index + 1,
                        group: group,
                        showsUsed: self.view.showsUsed,
                        numberStyle: self.view.numberStyle,
                        onAddRegion: self.view.onAddRegion,
                        onSelect: self.view.onSelectProvider)
                } else if let summary = group.rows.first {
                    AtelierProviderLedgerRow(
                        index: index + 1,
                        summary: summary,
                        showsUsed: self.view.showsUsed,
                        numberStyle: self.view.numberStyle,
                        onSelect: self.view.onSelectProvider)
                }
            }
        }
        .background(self.runicTheme.cardFill)
    }

    // MARK: 7-Day Cadence Sheet

    private var cadenceBand: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                AtelierKicker(text: "7-day cadence")
                Spacer(minLength: 8)
                if self.view.totalTodayTokens > 0 {
                    let tokens = UsageFormatter.tokenCountString(
                        self.view.totalTodayTokens,
                        style: self.view.numberStyle)
                    Text("\(tokens) TODAY")
                        .font(RunicAtelier.mono(9.5, .medium))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
            }
            self.view.activityChart
                .padding(8)
                .background(self.runicTheme.cardFill)
                .overlay(Rectangle().strokeBorder(self.runicTheme.cardStroke, lineWidth: 1))
                .overlay(AtelierCornerReticles())
        }
        .padding(RunicAtelier.panelInset)
        .background(AtelierDotGridPaper())
    }
}

// MARK: - Ledger Row & Regional Brand Stack

private struct AtelierProviderLedgerRow: View {
    let index: Int
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    var onSelect: ((UsageProvider) -> Void)?
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let code = String(format: "%02d", self.index)
        HStack(alignment: .top, spacing: 8) {
            Text(code)
                .font(RunicAtelier.mono(10.5, .semibold))
                .skinFace()
                .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.secondaryText)
                .frame(width: 20, alignment: .leading)
                .padding(.top, 2)

            if let icon = self.summary.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(self.summary.name)
                        .font(RunicAtelier.sans(12.5, .medium))
                        .skinFace()
                        .foregroundStyle(self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText)
                        .lineLimit(1)
                        .layoutPriority(1)
                    if let plan = self.summary.planBadge {
                        AtelierPillBadge(text: plan.uppercased(), tone: .neutral)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    Spacer(minLength: 6)
                    if self.summary.todayTokens > 0 {
                        Text(UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle))
                            .font(RunicAtelier.mono(9.5))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }
                    Text(self.summary.hasQuota ? "\(Int(self.summary.usedPercent.rounded()))%" : "\u{2014}")
                        .font(RunicAtelier.mono(13, .semibold))
                        .skinFace()
                        .foregroundStyle(self.percentColor)
                }

                if self.summary.hasQuota {
                    let direction = self.showsUsed ? "usage used" : "usage remaining"
                    AtelierGauge(
                        percent: self.summary.usedPercent,
                        tint: self.barTint,
                        accessibilityLabel: "\(self.summary.name), \(direction)")
                }

                let byline = [
                    self.summary.windowLabel,
                    self.summary.resetDescription,
                    self.summary.topModelContext,
                ].compactMap(\.self).filter { !$0.isEmpty }
                if !byline.isEmpty || self.summary.bankedResetsText != nil {
                    HStack(spacing: 6) {
                        if !byline.isEmpty {
                            Text(byline.joined(separator: " \u{00B7} "))
                                .font(RunicAtelier.mono(9.5))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 0)
                        if let banked = self.summary.bankedResetsText {
                            AtelierPillBadge(text: banked.uppercased(), tone: .good)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 9)
        .background(self.isHovered ? self.runicTheme.surfaceAlt.opacity(0.65) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .onTapGesture {
            self.onSelect?(self.summary.provider)
        }
        .accessibilityElement(children: .combine)
    }

    private var isExhausted: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent >= 99.5 : self.summary.usedPercent <= 0.5
    }

    private var isElevated: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent > 80 : self.summary.usedPercent < 20
    }

    private var percentColor: Color {
        if self.isExhausted { return self.runicTheme.warm }
        if self.isElevated { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }

    private var barTint: Color {
        if self.isExhausted { return self.runicTheme.warm }
        if self.isElevated { return self.runicTheme.highlight }
        if self.isHovered { return self.runicTheme.accent }
        return self.runicTheme.primary
    }
}

private struct AtelierBrandLedgerGroup: View {
    let index: Int
    let group: OverviewMenuView.BrandGroup
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    let onAddRegion: ((UsageProvider) -> Void)?
    var onSelect: ((UsageProvider) -> Void)?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let brandName = UsageProvider.compactDisplayName(self.group.rows.first?.name ?? self.group.root.rawValue)
        let code = String(format: "%02d", self.index)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(code)
                    .font(RunicAtelier.mono(10.5, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(width: 20, alignment: .leading)
                if let icon = self.group.rows.first?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .accessibilityHidden(true)
                }
                Text(brandName)
                    .font(RunicAtelier.sans(12.5, .medium))
                    .skinFace()
                    .lineLimit(1)
                Spacer(minLength: 6)
                AtelierKicker(
                    text: self.group.rows.count == 2 ? "2 regions" : "1 of 2 regions",
                    parenthesized: false)
            }
            ForEach(self.group.rows) { summary in
                AtelierRegionQuotaSubRow(
                    summary: summary,
                    showsUsed: self.showsUsed,
                    numberStyle: self.numberStyle,
                    onSelect: self.onSelect)
                    .padding(.leading, 28)
            }
            if let missing = self.group.missingSlot, let onAddRegion = self.onAddRegion {
                HStack {
                    AtelierButton(
                        title: "Add \(brandName) (\(missing.region.displayName))",
                        arrow: "\u{2192}",
                        action: { onAddRegion(missing) })
                        .padding(.leading, 28)
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, RunicAtelier.panelInset)
        .padding(.vertical, 9)
    }
}

private struct AtelierRegionQuotaSubRow: View {
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    var onSelect: ((UsageProvider) -> Void)?
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(self.summary.region == .china ? "CN" : "INTL")
                    .font(RunicAtelier.mono(8.5, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(self.runicTheme.surfaceAlt)
                    .overlay(Rectangle().strokeBorder(self.runicTheme.cardStroke, lineWidth: 0.75))
                if let plan = self.summary.planBadge {
                    AtelierPillBadge(text: plan.uppercased(), tone: .neutral)
                }
                if self.summary.todayTokens > 0 {
                    Text(UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle))
                        .font(RunicAtelier.mono(9.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
                Spacer(minLength: 4)
                Text(self.summary.hasQuota ? "\(Int(self.summary.usedPercent.rounded()))%" : "\u{2014}")
                    .font(RunicAtelier.mono(12.5, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
            }
            if self.summary.hasQuota {
                AtelierGauge(
                    percent: self.summary.usedPercent,
                    tint: self.isHovered ? self.runicTheme.accent : self.runicTheme.primary,
                    accessibilityLabel: "\(self.summary.name) usage")
            }
            let byline = [
                self.summary.windowLabel,
                self.summary.resetDescription,
                self.summary.topModelContext,
            ].compactMap(\.self).filter { !$0.isEmpty }
            if !byline.isEmpty {
                Text(byline.joined(separator: " \u{00B7} "))
                    .font(RunicAtelier.mono(9.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onHover { self.isHovered = $0 }
        .onTapGesture { self.onSelect?(self.summary.provider) }
    }
}
