import AppKit
import Charts
import RunicCore
import SwiftUI

/// Overview dashboard showing all enabled providers at a glance.
/// Inspired by Apple Activity app rings, Awwwards dashboard layouts, and Tokex stat cards.
@MainActor
struct OverviewMenuView: View {
    struct ProviderSummary: Identifiable {
        let id: String
        let provider: UsageProvider
        let name: String
        let icon: NSImage?
        let usedPercent: Double
        let todayTokens: Int
        let brandColor: Color
        let resetDescription: String?
        let windowLabel: String? // e.g. "5h" or "Weekly"
        let topModelContext: String? // e.g. "200K ctx"
    }

    struct DailyPoint: Identifiable {
        let id: String
        let date: Date
        let tokens: Int
        let provider: String
        let color: Color
    }

    let summaries: [ProviderSummary]
    let chartPoints: [DailyPoint]
    let totalTodayTokens: Int
    let totalProviders: Int
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            // MARK: - Hero header

            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                // Ring indicator showing overall usage
                ZStack {
                    Circle()
                        .stroke(Color(nsColor: .separatorColor).opacity(0.15), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: min(1, self.averageUsedPercent / 100))
                        .stroke(
                            AngularGradient(
                                colors: [RunicColors.chartColor(at: 4), RunicColors.chartColor(at: 0)],
                                center: .center),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 0) {
                    Text(UsageFormatter.tokenCountString(self.totalTodayTokens))
                        .font(RunicFont.system(size: 22, weight: .bold))
                    Text("\(self.summaries.count) of \(self.totalProviders) active")
                        .font(RunicFont.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("today")
                        .font(RunicFont.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(Int(self.averageUsedPercent))% avg")
                        .font(RunicFont.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            Divider().opacity(0.5)

            // MARK: - Provider cards

            if self.summaries.isEmpty {
                Text("No active providers.")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, RunicSpacing.md)
            } else {
                VStack(spacing: RunicSpacing.compact) {
                    ForEach(self.summaries) { summary in
                        ProviderRow(summary: summary)
                    }
                }
            }

            // MARK: - Combined 7-day chart

            if !self.chartPoints.isEmpty {
                Divider().opacity(0.5)

                HStack {
                    Text("7-day activity")
                        .font(RunicFont.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    // Mini legend dots
                    HStack(spacing: RunicSpacing.xxs) {
                        ForEach(self.summaries.prefix(4)) { s in
                            Circle()
                                .fill(s.brandColor)
                                .frame(width: 5, height: 5)
                        }
                        if self.summaries.count > 4 {
                            Text("+\(self.summaries.count - 4)")
                                .font(RunicFont.system(size: 8))
                                .foregroundStyle(.quaternary)
                        }
                    }
                }

                Chart {
                    ForEach(self.chartPoints) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Tokens", point.tokens))
                            .foregroundStyle(by: .value("Provider", point.provider))
                            .cornerRadius(2)
                    }
                }
                .chartForegroundStyleScale(range: self.chartColors)
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3, 3]))
                            .foregroundStyle(Color(nsColor: .separatorColor).opacity(0.3))
                        AxisValueLabel {
                            if let tokens = value.as(Int.self) {
                                Text(UsageFormatter.tokenCountString(tokens))
                                    .font(RunicFont.system(size: 8))
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(RunicFont.system(size: 8, weight: .medium))
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .frame(height: 80)
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.sm)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private var averageUsedPercent: Double {
        let active = self.summaries.filter { $0.usedPercent > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + $1.usedPercent } / Double(active.count)
    }

    private var chartColors: [Color] {
        self.summaries.map(\.brandColor)
    }
}

// MARK: - Provider row

private struct ProviderRow: View {
    let summary: OverviewMenuView.ProviderSummary

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
            // Icon with brand tint
            if let icon = self.summary.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
            }

            // Name
            Text(self.summary.name)
                .font(RunicFont.caption)
                .fontWeight(.medium)
                .frame(width: 58, alignment: .leading)
                .lineLimit(1)

            // Progress bar with gradient fill
            GeometryReader { geo in
                let fillWidth = max(0, geo.size.width * min(1, self.summary.usedPercent / 100))
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color(nsColor: .separatorColor).opacity(0.12))

                    // Fill with gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    self.summary.brandColor.opacity(0.9),
                                    self.summary.brandColor,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing))
                        .frame(width: fillWidth)

                    // Gloss overlay on fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.2), location: 0),
                                    .init(color: .clear, location: 0.5),
                                ],
                                startPoint: .top,
                                endPoint: .bottom))
                        .frame(width: fillWidth)
                }
            }
            .frame(height: 7)

            // Percentage
            Text("\(Int(self.summary.usedPercent))%")
                .font(RunicFont.system(size: 9, weight: .semibold))
                .foregroundStyle(self.summary.usedPercent > 80 ? .primary : .secondary)
                .frame(width: 28, alignment: .trailing)

            // Today's tokens (if any)
            if self.summary.todayTokens > 0 {
                Text(UsageFormatter.tokenCountString(self.summary.todayTokens))
                    .font(RunicFont.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .frame(width: 32, alignment: .trailing)
            }
        }

        // Second line: window + reset + context
        let hasSecondLine = self.summary.windowLabel != nil ||
            self.summary.resetDescription != nil ||
            self.summary.topModelContext != nil

        if hasSecondLine {
            HStack(spacing: RunicSpacing.xxs) {
                // Spacer for icon + name width
                Color.clear.frame(width: 14 + 58 + RunicSpacing.xs * 2, height: 0)

                if let window = self.summary.windowLabel {
                    InfoPill(text: window)
                }
                if let reset = self.summary.resetDescription {
                    InfoPill(text: reset)
                }
                if let ctx = self.summary.topModelContext {
                    InfoPill(text: ctx)
                }
                Spacer()
            }
        }
    }
}

private struct InfoPill: View {
    let text: String

    var body: some View {
        Text(self.text)
            .font(RunicFont.system(size: 8, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(RunicColors.Opacity.subtle)))
    }
}
