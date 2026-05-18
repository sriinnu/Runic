import RunicCore
import SwiftUI

@MainActor
struct EfficiencyMetricsMenuView: View {
    @Environment(\.runicFonts) private var fonts
    enum SortColumn {
        case model
        case tokensPerRequest
        case costPerRequest
        case cacheHitRate

        var label: String {
            switch self {
            case .model: "Model"
            case .tokensPerRequest: "Tokens/Req"
            case .costPerRequest: "Cost/Req"
            case .cacheHitRate: "Cache Hit %"
            }
        }
    }

    fileprivate struct ModelMetrics: Identifiable {
        let id: String
        let modelName: String
        let requestCount: Int
        let tokensPerRequest: Double
        let costPerRequest: Double?
        let cacheHitRate: Double // 0.0-1.0

        init(summary: UsageLedgerModelSummary) {
            self.id = summary.model
            self.modelName = summary.model
            self.requestCount = summary.entryCount
            self.tokensPerRequest = summary.entryCount > 0
                ? Double(summary.totals.totalTokens) / Double(summary.entryCount)
                : 0
            self.costPerRequest = if let cost = summary.totals.costUSD, summary.entryCount > 0 {
                cost / Double(summary.entryCount)
            } else {
                nil
            }

            let cacheTotal = summary.totals.cacheCreationTokens + summary.totals.cacheReadTokens
            let totalTokens = summary.totals.totalTokens
            self.cacheHitRate = totalTokens > 0 ? Double(cacheTotal) / Double(totalTokens) : 0.0
        }
    }

    private let modelSummaries: [UsageLedgerModelSummary]
    private let width: CGFloat
    @State private var sortColumn: SortColumn = .tokensPerRequest
    @State private var sortAscending = false
    @State private var hoveredModelID: String?
    @Environment(\.runicTheme) private var runicTheme

