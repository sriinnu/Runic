import AppKit
import RunicCore
import SwiftUI

/// Menu view displaying active alerts with severity indicators and acknowledgement
@MainActor
struct AlertsMenuView: View {

    // MARK: - Types

    typealias AlertEntry = AlertRuleStore.AlertHistoryEntry
    typealias Severity = AlertRuleStore.AlertSeverity

    // MARK: - State

    @State private var alerts: [AlertEntry] = []
    @State private var isRefreshing = false
    private let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    // MARK: - Initialization

    init(width: CGFloat = 320) {
        self.width = width
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
                .font(RunicFont.headline)
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
                        .font(RunicFont.caption)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh alerts")
            }
        }
    }

    private var unacknowledgedBadge: some View {
        Text("\(self.unacknowledgedCount)")
            .font(RunicFont.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, RunicSpacing.compact)
            .padding(.vertical, RunicSpacing.xxxs)
            .background(Capsule().fill(Color.red))
            .accessibilityLabel("\(self.unacknowledgedCount) unacknowledged alert\(self.unacknowledgedCount == 1 ? "" : "s")")
    }

    private var unacknowledgedCount: Int {
        self.alerts.filter { !$0.acknowledged }.count
    }

    // MARK: - Alerts List

    private var alertsList: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
            ForEach(self.alerts) { alert in
                AlertRow(alert: alert) {
                    await self.acknowledgeAlert(alert.id)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: RunicSpacing.xs) {
            Image(systemName: "checkmark.shield")
                .font(RunicFont.title2)
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))

            Text("No active alerts")
                .font(RunicFont.subheadline)
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RunicSpacing.sm)
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
}

// MARK: - Alert Row

private struct AlertRow: View {
    let alert: AlertsMenuView.AlertEntry
    let onAcknowledge: () async -> Void

    @State private var isAcknowledging = false
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        HStack(alignment: .top, spacing: RunicSpacing.xs) {
            self.severityIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(self.alert.message)
                    .font(RunicFont.footnote)
                    .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(self.timeAgo(from: self.alert.triggeredAt))
                    .font(RunicFont.caption2)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }

            Spacer()

            if !self.alert.acknowledged {
                self.acknowledgeButton
            }
        }
        .padding(RunicSpacing.xs)
        .background(self.backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: RunicCornerRadius.sm))
    }

    private var severityIcon: some View {
        let icon = self.severityIconName
        let color = self.severityColor

        return Image(systemName: icon)
            .font(RunicFont.caption)
            .foregroundStyle(color)
            .frame(width: 16, alignment: .center)
    }

    private var severityIconName: String {
        switch self.alert.severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var severityColor: Color {
        switch self.alert.severity {
        case .info: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    private var backgroundStyle: some View {
        let baseColor = self.alert.acknowledged
            ? Color(nsColor: .controlBackgroundColor).opacity(0.5)
            : Color(nsColor: .controlBackgroundColor)

        return baseColor
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
                    .font(RunicFont.caption)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
        }
        .buttonStyle(.plain)
        .disabled(self.isAcknowledging)
        .accessibilityLabel("Acknowledge alert")
    }

    private func timeAgo(from date: Date) -> String {
        let now = Date()
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
}
