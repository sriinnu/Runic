import AppKit
import RunicCore
import SwiftUI

// MARK: - Meridian Overview

/// Fleet chronometer overview: master power-reserve arc dial on the left,
/// fleet status beside it, every provider set into its own dial plate with
/// brand medallion, plan jewel plaque, railway-track gauge, and tabular readout,
/// and the 7-day cadence chart framed at the bottom.
struct MeridianFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            self.hero

            if self.view.summaries.isEmpty {
                MeridianDialPlate(padding: 14) {
                    Text("No active providers.")
                        .font(RunicMeridian.body(12))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                MeridianSectionTitle(
                    title: "Calibers",
                    systemImage: "circle.grid.2x2",
                    trailing: "\(self.view.summaries.count) of \(self.view.totalProviders) active")
                    .padding(.top, 2)
                ForEach(OverviewMenuView.brandGroups(self.view.summaries)) { group in
                    if group.isStacked {
                        MeridianBrandStack(
                            group: group,
                            showsUsed: self.view.showsUsed,
                            numberStyle: self.view.numberStyle,
                            onAddRegion: self.view.onAddRegion)
                    } else if let summary = group.rows.first {
                        MeridianDialPlate(padding: 10) {
                            MeridianProviderRow(
                                summary: summary,
                                showsUsed: self.view.showsUsed,
                                numberStyle: self.view.numberStyle)
                        }
                    }
                }
            }

            if !self.view.chartPoints.isEmpty {
                HStack(alignment: .center) {
                    MeridianSectionTitle(title: "7-day cadence", systemImage: "chart.bar.fill")
                    HStack(spacing: 4) {
                        ForEach(self.view.chartLegendEntries.prefix(5), id: \.name) { entry in
                            Capsule(style: .continuous)
                                .fill(entry.color)
                                .frame(width: 10, height: 4)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .padding(.top, 2)
                MeridianDialPlate(padding: 10) {
                    self.view.activityChart
                }
            }
        }
        .skinFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(RunicMeridian.panelInset)
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Master Chronometer Hero

    private var hero: some View {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        let averageUsed = average.map { self.view.showsUsed ? $0 : 100 - $0 }
        let exhausted = self.view.summaries.count(where: { summary in
            guard summary.hasQuota else { return false }
            return self.view.showsUsed ? summary.usedPercent >= 99.5 : summary.usedPercent <= 0.5
        })
        let banked = self.view.summaries.count(where: { $0.bankedResetsText != nil })
        return MeridianDialPlate(padding: 12) {
            HStack(alignment: .center, spacing: 14) {
                MeridianPowerReserveArc(
                    percent: average ?? 0,
                    usedPercent: averageUsed ?? 0,
                    isUsedMode: self.view.showsUsed,
                    caption: self.view.showsUsed ? "avg used" : "reserve",
                    accessibilityLabel: self.view.averagePercentText,
                    diameter: 122)
                    .frame(width: 122)

                VStack(alignment: .leading, spacing: 6) {
                    MeridianLabel(text: "Master reserve")
                    Text(RunicMeridian.headline(forUsed: averageUsed))
                        .font(RunicMeridian.display(17, weight: .semibold))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    if self.view.totalTodayTokens > 0 {
                        let tokens = UsageFormatter.tokenCountString(
                            self.view.totalTodayTokens,
                            style: self.view.numberStyle)
                        Text("\(tokens) tokens today")
                            .font(RunicMeridian.mono(11))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                    }
                    HStack(spacing: 5) {
                        if exhausted > 0 {
                            MeridianJewelPill(
                                text: exhausted == 1 ? "1 EXHAUSTED" : "\(exhausted) EXHAUSTED",
                                jewel: true,
                                tone: .critical)
                        }
                        if banked > 0 {
                            MeridianJewelPill(
                                text: banked == 1 ? "1 BANKED" : "\(banked) BANKED",
                                jewel: true,
                                tone: .good)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Brand Stack

private struct MeridianBrandStack: View {
    let group: OverviewMenuView.BrandGroup
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    let onAddRegion: ((UsageProvider) -> Void)?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        MeridianDialPlate(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    MeridianBrandMedallion(
                        image: self.group.rows.first?.icon,
                        name: self.brandName,
                        tint: self.group.rows.first?.brandColor ?? self.runicTheme.accent,
                        size: 22)
                    Text(self.brandName)
                        .font(RunicMeridian.body(12.5, .semibold))
                        .skinFace()
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    MeridianLabel(text: self.group.rows.count == 2 ? "2 REGIONS" : "1 OF 2 REGIONS")
                }
                ForEach(self.group.rows) { summary in
                    MeridianHairline()
                    MeridianProviderRow(
                        summary: summary,
                        showsUsed: self.showsUsed,
                        numberStyle: self.numberStyle,
                        regionTag: summary.region == .china ? "CN" : "INTL")
                }
                if let missing = self.group.missingSlot, let onAddRegion = self.onAddRegion {
                    let label = OverviewMenuView.addRegionLabel(for: missing)
                    MeridianButton(title: label, systemImage: "plus") {
                        onAddRegion(missing)
                    }
                    .accessibilityLabel(label)
                }
            }
        }
    }

    private var brandName: String {
        let name = self.group.rows.first(where: { $0.region == .international })?.name
            ?? self.group.rows.first?.name ?? ""
        return name.hasSuffix(" CN") ? String(name.dropLast(3)) : name
    }
}

// MARK: - Provider Row

private struct MeridianProviderRow: View {
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    var regionTag: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let regionTag {
                Text(regionTag)
                    .font(RunicMeridian.mono(9, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(width: 30, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(self.runicTheme.primaryText.opacity(0.06)))
                    .padding(.top, 2)
            } else {
                MeridianBrandMedallion(
                    image: self.summary.icon,
                    name: self.summary.name,
                    tint: self.summary.brandColor,
                    size: 28)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(self.summary.name)
                        .font(RunicMeridian.body(13, .semibold))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .layoutPriority(1)
                    if let plan = self.summary.planBadge {
                        let elevated = OverviewMenuView.isElevatedPlanBadge(plan)
                        MeridianJewelPill(
                            text: plan.uppercased(),
                            jewel: elevated,
                            tone: elevated ? .accent : .neutral)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    Spacer(minLength: 6)
                    if self.summary.todayTokens > 0 {
                        Text(UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle))
                            .font(RunicMeridian.mono(10))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(self.summary.hasQuota ? "\(Int(self.summary.usedPercent.rounded()))" : "\u{2014}")
                            .font(RunicMeridian.mono(16, .semibold))
                            .skinFace()
                            .foregroundStyle(self.percentColor)
                        if self.summary.hasQuota {
                            Text("%")
                                .font(RunicMeridian.mono(10.5))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }
                    }
                }

                if self.summary.hasQuota {
                    let direction = self.showsUsed ? "usage used" : "usage remaining"
                    MeridianRailwayGauge(
                        percent: self.summary.usedPercent,
                        tint: self.barTint,
                        accessibilityLabel: "\(self.summary.name), \(direction)",
                        height: 8)
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
                                .font(RunicMeridian.body(10.5))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 0)
                        if let banked = self.summary.bankedResetsText {
                            MeridianJewelPill(text: banked.uppercased(), jewel: true, tone: .good)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emphasizes: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent > 80 : self.summary.usedPercent < 20
    }

    private var isExhausted: Bool {
        guard self.summary.hasQuota else { return false }
        return self.showsUsed ? self.summary.usedPercent >= 99.5 : self.summary.usedPercent <= 0.5
    }

    private var percentColor: Color {
        if self.isExhausted { return self.runicTheme.warm }
        if self.emphasizes { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }

    private var barTint: Color {
        if self.isExhausted { return self.runicTheme.warm }
        if self.emphasizes { return self.runicTheme.highlight }
        return self.summary.brandColor
    }
}
