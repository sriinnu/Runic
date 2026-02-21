import Charts
import RunicCore
import SwiftUI

@MainActor
struct ProjectBreakdownMenuView: View {
    private let breakdown: [UsageLedgerProjectSummary]
    private let width: CGFloat

    /// Maximum number of projects to show before truncating with "and N more".
    private static let maxDisplayed = 8

    init(breakdown: [UsageLedgerProjectSummary], width: CGFloat) {
        self.breakdown = breakdown
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(from: self.breakdown)
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            if model.items.isEmpty {
                Text("No project data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                // MARK: - Title
                Text("Projects")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

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
                            .font(.caption2)
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    }
                }
                .chartLegend(.hidden)
                .frame(height: Self.chartHeight(itemCount: model.chartItems.count))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.chartAccessibilityLabel(model: model))

                // MARK: - Project list
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    ForEach(model.chartItems) { item in
                        Self.projectRow(item: item)
                    }
                }

                // MARK: - Overflow note
                if model.overflowCount > 0 {
                    Text("and \(model.overflowCount) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // MARK: - Total summary
                Divider()
                Self.totalRow(model: model)
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Row views

    private static func projectRow(item: ProjectItem) -> some View {
        HStack(spacing: RunicSpacing.xxs) {
            Circle()
                .fill(item.color)
                .frame(width: RunicSpacing.chartLegendDot, height: RunicSpacing.chartLegendDot)
            Text(item.name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: RunicSpacing.xxs)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(UsageFormatter.tokenCountString(item.totalTokens)) tokens")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                HStack(spacing: RunicSpacing.xxxs) {
                    if let cost = item.costText {
                        Text(cost)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    if item.modelCount > 0 {
                        Text("\(item.modelCount) model\(item.modelCount == 1 ? "" : "s")")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private static func totalRow(model: ProjectModel) -> some View {
        HStack {
            Text("Total")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Spacer(minLength: RunicSpacing.xxs)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(UsageFormatter.tokenCountString(model.grandTotalTokens)) tokens")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                if let cost = model.grandTotalCostText {
                    Text(cost)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
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
        let color: Color
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

    private static func makeModel(from breakdown: [UsageLedgerProjectSummary]) -> ProjectModel {
        let sorted = breakdown.sorted { lhs, rhs in
            lhs.totals.totalTokens > rhs.totals.totalTokens
        }

        let items: [ProjectItem] = sorted.enumerated().map { index, summary in
            let name = summary.projectName ?? summary.projectID ?? "Unknown project"
            let costText = summary.totals.costUSD.map { UsageFormatter.usdString($0) }
            return ProjectItem(
                id: "\(name)-\(index)",
                name: name,
                totalTokens: summary.totals.totalTokens,
                costText: costText,
                modelCount: summary.modelsUsed.count,
                color: RunicColors.chartColor(at: index))
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
}
