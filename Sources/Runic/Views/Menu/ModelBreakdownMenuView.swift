import Charts
import RunicCore
import SwiftUI

@MainActor
struct ModelBreakdownMenuView: View {
    @Environment(\.runicFonts) private var fonts
    private let breakdown: [UsageLedgerModelSummary]
    private let width: CGFloat
    @State private var selectedModelID: String?
    @Environment(\.runicTheme) private var runicTheme

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
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            } else {
                let detail = self.detailText(model: model)

                // MARK: - Title

                Text("Models")
                    .font(self.fonts.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(self.runicTheme.primaryText)

                // MARK: - Donut chart

                Chart {
                    ForEach(model.chartItems) { item in
                        SectorMark(
                            angle: .value("Tokens", item.totalTokens),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.0)
                            .foregroundStyle(item.color)
                            .opacity(self.selectedModelID == nil || self.selectedModelID == item.id ? 1.0 : 0.42)
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 100)
                .help(detail)
                .chartOverlay { _ in
                    GeometryReader { geo in
                        MouseLocationReader { location in
                            self.updateSelection(location: location, model: model, geo: geo)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.chartAccessibilityLabel(model: model))

                Text(detail)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: 16, alignment: .leading)

                // MARK: - Model list

                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    ForEach(model.chartItems) { item in
                        Self.modelRow(item: item, theme: self.runicTheme)
                            .help(item.helpText(grandTotalTokens: model.grandTotalTokens))
                    }
                }

                // MARK: - Overflow note

                if model.overflowCount > 0 {
                    Text("and \(model.overflowCount) more")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                }

                // MARK: - Cache hit rate

                if let cacheRate = model.cacheHitRateText {
                    Divider()
                        .overlay(self.runicTheme.menuSeparatorColor)
                    HStack(spacing: RunicSpacing.xxs) {
                        Text("Cache hit rate")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                        Spacer(minLength: RunicSpacing.xxs)
                        Text(cacheRate)
                            .font(self.fonts.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(self.runicTheme.primaryText)
                    }
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

    private static func modelRow(item: ModelItem, theme: RunicThemePalette) -> some View {
        HStack(spacing: RunicSpacing.xxs) {
            Circle()
                .fill(item.color)
                .frame(width: RunicSpacing.chartLegendDot, height: RunicSpacing.chartLegendDot)
            Text(item.displayName)
                .font(RunicFont.caption)
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: RunicSpacing.xxs)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(UsageFormatter.tokenCountString(item.totalTokens)) tokens")
                    .font(RunicFont.caption2)
                    .foregroundStyle(theme.secondaryText)
                if let context = UsageFormatter.modelContextLabel(for: item.model) {
                    Text(context)
                        .font(RunicFont.caption2)
                        .foregroundStyle(theme.chartAxisLabelColor)
                }
                HStack(spacing: RunicSpacing.xxxs) {
                    Text("\(item.requestCount) req\(item.requestCount == 1 ? "" : "s")")
                        .font(RunicFont.caption2)
                        .foregroundStyle(theme.chartAxisLabelColor)
                    if let cost = item.costText {
                        Text(cost)
                            .font(RunicFont.caption2)
                            .foregroundStyle(theme.chartAxisLabelColor)
                    }
                }
            }
        }
    }

    private static func totalRow(model: ModelModel, theme: RunicThemePalette) -> some View {
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
                HStack(spacing: RunicSpacing.xxxs) {
                    Text("\(model.grandTotalRequests) requests")
                        .font(RunicFont.caption2)
                        .foregroundStyle(theme.chartAxisLabelColor)
                    if let cost = model.grandTotalCostText {
                        Text(cost)
                            .font(RunicFont.caption2)
                            .foregroundStyle(theme.chartAxisLabelColor)
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

        func helpText(grandTotalTokens: Int) -> String {
            let share = grandTotalTokens > 0
                ? Double(self.totalTokens) / Double(grandTotalTokens) * 100
                : 0
            var parts = [
                self.displayName,
                "\(UsageFormatter.tokenCountString(self.totalTokens)) tokens",
                "\(String(format: "%.0f", share))%",
                "\(self.requestCount) req",
            ]
            if let costText {
                parts.append(costText)
            }
            return parts.joined(separator: " · ")
        }
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

    private func updateSelection(location: CGPoint?, model: ModelModel, geo: GeometryProxy) {
        guard let location, model.grandTotalTokens > 0 else {
            if self.selectedModelID != nil { self.selectedModelID = nil }
            return
        }

        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radius = min(geo.size.width, geo.size.height) / 2
        let distance = sqrt(dx * dx + dy * dy)
        guard distance >= radius * 0.44, distance <= radius * 1.08 else {
            if self.selectedModelID != nil { self.selectedModelID = nil }
            return
        }

        var angle = atan2(dy, dx) + (.pi / 2)
        if angle < 0 { angle += .pi * 2 }
        let total = Double(model.grandTotalTokens)
        var cursor = 0.0
        for item in model.chartItems {
            cursor += Double(item.totalTokens) / total * (.pi * 2)
            if angle <= cursor {
                if self.selectedModelID != item.id {
                    self.selectedModelID = item.id
                }
                return
            }
        }
        self.selectedModelID = model.chartItems.last?.id
    }

    private func detailText(model: ModelModel) -> String {
        guard let selectedModelID = self.selectedModelID,
              let item = model.chartItems.first(where: { $0.id == selectedModelID })
        else {
            return "Hover the donut for distribution"
        }
        let share = model.grandTotalTokens > 0
            ? Double(item.totalTokens) / Double(model.grandTotalTokens) * 100
            : 0
        var parts = [
            "\(item.displayName)",
            "\(UsageFormatter.tokenCountString(item.totalTokens)) tokens",
            "\(String(format: "%.0f", share))%",
            "\(item.requestCount) req",
        ]
        if let cost = item.costText {
            parts.append(cost)
        }
        return parts.joined(separator: " · ")
    }

    static func makeModel(from breakdown: [UsageLedgerModelSummary]) -> ModelModel {
        let collapsed = self.collapsedSummaries(from: breakdown)
        let sorted = collapsed.sorted { lhs, rhs in
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

    private static func collapsedSummaries(from breakdown: [UsageLedgerModelSummary]) -> [UsageLedgerModelSummary] {
        var buckets: [String: ModelAccumulator] = [:]

        for summary in breakdown {
            let displayName = UsageFormatter.modelDisplayName(summary.model)
            let key = displayName
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            buckets[key, default: ModelAccumulator(summary: summary, displayName: displayName)]
                .consume(summary)
        }

        return buckets.values.map(\.summary)
    }

    private struct ModelAccumulator {
        private(set) var provider: UsageProvider
        private(set) var model: String
        private(set) var displayName: String
        private(set) var representativeTokens: Int
        private(set) var entryCount = 0
        private(set) var inputTokens = 0
        private(set) var outputTokens = 0
        private(set) var cacheCreationTokens = 0
        private(set) var cacheReadTokens = 0
        private(set) var costUSD: Double?

        init(summary: UsageLedgerModelSummary, displayName: String) {
            self.provider = summary.provider
            self.model = summary.model
            self.displayName = displayName
            self.representativeTokens = summary.totals.totalTokens
        }

        mutating func consume(_ summary: UsageLedgerModelSummary) {
            self.entryCount += summary.entryCount
            self.inputTokens += summary.totals.inputTokens
            self.outputTokens += summary.totals.outputTokens
            self.cacheCreationTokens += summary.totals.cacheCreationTokens
            self.cacheReadTokens += summary.totals.cacheReadTokens
            if let cost = summary.totals.costUSD {
                self.costUSD = (self.costUSD ?? 0) + cost
            }
            if summary.totals.totalTokens > self.representativeTokens {
                self.model = summary.model
                self.representativeTokens = summary.totals.totalTokens
            }
        }

        var summary: UsageLedgerModelSummary {
            UsageLedgerModelSummary(
                provider: self.provider,
                projectID: nil,
                model: self.model,
                entryCount: self.entryCount,
                totals: UsageLedgerTotals(
                    inputTokens: self.inputTokens,
                    outputTokens: self.outputTokens,
                    cacheCreationTokens: self.cacheCreationTokens,
                    cacheReadTokens: self.cacheReadTokens,
                    costUSD: self.costUSD))
        }
    }
}
