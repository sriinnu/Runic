import AppKit
import RunicCore
import SwiftUI

/// Menu view displaying active alerts with severity indicators and acknowledgement
@MainActor
struct AlertsMenuView: View {
    @Environment(\.runicFonts) private var fonts

    // MARK: - Types

    typealias AlertEntry = AlertRuleStore.AlertHistoryEntry
    typealias Severity = AlertRuleStore.AlertSeverity

    // MARK: - State

    @State private var alerts: [AlertEntry] = []
    @State private var isRefreshing = false
    private let width: CGFloat
    private let dateStyle: UsageFormatter.DateStyle
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

    // MARK: - Initialization

    init(width: CGFloat = 320, dateStyle: UsageFormatter.DateStyle = .relative) {
        self.width = width
        self.dateStyle = dateStyle
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.sectionSpacing) {
            self.headerSection

            if self.alerts.isEmpty {
                self.emptyStateView
            } else {
                self.alertsList
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, MenuCardMetrics.sectionTopPadding)
        .frame(width: self.width, alignment: .leading)
        .task {
            await self.loadAlerts()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Alerts")
                .font(self.fonts.headline)
                .fontWeight(.semibold)

            if self.unacknowledgedCount > 0 {
                self.unacknowledgedBadge
            }

            Spacer()

            if self.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
            } else {
                Button {
                    Task { await self.loadAlerts() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh alerts")
            }
        }
    }

    private var unacknowledgedBadge: some View {
        Text("\(self.unacknowledgedCount)")
            .font(self.fonts.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, RunicSpacing.compact)
            .padding(.vertical, RunicSpacing.xxxs)
            .background(Capsule().fill(self.runicTheme.warm))
            .accessibilityLabel(
                "\(self.unacknowledgedCount) unacknowledged alert\(self.unacknowledgedCount == 1 ? "" : "s")")
    }

    private var unacknowledgedCount: Int {
        self.alerts.count(where: { !$0.acknowledged })
    }

    // MARK: - Alerts List

    private var alertsList: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
            ForEach(self.alerts) { alert in
                AlertRow(alert: alert, dateStyle: self.dateStyle) {
                    await self.acknowledgeAlert(alert.id)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        RunicEmptyStateView(
            mood: .zen,
            title: "All quiet",
            hint: "No alerts triggered.")
            .padding(.vertical, RunicSpacing.xxs)
    }

    // MARK: - Data Loading

    private func loadAlerts() async {
        self.isRefreshing = true

        // Simulate async delay for UI smoothness
        try? await Task.sleep(for: .milliseconds(100))

        // Load alerts from storage
        self.alerts = AlertRuleStore.getRecentHistory(limit: 20)

        self.isRefreshing = false
    }

    private func acknowledgeAlert(_ id: String) async {
        do {
            try AlertRuleStore.acknowledgeAlert(id: id)
            await self.loadAlerts()
        } catch {
            print("[AlertsMenuView] Failed to acknowledge alert: \(error)")
        }
    }

    private var secondaryTextColor: Color {
        self.isHighlighted ? MenuHighlightStyle.selectionText : self.runicTheme.secondaryText
    }
}

// MARK: - Alert Row

private struct AlertRow: View {
    @Environment(\.runicFonts) private var fonts
    let alert: AlertsMenuView.AlertEntry
    let dateStyle: UsageFormatter.DateStyle
    let onAcknowledge: () async -> Void

    @State private var isAcknowledging = false
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: RunicSpacing.xs) {
            self.severityIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(self.alert.message)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.primaryTextColor)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(self.timeAgo(from: self.alert.triggeredAt))
                    .font(self.fonts.caption2)
                    .foregroundStyle(self.secondaryTextColor)
            }

            Spacer()

            if !self.alert.acknowledged {
                self.acknowledgeButton
            }
        }
        .padding(RunicSpacing.xs)
        .background(self.backgroundStyle)
        .overlay(self.glowStroke)
        .clipShape(RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm)))
    }

    /// Glass/Dark glow stroke around unacknowledged alerts — accent halo
    /// makes severity feel kinetic. Other themes get nothing (clean).
    private var glowStroke: some View {
        let active = !self.alert.acknowledged && self.runicTheme.shape.separator == .glow
        return RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm))
            .strokeBorder(active ? self.severityColor.opacity(0.55) : .clear, lineWidth: active ? 1.2 : 0)
            .shadow(color: active ? self.severityColor.opacity(0.40) : .clear, radius: active ? 5 : 0)
    }

    private var severityIcon: some View {
        let icon = self.severityIconName
        let color = self.severityColor

        return Image(systemName: icon)
            .font(self.fonts.caption)
            .foregroundStyle(color)
            .frame(width: 16, alignment: .center)
    }

    private var severityIconName: String {
        switch self.alert.severity {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        }
    }

    private var severityColor: Color {
        switch self.alert.severity {
        case .info: self.runicTheme.tertiary
        case .warning: self.runicTheme.highlight
        case .critical: self.runicTheme.warm
        }
    }

    private var backgroundStyle: some View {
        self.alert.acknowledged
            ? self.runicTheme.menuSubtleFill.opacity(0.55)
            : self.runicTheme.menuSubtleFill
    }

    private var acknowledgeButton: some View {
        Button {
            Task {
                self.isAcknowledging = true
                await self.onAcknowledge()
                self.isAcknowledging = false
            }
        } label: {
            if self.isAcknowledging {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.secondaryTextColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(self.isAcknowledging)
        .accessibilityLabel("Acknowledge alert")
    }

    private func timeAgo(from date: Date) -> String {
        let now = Date()
        // Honor the app-wide date-format preference: absolute renders a
        // timestamp, relative keeps the compact "5m ago" phrasing.
        if self.dateStyle == .absolute {
            return UsageFormatter.absoluteTimestampString(from: date, now: now)
        }
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    private var primaryTextColor: Color {
        self.isHighlighted ? MenuHighlightStyle.selectionText : self.runicTheme.primaryText
    }

    private var secondaryTextColor: Color {
        self.isHighlighted ? MenuHighlightStyle.selectionText : self.runicTheme.secondaryText
    }
}
