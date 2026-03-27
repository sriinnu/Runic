import Charts
import RunicCore
import SwiftUI

@MainActor
struct CostComparativeChartMenuView: View {
    private struct ModelCostData: Identifiable {
        let id: String
        let modelName: String
        let costPerToken: Double
        let totalTokens: Int
        let totalCost: Double
        let relativeExpensiveness: Double // multiplier vs average

        init(modelName: String, totalTokens: Int, totalCost: Double, averageCostPerToken: Double) {
            self.id = modelName
            self.modelName = modelName
            self.totalTokens = totalTokens
            self.totalCost = totalCost
            self.costPerToken = totalTokens > 0 ? totalCost / Double(totalTokens) : 0
            self.relativeExpensiveness = averageCostPerToken > 0 ? (self.costPerToken / averageCostPerToken) : 1.0
        }
    }

    private let modelSummaries: [UsageLedgerModelSummary]
    private let width: CGFloat
    @State private var selectedModelID: String?

    init(modelSummaries: [UsageLedgerModelSummary], width: CGFloat) {
        self.modelSummaries = modelSummaries
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(from: self.modelSummaries)
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            if model.isEmpty {
                Text("No cost comparison data.")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(model) { data in
                        BarMark(
                            x: .value("Cost per token", data.costPerToken * 1_000_000),
                            y: .value("Model", UsageFormatter.modelDisplayName(data.modelName)))
                            .foregroundStyle(Self.colorForExpensiveness(data.relativeExpensiveness))
                    }
                }
                .chartXAxisLabel("Cost per 1M tokens (USD)")
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let cost = value.as(Double.self) {
                                Text(UsageFormatter.usdString(cost))
                                    .font(RunicFont.caption2)
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.clear)
                        AxisTick().foregroundStyle(Color.clear)
                        AxisValueLabel()
                            .font(RunicFont.caption2)
                            .foregroundStyle(Color(nsColor: .labelColor))
                    }
                }
                .chartLegend(.hidden)
                .frame(height: CGFloat(min(300, max(150, model.count * 30))))
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if let rect = self.selectionBandRect(model: model, proxy: proxy, geo: geo) {
                                Rectangle()
                                    .fill(Self.selectionBandColor)
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

                let detail = self.detailLines(model: model)
                VStack(alignment: .leading, spacing: 0) {
                    Text(detail.primary)
                        .font(RunicFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(height: 32, alignment: .leading)
                    if let secondary = detail.secondary {
                        Text(secondary)
                            .font(RunicFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(height: 16, alignment: .leading)
                    }
                }

                // Legend
                HStack(spacing: RunicSpacing.md) {
                    HStack(spacing: RunicSpacing.xxs) {
                        Circle()
                            .fill(Self.cheapColor)
                            .frame(width: 8, height: 8)
                        Text("Low cost")
                            .font(RunicFont.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: RunicSpacing.xxs) {
                        Circle()
                            .fill(Self.mediumColor)
                            .frame(width: 8, height: 8)
                        Text("Medium cost")
                            .font(RunicFont.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: RunicSpacing.xxs) {
                        Circle()
                            .fill(Self.expensiveColor)
                            .frame(width: 8, height: 8)
                        Text("High cost")
                            .font(RunicFont.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private static let selectionBandColor = Color(nsColor: .labelColor).opacity(0.1)
    private static let cheapColor = Color(red: 0.46, green: 0.75, blue: 0.36)
    private static let mediumColor = Color(red: 0.94, green: 0.74, blue: 0.26)
    private static let expensiveColor = Color(red: 0.94, green: 0.36, blue: 0.36)

    private static func makeModel(from summaries: [UsageLedgerModelSummary]) -> [ModelCostData] {
        let withCost = summaries.compactMap { summary -> ModelCostData? in
            guard let cost = summary.totals.costUSD, cost > 0,
                  summary.totals.totalTokens > 0
            else {
                return nil
            }
            // Calculate average cost per token across all models
            let totalCost = summaries.compactMap(\.totals.costUSD).reduce(0, +)
            let totalTokens = summaries.map(\.totals.totalTokens).reduce(0, +)
            let averageCostPerToken = totalTokens > 0 ? totalCost / Double(totalTokens) : 0

            return ModelCostData(
                modelName: summary.model,
                totalTokens: summary.totals.totalTokens,
                totalCost: cost,
                averageCostPerToken: averageCostPerToken)
        }

        return withCost.sorted { $0.costPerToken > $1.costPerToken }
    }

    private static func colorForExpensiveness(_ relative: Double) -> Color {
        if relative < 0.7 {
            self.cheapColor
        } else if relative < 1.5 {
            self.mediumColor
        } else {
            self.expensiveColor
        }
    }

    private func selectionBandRect(model: [ModelCostData], proxy: ChartProxy, geo: GeometryProxy) -> CGRect? {
        guard let modelID = self.selectedModelID else { return nil }
        guard let plotAnchor = proxy.plotFrame else { return nil }
        let plotFrame = geo[plotAnchor]
        guard let index = model.firstIndex(where: { $0.id == modelID }) else { return nil }
        let modelName = UsageFormatter.modelDisplayName(model[index].modelName)
        guard let y = proxy.position(forY: modelName) else { return nil }

        func yForIndex(_ idx: Int) -> CGFloat? {
            guard idx >= 0, idx < model.count else { return nil }
            return proxy.position(forY: UsageFormatter.modelDisplayName(model[idx].modelName))
        }

        let yPrev = yForIndex(index - 1)
        let yNext = yForIndex(index + 1)

        let topInPlot: CGFloat = if let yPrev {
            (yPrev + y) / 2
        } else if let yNext {
            y - (yNext - y) / 2
        } else {
            y - 8
        }

        let bottomInPlot: CGFloat = if let yNext {
            (yNext + y) / 2
        } else if let yPrev {
            y + (y - yPrev) / 2
        } else {
            y + 8
        }

        let top = plotFrame.origin.y + min(topInPlot, bottomInPlot)
        let bottom = plotFrame.origin.y + max(topInPlot, bottomInPlot)
        return CGRect(x: plotFrame.origin.x, y: top, width: plotFrame.width, height: bottom - top)
    }

    private func updateSelection(
        location: CGPoint?,
        model: [ModelCostData],
        proxy: ChartProxy,
        geo: GeometryProxy)
    {
        guard let location else {
            if self.selectedModelID != nil { self.selectedModelID = nil }
            return
        }

        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location) else { return }

        let yInPlot = location.y - plotFrame.origin.y
        guard let modelName: String = proxy.value(atY: yInPlot) else { return }
        guard let nearest = self.nearestModelID(to: modelName, model: model) else { return }

        if self.selectedModelID != nearest {
            self.selectedModelID = nearest
        }
    }

    private func nearestModelID(to modelName: String, model: [ModelCostData]) -> String? {
        model.first { UsageFormatter.modelDisplayName($0.modelName) == modelName }?.id
    }

    private func detailLines(model: [ModelCostData]) -> (primary: String, secondary: String?) {
        guard let modelID = self.selectedModelID,
              let data = model.first(where: { $0.id == modelID })
        else {
            return ("Hover a bar for details", nil)
        }

        let displayName = UsageFormatter.modelDisplayName(data.modelName)
        let costPer1M = data.costPerToken * 1_000_000
        let primary = "\(displayName): \(UsageFormatter.usdString(costPer1M)) per 1M tokens"

        let relativeText = if data.relativeExpensiveness > 1.1 {
            String(format: "%.1fx more expensive than average", data.relativeExpensiveness)
        } else if data.relativeExpensiveness < 0.9 {
            String(format: "%.1fx cheaper than average", 1.0 / data.relativeExpensiveness)
        } else {
            "Close to average cost"
        }

        let tokens = UsageFormatter.tokenCountString(data.totalTokens)
        var secondary = "\(tokens) tokens · \(relativeText)"
        if let context = UsageFormatter.modelContextLabel(for: data.modelName) {
            secondary += " · \(context)"
        }

        return (primary, secondary)
    }
}
