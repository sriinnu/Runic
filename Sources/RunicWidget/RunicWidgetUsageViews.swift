import RunicCore
import SwiftUI

struct SmallUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HeaderView(provider: self.entry.provider, updatedAt: self.entry.updatedAt)
            WindowUsageRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.sessionLabel ?? "Session",
                window: self.entry.primary,
                color: WidgetColors.color(for: self.entry.provider))
            WindowUsageRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.weeklyLabel ?? "Weekly",
                window: self.entry.secondary,
                color: WidgetColors.color(for: self.entry.provider))
            if let codeReview = entry.codeReviewRemainingPercent {
                UsageBarRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    color: WidgetColors.color(for: self.entry.provider))
            }
        }
        .padding(12)
    }
}

struct MediumUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeaderView(provider: self.entry.provider, updatedAt: self.entry.updatedAt)
            WindowUsageRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.sessionLabel ?? "Session",
                window: self.entry.primary,
                color: WidgetColors.color(for: self.entry.provider))
            WindowUsageRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.weeklyLabel ?? "Weekly",
                window: self.entry.secondary,
                color: WidgetColors.color(for: self.entry.provider))
            if let credits = entry.creditsRemaining {
                ValueLine(title: "Credits", value: WidgetFormat.credits(credits))
            }
            if let token = entry.tokenUsage {
                ValueLine(
                    title: "Today",
                    value: WidgetFormat.costAndTokens(cost: token.sessionCostUSD, tokens: token.sessionTokens))
            }
        }
        .padding(12)
    }
}

struct LargeUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(provider: self.entry.provider, updatedAt: self.entry.updatedAt)
            WindowUsageRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.sessionLabel ?? "Session",
                window: self.entry.primary,
                color: WidgetColors.color(for: self.entry.provider))
            WindowUsageRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.weeklyLabel ?? "Weekly",
                window: self.entry.secondary,
                color: WidgetColors.color(for: self.entry.provider))
            if let codeReview = entry.codeReviewRemainingPercent {
                UsageBarRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    color: WidgetColors.color(for: self.entry.provider))
            }
            if let credits = entry.creditsRemaining {
                ValueLine(title: "Credits", value: WidgetFormat.credits(credits))
            }
            if let token = entry.tokenUsage {
                VStack(alignment: .leading, spacing: 4) {
                    ValueLine(
                        title: "Today",
                        value: WidgetFormat.costAndTokens(cost: token.sessionCostUSD, tokens: token.sessionTokens))
                    ValueLine(
                        title: "30d",
                        value: WidgetFormat.costAndTokens(
                            cost: token.last30DaysCostUSD,
                            tokens: token.last30DaysTokens))
                }
            }
            UsageHistoryChart(points: self.entry.dailyUsage, color: WidgetColors.color(for: self.entry.provider))
                .frame(height: 50)
        }
        .padding(12)
    }
}

struct HistoryView: View {
    let entry: WidgetSnapshot.ProviderEntry
    let isLarge: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(provider: self.entry.provider, updatedAt: self.entry.updatedAt)
            UsageHistoryChart(points: self.entry.dailyUsage, color: WidgetColors.color(for: self.entry.provider))
                .frame(height: self.isLarge ? 90 : 60)
            if let token = entry.tokenUsage {
                ValueLine(
                    title: "Today",
                    value: WidgetFormat.costAndTokens(cost: token.sessionCostUSD, tokens: token.sessionTokens))
                ValueLine(
                    title: "30d",
                    value: WidgetFormat.costAndTokens(cost: token.last30DaysCostUSD, tokens: token.last30DaysTokens))
            }
        }
        .padding(12)
    }
}

struct HeaderView: View {
    let provider: UsageProvider
    let updatedAt: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(ProviderDefaults.metadata[self.provider]?.displayName ?? self.provider.rawValue.capitalized)
                .font(.body)
                .fontWeight(.semibold)
            Spacer()
            Text(WidgetFormat.relativeDate(self.updatedAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Renders a quota bar for a rate window, or falls back to the window's
/// summary text when the window has no real limit (`hasKnownLimit == false`)
/// so providers without quotas never show a fake gauge.
struct WindowUsageRow: View {
    let title: String
    let window: RateWindow?
    let color: Color

    var body: some View {
        if let window, window.hasKnownLimit == false {
            if let summary = window.resetDescription ?? window.label {
                ValueLine(title: self.title, value: summary)
            }
        } else {
            UsageBarRow(title: self.title, percentLeft: self.window?.remainingPercent, color: self.color)
        }
    }
}

struct UsageBarRow: View {
    let title: String
    let percentLeft: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(self.title)
                    .font(.caption)
                Spacer()
                Text(WidgetFormat.percent(self.percentLeft))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                let width = max(0, min(1, (percentLeft ?? 0) / 100)) * proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(self.color).frame(width: width)
                }
            }
            .frame(height: 6)
        }
    }
}

struct ValueLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(self.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(self.value)
                .font(.caption)
        }
    }
}

struct UsageHistoryChart: View {
    let points: [WidgetSnapshot.DailyUsagePoint]
    let color: Color

    var body: some View {
        let values = self.points.map { point -> Double in
            if let cost = point.costUSD { return cost }
            return Double(point.totalTokens ?? 0)
        }
        let maxValue = values.max() ?? 0
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(values.indices, id: \.self) { index in
                let value = values[index]
                let height = maxValue > 0 ? CGFloat(value / maxValue) : 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(self.color.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: 1, y: height, anchor: .bottom)
                    .animation(.easeOut(duration: 0.2), value: height)
            }
        }
    }
}
