import Charts
import RunicCore
import SwiftUI

/// Burn panel: the actual quota curve inside the current cycle against the
/// even-burn budget line, a "now" rule, and dashed projections from the
/// last 1h and 6h rates to their run-out points. The headline says how far
/// ahead or behind budget the window is and when it runs out.
@MainActor
struct QuotaBurnChartMenuView: View {
    struct WindowSeries: Identifiable, Equatable {
        let id: String
        let title: String
        let series: QuotaBurnSeries
    }

    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @State private var selectedID: String?

    let windows: [WindowSeries]
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Burn")
                    .font(self.fonts.sectionTitle)
                Spacer()
                if let series = self.selected?.series {
                    Text(Self.sampleSummary(series))
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }

            if self.windows.count > 1 {
                RunicSegmentedPicker(
                    selection: Binding(
                        get: { self.selected?.id ?? "" },
                        set: { self.selectedID = $0 }),
                    options: self.windows.map { ($0.id, $0.title) })
            }

            if let window = self.selected {
                self.headline(for: window.series)
                self.chart(for: window.series)
                    .frame(height: RunicSpacing.chartHeight + 24)
                self.legend(for: window.series)
            } else {
                Text("No quota history yet. A few refreshes and the curve appears.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(height: 80)
            }
        }
        .frame(width: self.width, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quota burn")
    }

    private var selected: WindowSeries? {
        self.windows.first { $0.id == self.selectedID } ?? self.windows.first
    }

    // MARK: - Headline

    private func headline(for series: QuotaBurnSeries) -> some View {
        let delta = series.paceDeltaPercent
        let paceText: String
        let paceColor: Color
        if series.currentUsedPercent >= 99.5 {
            paceText = "Exhausted"
            paceColor = self.runicTheme.warm
        } else if abs(delta) < 2 {
            paceText = "On budget"
            paceColor = self.runicTheme.tertiary
        } else if delta > 0 {
            paceText = "Ahead of budget by \(Int(delta.rounded()))%"
            paceColor = delta > 15 ? self.runicTheme.warm : self.runicTheme.highlight
        } else {
            paceText = "Under budget by \(Int((-delta).rounded()))%"
            paceColor = self.runicTheme.tertiary
        }
        return VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
            HStack(alignment: .firstTextBaseline, spacing: RunicSpacing.xs) {
                Text(paceText)
                    .font(self.fonts.footnote.weight(.semibold))
                    .foregroundStyle(paceColor)
                Spacer()
                Text("\(Int(series.currentUsedPercent.rounded()))% used")
                    .font(self.fonts.numericFootnote.weight(.semibold))
                    .monospacedDigit()
            }
            Text(Self.runOutText(series))
                .font(self.fonts.caption2)
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    nonisolated static func runOutText(_ series: QuotaBurnSeries) -> String {
        let resetText = UsageFormatter.resetExpiryString(from: series.resetsAt, now: series.now)
        if series.currentUsedPercent >= 99.5 {
            let countdown = UsageFormatter.resetCountdownDescription(from: series.resetsAt, now: series.now)
            return "Exhausted · resets \(resetText) (\(countdown))"
        }
        let measured = series.projections.filter { $0.measuredSpan >= QuotaBurnSeries.minimumProjectionSpan }
        guard let longest = measured.last else {
            return "Resets \(resetText) · projections need a little more history"
        }
        let label = Self.horizonLabel(longest.horizon)
        if let runsOut = longest.runsOutAt {
            let when = UsageFormatter.resetExpiryString(from: runsOut, now: series.now)
            let countdown = UsageFormatter.resetCountdownDescription(from: runsOut, now: series.now)
            return "Runs out \(when) (\(countdown)) at the \(label) rate · resets \(resetText)"
        }
        if longest.ratePercentPerHour <= 0.01 {
            return "Idle at the \(label) rate · resets \(resetText)"
        }
        return "Lasts to the reset at the \(label) rate · resets \(resetText)"
    }

    nonisolated static func sampleSummary(_ series: QuotaBurnSeries) -> String {
        let count = series.points.count
        let last = series.points.last?.at ?? series.now
        return "\(count) samples · last \(last.formatted(date: .omitted, time: .shortened))"
    }

    nonisolated static func horizonLabel(_ horizon: TimeInterval) -> String {
        let hours = Int((horizon / 3600).rounded())
        return "\(hours)h"
    }

    // MARK: - Chart

    private func chart(for series: QuotaBurnSeries) -> some View {
        let actualColor = self.runicTheme.chartColor(at: 0)
        let budgetColor = self.runicTheme.highlight
        let isTerminal = self.runicTheme.isTerminalHUD
        return Chart {
            // Even-burn budget: 0 at window start, 100 at reset.
            LineMark(
                x: .value("Time", series.windowStart),
                y: .value("Budget", 0),
                series: .value("Series", "budget"))
                .foregroundStyle(budgetColor.opacity(0.9))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
            LineMark(
                x: .value("Time", series.resetsAt),
                y: .value("Budget", 100),
                series: .value("Series", "budget"))
                .foregroundStyle(budgetColor.opacity(0.9))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))

            // Actual readings as a step curve with a faint fill.
            ForEach(Array(series.points.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Time", point.at),
                    y: .value("Used", point.usedPercent),
                    series: .value("Series", "actual"))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [actualColor.opacity(isTerminal ? 0.18 : 0.28), actualColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom))
                    .interpolationMethod(.stepEnd)
                LineMark(
                    x: .value("Time", point.at),
                    y: .value("Used", point.usedPercent),
                    series: .value("Series", "actual"))
                    .foregroundStyle(actualColor)
                    .lineStyle(StrokeStyle(lineWidth: isTerminal ? 1.4 : 2))
                    .interpolationMethod(.stepEnd)
            }

