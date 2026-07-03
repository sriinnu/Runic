import Charts
import RunicCore
import SwiftUI

@MainActor
struct UsageHeatmapMenuView: View {
    @Environment(\.runicFonts) private var fonts
    fileprivate struct HeatmapCell: Identifiable {
        let id: String
        let hourStart: Date
        let weekday: Int // 0 = Sunday, 6 = Saturday
        let hour: Int // 0-23
        let totalTokens: Int
        let intensity: Double // 0.0-1.0

        init(hourStart: Date, weekday: Int, hour: Int, totalTokens: Int, maxTokens: Int) {
            self.hourStart = hourStart
            self.weekday = weekday
            self.hour = hour
            self.totalTokens = totalTokens
            self.intensity = maxTokens > 0 ? Double(totalTokens) / Double(maxTokens) : 0.0
            self.id = "\(weekday)-\(hour)"
        }

        var weekdayLabel: String {
            ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][self.weekday]
        }

        var hourLabel: String {
            if self.hour == 0 { return "12 AM" }
            if self.hour < 12 { return "\(self.hour) AM" }
            if self.hour == 12 { return "12 PM" }
            return "\(self.hour - 12) PM"
        }
    }

    private let hourlySummaries: [UsageLedgerHourlySummary]
    private let width: CGFloat
    private let numberStyle: UsageFormatter.NumberStyle
    @State private var selectedCellID: String?
    @Environment(\.runicTheme) private var runicTheme

    init(
        hourlySummaries: [UsageLedgerHourlySummary],
        width: CGFloat,
        numberStyle: UsageFormatter.NumberStyle = .abbreviated)
    {
        self.hourlySummaries = hourlySummaries
        self.width = width
        self.numberStyle = numberStyle
    }

    var body: some View {
        let model = Self.makeModel(from: self.hourlySummaries)
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            Text("Usage Heatmap (24×7)")
                .font(self.fonts.headline)
                .fontWeight(.semibold)

            if model.isEmpty {
                RunicEmptyStateView(
                    mood: .searching,
                    title: "No heatmap data.",
                    hint: "Hourly activity paints this grid over time.")
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        // Hour labels
                        HStack(spacing: 0) {
                            Text("")
                                .frame(width: 40, alignment: .leading)
                            ForEach(0..<24, id: \.self) { hour in
                                Text(self.hourLabel(hour))
                                    .font(self.fonts.caption2)
                                    .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                                    .frame(width: 40, alignment: .center)
                                    .lineLimit(1)
                            }
                        }

                        // Heatmap grid
                        ForEach(0..<7, id: \.self) { weekday in
                            HStack(spacing: 2) {
                                Text(self.weekdayLabel(weekday))
                                    .font(self.fonts.caption)
                                    .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                                    .frame(width: 38, alignment: .leading)

                                ForEach(0..<24, id: \.self) { hour in
                                    let cell = model.first { $0.weekday == weekday && $0.hour == hour }
                                    HeatmapCellView(
                                        cell: cell,
                                        isSelected: self.selectedCellID == cell?.id)
                                        .onTapGesture {
                                            self.selectedCellID = cell?.id
                                        }
                                        .onHover { hovering in
                                            if hovering {
                                                self.selectedCellID = cell?.id
                                            } else if self.selectedCellID == cell?.id {
                                                self.selectedCellID = nil
                                            }
                                        }
                                }
                            }
                        }

                        // Legend
                        HStack(spacing: RunicSpacing.xs) {
                            Text("Low")
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText)
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { level in
                                    Rectangle()
                                        .fill(Self.colorForIntensity(Double(level) / 4.0, theme: self.runicTheme))
                                        .frame(width: 16, height: 16)
                                        .cornerRadius(self.runicTheme.shape.cornerRadius(RunicCornerRadius.xs))
                                }
                            }
                            Text("High")
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }
                        .padding(.top, RunicSpacing.xs)
                    }
                    .padding(.horizontal, RunicSpacing.xxs)
                }
                .frame(height: 280)

                let detail = self.detailText(model: model)
                Text(detail)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .leading)
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private static func makeModel(from summaries: [UsageLedgerHourlySummary]) -> [HeatmapCell] {
        let calendar = Calendar.current
        var buckets: [String: Int] = [:]
        var maxTokens = 0

        for summary in summaries {
            let weekday = calendar.component(.weekday, from: summary.hourStart) - 1 // Convert to 0-6
            let hour = calendar.component(.hour, from: summary.hourStart)
            let key = "\(weekday)-\(hour)"
            buckets[key, default: 0] += summary.totals.totalTokens
            maxTokens = max(maxTokens, buckets[key]!)
        }

        var cells: [HeatmapCell] = []
        for weekday in 0..<7 {
            for hour in 0..<24 {
                let key = "\(weekday)-\(hour)"
                let totalTokens = buckets[key] ?? 0
                // Use a reference date for the hour start (doesn't matter for display)
                let hourStart = calendar.date(from: DateComponents(hour: hour)) ?? Date()
                cells.append(HeatmapCell(
                    hourStart: hourStart,
                    weekday: weekday,
                    hour: hour,
                    totalTokens: totalTokens,
                    maxTokens: maxTokens))
            }
        }

        return cells
    }

    fileprivate static func colorForIntensity(_ intensity: Double, theme: RunicThemePalette) -> Color {
        if intensity == 0 {
            return theme.menuTrackColor.opacity(0.6)
        }
        if intensity < 0.25 {
            return theme.tertiary.opacity(0.32)
        } else if intensity < 0.5 {
            return theme.tertiary.opacity(0.62)
        } else if intensity < 0.75 {
            return theme.highlight.opacity(0.76)
        } else {
            return theme.warm.opacity(0.86)
        }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][weekday]
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    private func detailText(model: [HeatmapCell]) -> String {
        guard let cellID = self.selectedCellID,
              let cell = model.first(where: { $0.id == cellID })
        else {
            return "Hover a cell for details"
        }

        if cell.totalTokens == 0 {
            return "\(cell.weekdayLabel) \(cell.hourLabel): No usage"
        }

        let count = UsageFormatter.tokenCountString(cell.totalTokens, style: self.numberStyle)
        return "\(cell.weekdayLabel) \(cell.hourLabel): \(count) tokens"
    }
}

private struct HeatmapCellView: View {
    let cell: UsageHeatmapMenuView.HeatmapCell?
    let isSelected: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Group {
            if let cell {
                Rectangle()
                    .fill(UsageHeatmapMenuView.colorForIntensity(cell.intensity, theme: self.runicTheme))
                    .overlay {
                        if self.isSelected {
                            Rectangle()
                                .strokeBorder(self.runicTheme.accent, lineWidth: 2)
                        }
                    }
            } else {
                Rectangle()
                    .fill(self.runicTheme.menuTrackColor.opacity(0.45))
            }
        }
        .frame(width: 38, height: 30)
        .cornerRadius(self.runicTheme.shape.cornerRadius(RunicCornerRadius.xs))
    }
}
