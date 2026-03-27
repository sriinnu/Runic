import Charts
import SwiftUI

@MainActor
struct TeamDashboardView: View {
    let team: Team
    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedMemberID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RunicSpacing.lg) {
                self.headerSection

                PreferencesDivider()

                self.usageOverviewSection

                PreferencesDivider()

                self.memberBreakdownSection

                PreferencesDivider()

                self.recentActivitySection
            }
            .padding(RunicSpacing.lg)
        }
        .runicTypography()
        .frame(width: 700, height: 600)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    Text(self.team.name)
                        .font(RunicFont.title.weight(.bold))
                    Text("\(self.team.members.count) member\(self.team.members.count == 1 ? "" : "s")")
                        .font(RunicFont.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Period", selection: self.$selectedPeriod) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
        }
    }

    private var usageOverviewSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.md) {
            Text("Usage Overview")
                .font(RunicFont.headline)

            HStack(spacing: RunicSpacing.lg) {
                self.statCard(
                    title: "Total Quota",
                    value: "\(self.team.totalQuota)",
                    subtitle: "credits",
                    icon: "chart.bar.fill",
                    color: .blue)

                self.statCard(
                    title: "Used",
                    value: "\(self.team.usedQuota)",
                    subtitle: "credits",
                    icon: "arrow.up.circle.fill",
                    color: .orange)

                self.statCard(
                    title: "Available",
                    value: "\(self.team.totalQuota - self.team.usedQuota)",
                    subtitle: "credits",
                    icon: "circle.fill",
                    color: .green)

                self.statCard(
                    title: "Usage",
                    value: String(format: "%.1f%%", self.team.usagePercent),
                    subtitle: "of quota",
                    icon: "percent",
                    color: self.team.usageColor)
            }

            UsageProgressBar(
                percent: self.team.usagePercent,
                tint: self.team.usageColor,
                accessibilityLabel: "Team quota usage",
                height: .large)
        }
    }

    private var memberBreakdownSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.md) {
            Text("Member Usage Breakdown")
                .font(RunicFont.headline)

            let data = self.memberUsageData

            if data.isEmpty {
                Text("No usage data available")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, RunicSpacing.xl)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Member", item.memberName),
                        y: .value("Usage", item.usage))
                        .foregroundStyle(
                            self.selectedMemberID == item.memberID
                                ? item.color.opacity(0.8)
                                : item.color.opacity(0.5))
                        .annotation(position: .top) {
                            if item.usage > 0 {
                                Text("\(item.usage, specifier: "%d")")
                                    .font(RunicFont.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let name = value.as(String.self) {
                                Text(name)
                                    .font(RunicFont.caption)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue / 1000)K")
                                    .font(RunicFont.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                self.handleChartTap(location: location, proxy: proxy, geo: geo, data: data)
                            }
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)],
                    alignment: .leading,
                    spacing: RunicSpacing.xs)
                {
                    ForEach(data) { item in
                        HStack(spacing: RunicSpacing.xs) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.memberName)
                                .font(RunicFont.caption)
                                .foregroundStyle(
                                    self.selectedMemberID == item.memberID
                                        ? .primary
                                        : .secondary)
                            Spacer()
                            Text("\(item.usage, specifier: "%d")")
                                .font(RunicFont.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, RunicSpacing.xs)
                        .padding(.vertical, RunicSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    self.selectedMemberID == item.memberID
                                        ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3)
                                        : Color.clear))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if self.selectedMemberID == item.memberID {
                                self.selectedMemberID = nil
                            } else {
                                self.selectedMemberID = item.memberID
                            }
                        }
                    }
                }
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.md) {
            Text("Recent Activity")
                .font(RunicFont.headline)

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                ForEach(self.recentActivities) { activity in
                    HStack(spacing: RunicSpacing.sm) {
                        Image(systemName: activity.icon)
                            .font(RunicFont.body)
                            .foregroundStyle(activity.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                            Text(activity.title)
                                .font(RunicFont.footnote)
                            Text(activity.timestamp)
                                .font(RunicFont.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, RunicSpacing.sm)
                    .padding(.vertical, RunicSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5)))
                }
            }
        }
    }

    private func statCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        color: Color) -> some View
    {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(RunicFont.caption)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(RunicFont.title2.weight(.bold))
                .foregroundStyle(color)

            Text(title)
                .font(RunicFont.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(RunicFont.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RunicSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var memberUsageData: [MemberUsageItem] {
        self.team.members.map { member in
            MemberUsageItem(
                memberID: member.id,
                memberName: member.name,
                usage: member.usedQuota,
                color: member.avatarColor)
        }
    }

    private var recentActivities: [ActivityItem] {
        [
            ActivityItem(
                id: "1",
                title: "Alice Johnson used 2,500 credits",
                timestamp: "2 hours ago",
                icon: "arrow.up.circle.fill",
                color: Color(nsColor: .systemOrange)),
            ActivityItem(
                id: "2",
                title: "Bob Smith joined the team",
                timestamp: "5 hours ago",
                icon: "person.badge.plus.fill",
                color: Color(nsColor: .systemGreen)),
            ActivityItem(
                id: "3",
                title: "Quota increased to 100,000 credits",
                timestamp: "1 day ago",
                icon: "chart.line.uptrend.xyaxis",
                color: Color(nsColor: .systemBlue)),
            ActivityItem(
                id: "4",
                title: "Charlie Davis invited Diana Williams",
                timestamp: "2 days ago",
                icon: "envelope.fill",
                color: Color(nsColor: .systemPurple)),
        ]
    }

    private func handleChartTap(
        location: CGPoint,
        proxy: ChartProxy,
        geo: GeometryProxy,
        data: [MemberUsageItem])
    {
        guard let plotFrame = proxy.plotFrame.map({ geo[$0] }) else { return }
        guard plotFrame.contains(location) else { return }

        let xPosition = location.x - plotFrame.origin.x
        guard let memberName: String = proxy.value(atX: xPosition) else { return }

        if let member = data.first(where: { $0.memberName == memberName }) {
            if self.selectedMemberID == member.memberID {
                self.selectedMemberID = nil
            } else {
                self.selectedMemberID = member.memberID
            }
        }
    }
}

// MARK: - Models

enum TimePeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String {
        self.rawValue
    }

    var displayName: String {
        switch self {
        case .day: "Today"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

struct MemberUsageItem: Identifiable {
    let memberID: String
    let memberName: String
    let usage: Int
    let color: Color

    var id: String {
        self.memberID
    }
}

struct ActivityItem: Identifiable {
    let id: String
    let title: String
    let timestamp: String
    let icon: String
    let color: Color
}