    init(modelSummaries: [UsageLedgerModelSummary], width: CGFloat) {
        self.modelSummaries = modelSummaries
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(
            from: self.modelSummaries,
            sortBy: self.sortColumn,
            ascending: self.sortAscending)

        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            Text("Efficiency Metrics")
                .font(self.fonts.headline)
                .fontWeight(.semibold)

            if model.isEmpty {
                Text("No efficiency metrics available.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    // Header
                    HStack(spacing: 0) {
                        SortableColumnHeader(
                            title: "Model",
                            column: .model,
                            currentSort: self.sortColumn,
                            ascending: self.sortAscending,
                            width: 140,
                            onSort: self.toggleSort)
                        SortableColumnHeader(
                            title: "Tokens/Req",
                            column: .tokensPerRequest,
                            currentSort: self.sortColumn,
                            ascending: self.sortAscending,
                            width: 90,
                            onSort: self.toggleSort)
                        SortableColumnHeader(
                            title: "Cost/Req",
                            column: .costPerRequest,
                            currentSort: self.sortColumn,
                            ascending: self.sortAscending,
                            width: 80,
                            onSort: self.toggleSort)
                        SortableColumnHeader(
                            title: "Cache Hit",
                            column: .cacheHitRate,
                            currentSort: self.sortColumn,
                            ascending: self.sortAscending,
                            width: 80,
                            onSort: self.toggleSort)
                    }
                    .padding(.horizontal, RunicSpacing.xs)
                    .padding(.vertical, RunicSpacing.xxs)
                    .background(self.runicTheme.menuSubtleFill)
                    .cornerRadius(self.runicTheme.shape.cornerRadius(RunicCornerRadius.xs))

                    Divider()
                        .overlay(self.runicTheme.menuSeparatorColor)

                    ScrollView {
                        VStack(spacing: RunicSpacing.xxxs) {
                            ForEach(model) { metrics in
                                MetricsRow(
                                    metrics: metrics,
                                    isHovered: self.hoveredModelID == metrics.id)
                                    .onHover { hovering in
                                        self.hoveredModelID = hovering ? metrics.id : nil
                                    }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }

                // Summary stats
                Divider()
                    .overlay(self.runicTheme.menuSeparatorColor)
                    .padding(.vertical, RunicSpacing.xxs)

                HStack(spacing: RunicSpacing.lg) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        Text("Total Requests")
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.secondaryText)
                        Text("\(Self.totalRequests(model))")
                            .font(self.fonts.caption)
                            .fontWeight(.medium)
                    }
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        Text("Avg Tokens/Req")
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.secondaryText)
                        Text(UsageFormatter.tokenCountString(Self.averageTokensPerRequest(model)))
                            .font(self.fonts.caption)
                            .fontWeight(.medium)
                    }
                    if Self.hasAnyCost(model) {
                        VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                            Text("Avg Cost/Req")
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText)
                            Text(UsageFormatter.usdString(Self.averageCostPerRequest(model)))
                                .font(self.fonts.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private func toggleSort(column: SortColumn) {
        if self.sortColumn == column {
            self.sortAscending.toggle()
        } else {
            self.sortColumn = column
            self.sortAscending = false
        }
    }

    private static func makeModel(
        from summaries: [UsageLedgerModelSummary],
        sortBy: SortColumn,
        ascending: Bool) -> [ModelMetrics]
    {
        let metrics = summaries.map { ModelMetrics(summary: $0) }
        return metrics.sorted { lhs, rhs in
            let result: Bool
            switch sortBy {
            case .model:
                result = lhs.modelName < rhs.modelName
            case .tokensPerRequest:
                result = lhs.tokensPerRequest < rhs.tokensPerRequest
            case .costPerRequest:
                let lhsCost = lhs.costPerRequest ?? 0
                let rhsCost = rhs.costPerRequest ?? 0
                result = lhsCost < rhsCost
            case .cacheHitRate:
                result = lhs.cacheHitRate < rhs.cacheHitRate
            }
            return ascending ? result : !result
        }
    }

    private static func totalRequests(_ metrics: [ModelMetrics]) -> Int {
        metrics.reduce(0) { $0 + $1.requestCount }
    }

    private static func averageTokensPerRequest(_ metrics: [ModelMetrics]) -> Int {
        let totalTokens = metrics.reduce(0.0) { $0 + ($1.tokensPerRequest * Double($1.requestCount)) }
        let totalRequests = totalRequests(metrics)
        return totalRequests > 0 ? Int(totalTokens / Double(totalRequests)) : 0
    }

    private static func averageCostPerRequest(_ metrics: [ModelMetrics]) -> Double {
        let totalCost = metrics.reduce(0.0) { sum, m in
            sum + ((m.costPerRequest ?? 0) * Double(m.requestCount))
        }
        let totalRequests = totalRequests(metrics)
        return totalRequests > 0 ? totalCost / Double(totalRequests) : 0
    }

    private static func hasAnyCost(_ metrics: [ModelMetrics]) -> Bool {
        metrics.contains { $0.costPerRequest != nil }
    }
}

private struct SortableColumnHeader: View {
    @Environment(\.runicFonts) private var fonts
    let title: String
    let column: EfficiencyMetricsMenuView.SortColumn
    let currentSort: EfficiencyMetricsMenuView.SortColumn
    let ascending: Bool
    let width: CGFloat
    let onSort: (EfficiencyMetricsMenuView.SortColumn) -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button {
            self.onSort(self.column)
        } label: {
            HStack(spacing: RunicSpacing.xxs) {
                Text(self.title)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .fontWeight(.medium)
                if self.currentSort == self.column {
                    Image(systemName: self.ascending ? "chevron.up" : "chevron.down")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.accent)
                }
            }
            .frame(width: self.width, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct MetricsRow: View {
    @Environment(\.runicFonts) private var fonts
    let metrics: EfficiencyMetricsMenuView.ModelMetrics
    let isHovered: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                Text(UsageFormatter.modelDisplayName(self.metrics.modelName))
                    .font(self.fonts.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let context = UsageFormatter.modelContextLabel(for: metrics.modelName) {
                    Text(context)
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(width: 140, alignment: .leading)
            Text(UsageFormatter.tokenCountString(Int(self.metrics.tokensPerRequest)))
                .font(self.fonts.caption)
                .frame(width: 90, alignment: .leading)
            if let cost = metrics.costPerRequest {
                Text(UsageFormatter.usdString(cost))
                    .font(self.fonts.caption)
                    .frame(width: 80, alignment: .leading)
            } else {
                Text("—")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(width: 80, alignment: .leading)
            }
            Text(String(format: "%.1f%%", self.metrics.cacheHitRate * 100))
                .font(self.fonts.caption)
                .foregroundStyle(self.cacheHitColor)
                .frame(width: 80, alignment: .leading)
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.compact)
        .background {
            if self.isHovered {
                RoundedRectangle(cornerRadius: RunicSpacing.xxs, style: .continuous)
                    .fill(self.runicTheme.menuHoverFill)
            }
        }
    }

    private var cacheHitColor: Color {
        if self.metrics.cacheHitRate > 0.5 {
            self.runicTheme.tertiary
        } else if self.metrics.cacheHitRate > 0.2 {
            self.runicTheme.highlight
        } else {
            self.runicTheme.secondaryText
        }
    }
}
