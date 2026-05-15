import Charts
import RunicCore
import SwiftUI

@MainActor
struct ProjectBreakdownMenuView: View {
    private let breakdown: [UsageLedgerProjectSummary]
    private let width: CGFloat
    @State private var selectedProjectID: String?
    @Environment(\.runicTheme) private var runicTheme

    /// Maximum number of projects to show before truncating with "and N more".
    private static let maxDisplayed = 8

    init(breakdown: [UsageLedgerProjectSummary], width: CGFloat) {
        self.breakdown = breakdown
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(from: self.breakdown, theme: self.runicTheme)
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            if model.items.isEmpty {
                Text("No project data.")
                    .font(RunicFont.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            } else {
                let detail = self.detailText(model: model)
                // MARK: - Title

                Text("Projects")
                    .font(RunicFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(self.runicTheme.primaryText)

                // MARK: - Horizontal bar chart

                Chart {
                    ForEach(model.chartItems) { item in
                        BarMark(
                            x: .value("Tokens", item.totalTokens),
                            y: .value("Project", item.name))
                            .foregroundStyle(item.color)
                            .cornerRadius(RunicCornerRadius.xs)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(RunicFont.caption2)
                            .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                    }
                }
                .chartLegend(.hidden)
                .frame(height: Self.chartHeight(itemCount: model.chartItems.count))
                .help(detail)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if let rect = self.selectionBandRect(model: model, proxy: proxy, geo: geo) {
                                RoundedRectangle(cornerRadius: RunicCornerRadius.xs, style: .continuous)
                                    .fill(self.runicTheme.chartSelectionBandColor)
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .allowsHitTesting(false)
                            }
                            MouseLocationReader { location in
                                self.updateSelection(location: location, model: model, proxy: proxy, geo: geo)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.chartAccessibilityLabel(model: model))

                Text(detail)
                    .font(RunicFont.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // MARK: - Project list

                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    ForEach(model.chartItems) { item in
                        Self.projectRow(item: item, theme: self.runicTheme)
                            .help(item.helpText(grandTotalTokens: model.grandTotalTokens))
                    }
                }

                // MARK: - Overflow note

                if model.overflowCount > 0 {
                    Text("and \(model.overflowCount) more")
                        .font(RunicFont.caption2)
                        .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                }

                // MARK: - Total summary

                Divider()
                    .overlay(self.runicTheme.menuSeparatorColor)
                Self.totalRow(model: model, theme: self.runicTheme)
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Row views

    private static func projectRow(item: ProjectItem, theme: RunicThemePalette) -> some View {
        HStack(spacing: RunicSpacing.xxs) {
            Circle()
                .fill(item.color)
                .frame(width: RunicSpacing.chartLegendDot, height: RunicSpacing.chartLegendDot)
            Text(item.name)
                .font(RunicFont.caption)
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: RunicSpacing.xxs)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(UsageFormatter.tokenCountString(item.totalTokens)) tokens")
                    .font(RunicFont.caption2)
                    .foregroundStyle(theme.secondaryText)
                HStack(spacing: RunicSpacing.xxxs) {
                    if let cost = item.costText {
                        Text(cost)
                            .font(RunicFont.caption2)
                            .foregroundStyle(theme.chartAxisLabelColor)
                    }
                    if item.modelCount > 0 {
                        Text("\(item.modelCount) model\(item.modelCount == 1 ? "" : "s")")
                            .font(RunicFont.caption2)
                            .foregroundStyle(theme.chartAxisLabelColor)
                    }
                }
            }
        }
    }

    private static func totalRow(model: ProjectModel, theme: RunicThemePalette) -> some View {
        HStack {
            Text("Total")
                .font(RunicFont.caption)
                .fontWeight(.medium)
                .foregroundStyle(theme.primaryText)
            Spacer(minLength: RunicSpacing.xxs)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(UsageFormatter.tokenCountString(model.grandTotalTokens)) tokens")
                    .font(RunicFont.caption2)
                    .foregroundStyle(theme.secondaryText)
                if let cost = model.grandTotalCostText {
                    Text(cost)
                        .font(RunicFont.caption2)
                        .foregroundStyle(theme.chartAxisLabelColor)
                }
            }
        }
    }

    // MARK: - Chart height

    private static func chartHeight(itemCount: Int) -> CGFloat {
        // ~24pt per bar, minimum 60pt
        max(60, CGFloat(itemCount) * 24)
    }

    // MARK: - Model

    struct ProjectItem: Identifiable {
        let id: String
        let name: String
        let totalTokens: Int
        let costText: String?
        let modelCount: Int
        let attributionText: String?
        let color: Color

        func helpText(grandTotalTokens: Int) -> String {
            let share = grandTotalTokens > 0
                ? Double(self.totalTokens) / Double(grandTotalTokens) * 100
                : 0
            var parts = [
                self.name,
                "\(UsageFormatter.tokenCountString(self.totalTokens)) tokens",
                "\(String(format: "%.0f", share))%",
            ]
            if let costText {
                parts.append(costText)
            }
            if let attributionText {
                parts.append(attributionText)
            }
            return parts.joined(separator: " · ")
        }
    }

    struct ProjectModel {
        let items: [ProjectItem]
        let chartItems: [ProjectItem]
        let overflowCount: Int
        let grandTotalTokens: Int
        let grandTotalCostText: String?
    }

    private static func chartAccessibilityLabel(model: ProjectModel) -> String {
        guard !model.chartItems.isEmpty else { return "Project breakdown chart, no data" }

        let projectCount = model.items.count
        let totalTokens = UsageFormatter.tokenCountString(model.grandTotalTokens)

        let topItems = model.chartItems.prefix(3).map { item -> String in
            let pct = model.grandTotalTokens > 0
                ? Double(item.totalTokens) / Double(model.grandTotalTokens) * 100
                : 0
            return "\(item.name) \(String(format: "%.0f", pct))%"
        }

        var label = "Project breakdown: \(projectCount) project\(projectCount == 1 ? "" : "s"), \(totalTokens) tokens total"
        if !topItems.isEmpty {
            label += ", \(topItems.joined(separator: ", "))"
        }
        return label
    }

    private static func makeModel(from breakdown: [UsageLedgerProjectSummary], theme: RunicThemePalette) -> ProjectModel {
        let sorted = breakdown.sorted { lhs, rhs in
            lhs.totals.totalTokens > rhs.totals.totalTokens
        }

        let items: [ProjectItem] = sorted.enumerated().map { index, summary in
            let name = RunicProjectDisplay.name(for: summary)
            let costText = summary.totals.costUSD.map { UsageFormatter.usdString($0) }
            return ProjectItem(
                id: "\(name)-\(index)",
                name: name,
                totalTokens: summary.totals.totalTokens,
                costText: costText,
                modelCount: summary.modelsUsed.count,
                attributionText: RunicProjectDisplay.attributionText(for: summary),
                color: theme.chartColor(at: index))
        }

        let displayed = Array(items.prefix(self.maxDisplayed))
        let overflow = max(0, items.count - self.maxDisplayed)

        let grandTokens = sorted.reduce(0) { $0 + $1.totals.totalTokens }
        let grandCost = sorted.reduce(0.0) { $0 + ($1.totals.costUSD ?? 0) }
        let grandCostText = grandCost > 0 ? UsageFormatter.usdString(grandCost) : nil

        return ProjectModel(
            items: items,
            chartItems: displayed,
            overflowCount: overflow,
            grandTotalTokens: grandTokens,
            grandTotalCostText: grandCostText)
    }

    private func selectionBandRect(model: ProjectModel, proxy: ChartProxy, geo: GeometryProxy) -> CGRect? {
        guard let selectedProjectID = self.selectedProjectID else { return nil }
        guard let plotAnchor = proxy.plotFrame else { return nil }
        let plotFrame = geo[plotAnchor]
        guard let index = model.chartItems.firstIndex(where: { $0.id == selectedProjectID }) else { return nil }
        let item = model.chartItems[index]
        guard let y = proxy.position(forY: item.name) else { return nil }

        let step = plotFrame.height / CGFloat(max(1, model.chartItems.count))
        let height = min(30, max(18, step * 0.72))
        return CGRect(
            x: plotFrame.origin.x,
            y: plotFrame.origin.y + y - (height / 2),
            width: plotFrame.width,
            height: height)
    }

    private func updateSelection(
        location: CGPoint?,
        model: ProjectModel,
        proxy: ChartProxy,
        geo: GeometryProxy)
    {
        guard let location else {
            if self.selectedProjectID != nil { self.selectedProjectID = nil }
            return
        }
        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location) else {
            if self.selectedProjectID != nil { self.selectedProjectID = nil }
            return
        }

        let yInPlot = location.y - plotFrame.origin.y
        var bestID: String?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for item in model.chartItems {
            guard let y = proxy.position(forY: item.name) else { continue }
            let distance = abs(y - yInPlot)
            if distance < bestDistance {
                bestDistance = distance
                bestID = item.id
            }
        }
        if let bestID, self.selectedProjectID != bestID {
            self.selectedProjectID = bestID
        }
    }

    private func detailText(model: ProjectModel) -> String {
        let item = self.selectedProjectID
            .flatMap { selected in model.chartItems.first(where: { $0.id == selected }) }
            ?? model.chartItems.first
        guard let item else { return "Hover a project for attribution" }
        return item.helpText(grandTotalTokens: model.grandTotalTokens)
    }
}
