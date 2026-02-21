import Charts
import RunicCore
import SwiftUI

@MainActor
struct UsageHeatmapMenuView: View {
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
    @State private var selectedCellID: String?

    init(hourlySummaries: [UsageLedgerHourlySummary], width: CGFloat) {
        self.hourlySummaries = hourlySummaries
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(from: self.hourlySummaries)
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            Text("Usage Heatmap (24×7)")
                .font(.headline)
                .fontWeight(.semibold)

            if model.isEmpty {
                Text("No heatmap data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        // Hour labels
                        HStack(spacing: 0) {
                            Text("")
                                .frame(width: 40, alignment: .leading)
                            ForEach(0..<24, id: \.self) { hour in
                                Text(self.hourLabel(hour))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .center)
                                    .lineLimit(1)
                            }
                        }

                        // Heatmap grid
                        ForEach(0..<7, id: \.self) { weekday in
                            HStack(spacing: 2) {
                                Text(self.weekdayLabel(weekday))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { level in
                                    Rectangle()
                                        .fill(Self.colorForIntensity(Double(level) / 4.0))
                                        .frame(width: 16, height: 16)
                                        .cornerRadius(RunicCornerRadius.xs)
                                }
                            }
                            Text("High")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, RunicSpacing.xs)
                    }
                    .padding(.horizontal, RunicSpacing.xxs)
                }
                .frame(height: 280)

                let detail = self.detailText(model: model)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    fileprivate static func colorForIntensity(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color(nsColor: .separatorColor).opacity(0.3)
        }
        if intensity < 0.25 {
            return Color(red: 0.46, green: 0.75, blue: 0.36).opacity(0.3)
        } else if intensity < 0.5 {
            return Color(red: 0.46, green: 0.75, blue: 0.36).opacity(0.6)
        } else if intensity < 0.75 {
            return Color(red: 0.94, green: 0.74, blue: 0.26).opacity(0.7)
        } else {
            return Color(red: 0.94, green: 0.36, blue: 0.36).opacity(0.8)
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

        return "\(cell.weekdayLabel) \(cell.hourLabel): \(UsageFormatter.tokenCountString(cell.totalTokens)) tokens"
    }
}

private struct HeatmapCellView: View {
    let cell: UsageHeatmapMenuView.HeatmapCell?
    let isSelected: Bool

    var body: some View {
        Group {
            if let cell {
                Rectangle()
                    .fill(UsageHeatmapMenuView.colorForIntensity(cell.intensity))
                    .overlay {
                        if self.isSelected {
                            Rectangle()
                                .strokeBorder(Color.blue, lineWidth: 2)
                        }
                    }
            } else {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.2))
            }
        }
        .frame(width: 38, height: 30)
        .cornerRadius(RunicCornerRadius.xs)
    }
}