            // Projections from the last 1h / 6h rate to their run-out.
            ForEach(Array(series.projections.enumerated()), id: \.offset) { index, projection in
                if let runsOut = projection.runsOutAt {
                    let dash: [CGFloat] = index == 0 ? [2, 3] : [6, 4]
                    LineMark(
                        x: .value("Time", series.now),
                        y: .value("Used", series.currentUsedPercent),
                        series: .value("Series", "proj-\(index)"))
                        .foregroundStyle(self.runicTheme.warm.opacity(index == 0 ? 0.55 : 0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: dash))
                    LineMark(
                        x: .value("Time", runsOut),
                        y: .value("Used", 100),
                        series: .value("Series", "proj-\(index)"))
                        .foregroundStyle(self.runicTheme.warm.opacity(index == 0 ? 0.55 : 0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: dash))
                    PointMark(x: .value("Time", runsOut), y: .value("Used", 100))
                        .foregroundStyle(self.runicTheme.warm)
                        .symbolSize(index == 0 ? 18 : 28)
                }
            }

            // Now.
            RuleMark(x: .value("Time", series.now))
                .foregroundStyle(self.runicTheme.primaryText.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [1, 2]))
                .annotation(position: .top, alignment: .leading) {
                    Text("now")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            PointMark(x: .value("Time", series.now), y: .value("Used", series.currentUsedPercent))
                .foregroundStyle(actualColor)
                .symbolSize(40)
        }
        .chartXScale(domain: series.windowStart...series.resetsAt)
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine().foregroundStyle(self.runicTheme.chartGridColor)
                AxisValueLabel {
                    if let percent = value.as(Int.self) {
                        Text("\(percent)%")
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: Self.axisDates(for: series)) { value in
                AxisGridLine().foregroundStyle(self.runicTheme.chartGridColor)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Self.axisLabel(date, series: series))
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Quota burn, \(Int(series.currentUsedPercent.rounded())) percent used, \(Self.runOutText(series))")
    }

    private func legend(for series: QuotaBurnSeries) -> some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
            HStack(spacing: RunicSpacing.sm) {
                self.legendItem(color: self.runicTheme.chartColor(at: 0), text: "actual", dashed: false)
                self.legendItem(color: self.runicTheme.highlight, text: "even burn to reset", dashed: true)
                Spacer()
            }
            HStack(spacing: RunicSpacing.sm) {
                ForEach(Array(series.projections.enumerated()), id: \.offset) { index, projection in
                    if projection.measuredSpan >= QuotaBurnSeries.minimumProjectionSpan {
                        self.legendItem(
                            color: self.runicTheme.warm.opacity(index == 0 ? 0.6 : 0.9),
                            text: "last \(Self.horizonLabel(projection.horizon)): \(Self.rateText(projection))",
                            dashed: true)
                    }
                }
                Spacer()
            }
        }
    }

    private static func rateText(_ projection: QuotaBurnSeries.Projection) -> String {
        let rate = projection.ratePercentPerHour
        if rate < 0.05 { return "idle" }
        return rate < 1 ? String(format: "%.1f%%/h", rate) : "\(Int(rate.rounded()))%/h"
    }

    private func legendItem(color: Color, text: String, dashed: Bool) -> some View {
        HStack(spacing: RunicSpacing.xxs) {
            HStack(spacing: 2) {
                if dashed {
                    Rectangle().fill(color).frame(width: 4, height: 1.5)
                    Rectangle().fill(color).frame(width: 4, height: 1.5)
                } else {
                    Rectangle().fill(color).frame(width: 12, height: 2.5)
                }
            }
            Text(text)
                .font(self.fonts.caption2)
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(1)
        }
    }

    // MARK: - Axis

    /// Window start, reset, and clean intermediate ticks: hourly up to 8h,
    /// every 6h up to 36h, otherwise each day boundary. The last tick before
    /// the reset is dropped if it would sit on the reset mark.
    static func axisDates(for series: QuotaBurnSeries) -> [Date] {
        var dates: [Date] = [series.windowStart]
        let duration = series.windowDuration
        let calendar = Calendar.current
        if duration <= 36 * 3600 {
            let step: TimeInterval = duration <= 8 * 3600 ? 3600 : 6 * 3600
            var tick = series.windowStart.addingTimeInterval(step)
            while tick < series.resetsAt.addingTimeInterval(-step * 0.6) {
                dates.append(tick)
                tick = tick.addingTimeInterval(step)
            }
        } else {
            var tick = calendar.startOfDay(for: series.windowStart.addingTimeInterval(86400))
            while tick < series.resetsAt.addingTimeInterval(-6 * 3600) {
                dates.append(tick)
                tick = tick.addingTimeInterval(86400)
            }
        }
        dates.append(series.resetsAt)
        return dates
    }

    static func axisLabel(_ date: Date, series: QuotaBurnSeries) -> String {
        if abs(date.timeIntervalSince(series.resetsAt)) < 60 {
            return "↻"
        }
        if series.windowDuration <= 36 * 3600 {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}
