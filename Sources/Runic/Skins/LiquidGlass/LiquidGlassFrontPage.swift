import AppKit
import RunicCore
import SwiftUI

/// The overview through glass: the day's average as a 30pt numeral in a
/// matte well beside its one-line read, every provider as a well with its
/// brand tile, numeral and capillary (two-region brands stacked under one
/// header with the missing side offered), and the week's activity last.
struct LiquidGlassFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            self.hero

            if self.view.summaries.isEmpty {
                LiquidGlassWell(padding: 14) {
                    Text("No active providers.")
                        .font(RunicLiquidGlass.body(12))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                LiquidGlassSectionTitle(
                    title: "Providers",
                    systemImage: "square.stack.3d.up",
                    trailing: "\(self.view.summaries.count) of \(self.view.totalProviders) active")
                    .padding(.top, 2)
                ForEach(OverviewMenuView.brandGroups(self.view.summaries)) { group in
                    if group.isStacked {
                        LiquidGlassBrandStack(
                            group: group,
                            showsUsed: self.view.showsUsed,
                            numberStyle: self.view.numberStyle,
                            onAddRegion: self.view.onAddRegion)
                    } else if let summary = group.rows.first {
                        LiquidGlassWell(padding: 10) {
                            LiquidGlassProviderRow(
                                summary: summary,
                                showsUsed: self.view.showsUsed,
                                numberStyle: self.view.numberStyle)
                        }
                    }
                }
            }

            if !self.view.chartPoints.isEmpty {
                HStack(alignment: .center) {
                    LiquidGlassSectionTitle(title: "7-day activity", systemImage: "chart.bar.fill")
                    HStack(spacing: 4) {
                        ForEach(self.view.chartLegendEntries.prefix(5), id: \.name) { entry in
                            Capsule(style: .continuous)
                                .fill(entry.color)
                                .frame(width: 10, height: 5)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .padding(.top, 2)
                LiquidGlassWell(padding: 10) {
                    self.view.activityChart
                }
            }
        }
        .skinFace()
        .foregroundStyle(self.runicTheme.primaryText)
        .padding(RunicLiquidGlass.panelInset)
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Hero

    private var hero: some View {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        let exhausted = self.view.summaries.count(where: { summary in
            guard summary.hasQuota else { return false }
            return self.view.showsUsed ? summary.usedPercent >= 99.5 : summary.usedPercent <= 0.5
        })
        let banked = self.view.summaries.count(where: { $0.bankedResetsText != nil })
        return HStack(alignment: .center, spacing: 12) {
            LiquidGlassWell(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(average.map { "\(Int($0.rounded()))" } ?? "\u{2014}")
                            .font(RunicLiquidGlass.hero())
                            .skinFace()
                            .foregroundStyle(self.runicTheme.primaryText)
                        if average != nil {
                            Text("%")
                                .font(RunicLiquidGlass.header())
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }
                    }
                    LiquidGlassLabel(text: "avg \(self.view.showsUsed ? "used" : "left")")
                    if let average {
                        BorosilicateCapillaryBar(
                            percent: average,
                            tint: LiquidGlassProviderPage.liquidTint(
                                used: self.view.showsUsed ? average : 100 - average,
                                theme: self.runicTheme),
                            accessibilityLabel: self.view.showsUsed ? "Average used" : "Average remaining",
                            height: 8)
                    }
                }
            }
            .frame(width: 128)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(self.view.averagePercentText)

            VStack(alignment: .leading, spacing: 6) {
                LiquidGlassLabel(text: "Today")
                Text(RunicLiquidGlass.headline(forUsed: average.map { self.view.showsUsed ? $0 : 100 - $0 }))
                    .font(RunicLiquidGlass.header(17))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if self.view.totalTodayTokens > 0 {
                    let tokens = UsageFormatter.tokenCountString(
                        self.view.totalTodayTokens,
                        style: self.view.numberStyle)
                    Text("\(tokens) tokens today")
                        .font(RunicLiquidGlass.numeric(11.5))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    if exhausted > 0 {
                        LiquidGlassPill(
                            text: exhausted == 1 ? "1 exhausted" : "\(exhausted) exhausted",
                            tone: .critical)
                    }
                    if banked > 0 {
                        LiquidGlassPill(
                            text: banked == 1 ? "1 banked" : "\(banked) banked",
                            systemImage: "arrow.counterclockwise",
                            tone: .good)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Brand stack

/// A two-region brand as one well: the brand once, a row per region tagged
/// INTL / CN, and the add offer for the unconfigured side.
private struct LiquidGlassBrandStack: View {
    let group: OverviewMenuView.BrandGroup
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    let onAddRegion: ((UsageProvider) -> Void)?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        LiquidGlassWell(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    LiquidGlassProviderMark(
                        image: self.group.rows.first?.icon,
                        name: self.brandName,
                        tint: self.group.rows.first?.brandColor ?? self.runicTheme.accent,
                        size: 22)
                    Text(self.brandName)
                        .font(RunicLiquidGlass.body(12.5, .semibold))
                        .skinFace()
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    LiquidGlassLabel(text: self.group.rows.count == 2 ? "2 regions" : "1 of 2 regions")
                }
                ForEach(self.group.rows) { summary in
                    LiquidGlassHairline()
                    LiquidGlassProviderRow(
                        summary: summary,
                        showsUsed: self.showsUsed,
                        numberStyle: self.numberStyle,
                        regionTag: summary.region == .china ? "CN" : "INTL")
                }
                if let missing = self.group.missingSlot, let onAddRegion = self.onAddRegion {
                    let label = OverviewMenuView.addRegionLabel(for: missing)
                    LiquidGlassButton(title: label, systemImage: "plus") {
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

// MARK: - Provider row

/// One provider: brand tile (or region tag), name and numeral on one line,
/// the capillary in the brand colour, the window, reset, banked resets and
/// context as a byline.
private struct LiquidGlassProviderRow: View {
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle
    var regionTag: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let regionTag {
                Text(regionTag)
                    .font(RunicLiquidGlass.label(9.5))
                    .skinFace()
                    .tracking(0.6)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(width: 28, height: 18)
                    .background(Capsule(style: .continuous).fill(self.runicTheme.primaryText.opacity(0.06)))
                    .padding(.top, 1)
            } else {
                LiquidGlassProviderMark(
                    image: self.summary.icon,
                    name: self.summary.name,
                    tint: self.summary.brandColor,
                    size: 28)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(self.summary.name)
                        .font(RunicLiquidGlass.body(13, .semibold))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                        .layoutPriority(1)
                    if let plan = self.summary.planBadge {
                        LiquidGlassPill(
                            text: plan,
                            tone: OverviewMenuView.isElevatedPlanBadge(plan) ? .accent : .neutral)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    Spacer(minLength: 6)
                    if self.summary.todayTokens > 0 {
                        Text(UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle))
                            .font(RunicLiquidGlass.numeric(10.5))
                            .skinFace()
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(self.summary.hasQuota ? "\(Int(self.summary.usedPercent.rounded()))" : "\u{2014}")
                            .font(RunicLiquidGlass.numeric(17, .semibold))
                            .skinFace()
                            .foregroundStyle(self.percentColor)
                        if self.summary.hasQuota {
                            Text("%")
                                .font(RunicLiquidGlass.body(11, .medium))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }
                    }
                }
                if self.summary.hasQuota {
                    let direction = self.showsUsed ? "usage used" : "usage remaining"
                    BorosilicateCapillaryBar(
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
                                .font(RunicLiquidGlass.body(10.5))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 0)
                        if let banked = self.summary.bankedResetsText {
                            LiquidGlassPill(text: banked, systemImage: "arrow.counterclockwise", tone: .good)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Heavy use in "used" mode, little headroom in "left" mode.
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
