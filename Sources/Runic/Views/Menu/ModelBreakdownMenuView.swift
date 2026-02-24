import Charts
import RunicCore
import SwiftUI

@MainActor
struct ModelBreakdownMenuView: View {
    private let breakdown: [UsageLedgerModelSummary]
    private let width: CGFloat

    /// Maximum number of models to show before truncating.
    private static let maxDisplayed = 10

    init(breakdown: [UsageLedgerModelSummary], width: CGFloat) {
        self.breakdown = breakdown
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(from: self.breakdown)
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            if model.items.isEmpty {
                Text("No model data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                // MARK: - Title
                Text("Models")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                // MARK: - Donut chart
                Chart {
                    ForEach(model.chartItems) { item in
                        SectorMark(
                            angle: .value("Tokens", item.totalTokens),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.0)
                            .foregroundStyle(item.color)
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 100)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.chartAccessibilityLabel(model: model))

                // MARK: - Model list
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    ForEach(model.chartItems) { item in
                        Self.modelRow(item: item)
                    }
                }

                // MARK: - Overflow note
                if model.overflowCount > 0 {
                    Text("and \(model.overflowCount) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // MARK: - Cache hit rate
                if let cacheRate = model.cacheHitRateText {
                    Divider()
                    HStack(spacing: RunicSpacing.xxs) {
                        Text("Cache hit rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: RunicSpacing.xxs)
                        Text(cacheRate)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
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

    private static func modelRow(item: ModelItem) -> some View {
        HStack(spacing: RunicSpacing.xxs) {
            Circle()
                .fill(item.color)
                .frame(width: RunicSpacing.chartLegendDot, height: RunicSpacing.chartLegendDot)
            Text(item.displayName)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: RunicSpacing.xxs)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(UsageFormatter.tokenCountString(item.totalTokens)) tokens")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                if let context = UsageFormatter.modelContextLabel(for: item.model) {
                    Text(context)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: RunicSpacing.xxxs) {
                    Text("\(item.requestCount) req\(item.requestCount == 1 ? "" : "s")")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                    if let cost = item.costText {
                        Text(cost)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private static func totalRow(model: ModelModel) -> some View {
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
                HStack(spacing: RunicSpacing.xxxs) {
                    Text("\(model.grandTotalRequests) requests")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                    if let cost = model.grandTotalCostText {
                        Text(cost)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Model

    struct ModelItem: Identifiable {
        let id: String
        let displayName: String
        let model: String
        let totalTokens: Int
        let requestCount: Int
        let costText: String?
        let color: Color
    }

    struct ModelModel {
        let items: [ModelItem]
        let chartItems: [ModelItem]
        let overflowCount: Int
        let grandTotalTokens: Int
        let grandTotalRequests: Int
        let grandTotalCostText: String?
        let cacheHitRateText: String?
    }

    private static func chartAccessibilityLabel(model: ModelModel) -> String {
        guard !model.chartItems.isEmpty else { return "Model breakdown chart, no data" }

        let modelCount = model.items.count
        let totalTokens = UsageFormatter.tokenCountString(model.grandTotalTokens)

        let topItems = model.chartItems.prefix(3).map { item -> String in
            let pct = model.grandTotalTokens > 0
                ? Double(item.totalTokens) / Double(model.grandTotalTokens) * 100
                : 0
            return "\(item.displayName) \(String(format: "%.0f", pct))%"
        }

        var label = "Model breakdown: \(modelCount) model\(modelCount == 1 ? "" : "s"), \(totalTokens) tokens total"
        if !topItems.isEmpty {
            label += ", \(topItems.joined(separator: ", "))"
        }
        if let cacheRate = model.cacheHitRateText {
            label += ", cache hit rate \(cacheRate)"
        }
        return label
    }

    private static func makeModel(from breakdown: [UsageLedgerModelSummary]) -> ModelModel {
        let sorted = breakdown.sorted { lhs, rhs in
            lhs.totals.totalTokens > rhs.totals.totalTokens
        }

        let items: [ModelItem] = sorted.enumerated().map { index, summary in
            let displayName = UsageFormatter.modelDisplayName(summary.model)
            let costText = summary.totals.costUSD.map { UsageFormatter.usdString($0) }
            return ModelItem(
                id: "\(summary.model)-\(index)",
                displayName: displayName,
                model: summary.model,
                totalTokens: summary.totals.totalTokens,
                requestCount: summary.entryCount,
                costText: costText,
                color: RunicColors.colorForModel(summary.model))
        }

        let displayed = Array(items.prefix(self.maxDisplayed))
        let overflow = max(0, items.count - self.maxDisplayed)

        let grandTokens = sorted.reduce(0) { $0 + $1.totals.totalTokens }
        let grandRequests = sorted.reduce(0) { $0 + $1.entryCount }
        let grandCost = sorted.reduce(0.0) { $0 + ($1.totals.costUSD ?? 0) }
        let grandCostText = grandCost > 0 ? UsageFormatter.usdString(grandCost) : nil

        // Cache hit rate: cacheReadTokens / totalTokens across all models
        let totalCacheRead = sorted.reduce(0) { $0 + $1.totals.cacheReadTokens }
        let cacheHitRateText: String? = if grandTokens > 0, totalCacheRead > 0 {
            String(format: "%.1f%%", Double(totalCacheRead) / Double(grandTokens) * 100)
        } else {
            nil
        }

        return ModelModel(
            items: items,
            chartItems: displayed,
            overflowCount: overflow,
            grandTotalTokens: grandTokens,
            grandTotalRequests: grandRequests,
            grandTotalCostText: grandCostText,
            cacheHitRateText: cacheHitRateText)
    }
}
