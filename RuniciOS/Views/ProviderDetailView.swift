import SwiftUI
import RunicCore
import Charts

struct ProviderDetailView: View {
    let snapshot: EnhancedUsageSnapshot
    @EnvironmentObject var usageStore: iOSUsageStore
    @State private var selectedTimeRange: TimeRange = .day

    enum TimeRange: String, CaseIterable {
        case hour = "1H"
        case day = "24H"
        case week = "7D"
        case month = "30D"
    }

    var body: some View {
        List {
            // Header with current status
            Section {
                ProviderHeaderView(snapshot: snapshot)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Usage metrics
            Section("Usage Metrics") {
                UsageMetricsView(snapshot: snapshot)
            }

            // Reset information
            if let resetInfo = snapshot.primaryReset {
                Section("Reset Information") {
                    ResetInfoView(resetInfo: resetInfo)
                }
            }

            // Model usage
            if !snapshot.recentModels.isEmpty {
                Section("Recent Models") {
                    ForEach(snapshot.recentModels, id: \.modelName) { model in
                        ModelRowView(model: model)
                    }
                }
            }

            // Token usage
            if let tokenUsage = snapshot.tokenUsage {
                Section("Token Usage") {
                    TokenUsageView(tokenUsage: tokenUsage)
                }
            }

            // Project association
            if let project = snapshot.activeProject {
                Section("Active Project") {
                    ProjectInfoView(project: project)
                }
            }

            // Historical chart
            Section {
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                UsageChartView(
                    provider: snapshot.provider,
                    timeRange: selectedTimeRange
                )
                .frame(height: 200)
            } header: {
                Text("Usage History")
            }

            // Account info
            Section("Account") {
                LabeledContent("Type") {
                    AccountTypeBadge(type: snapshot.accountType)
                }

                if let email = snapshot.accountEmail {
                    LabeledContent("Email", value: email)
                }

                if let org = snapshot.accountOrganization {
                    LabeledContent("Organization", value: org)
                }

                LabeledContent("Data Source", value: snapshot.fetchSource)
            }
        }
        .navigationTitle(snapshot.provider.rawValue.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await usageStore.refresh(provider: snapshot.provider)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

// MARK: - Provider Header

struct ProviderHeaderView: View {
    let snapshot: EnhancedUsageSnapshot

    var statusColor: Color {
        let usage = snapshot.primary.usedPercent
        if usage >= 90 { return .red }
        if usage >= 75 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 20) {
            // Large usage indicator
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 12)

                Circle()
                    .trim(from: 0, to: snapshot.primary.usedPercent / 100)
                    .stroke(statusColor.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(snapshot.primary.usedPercent))%")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(statusColor)

                    Text("Used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)

            // Status message
            if snapshot.primary.usedPercent >= 90 {
                Text("⚠️ Approaching Limit")
                    .font(.headline)
                    .foregroundStyle(.red)
            } else if snapshot.primary.usedPercent >= 75 {
                Text("⚡ High Usage")
                    .font(.headline)
                    .foregroundStyle(.orange)
            } else {
                Text("✓ Healthy")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Usage Metrics

struct UsageMetricsView: View {
    let snapshot: EnhancedUsageSnapshot

    var body: some View {
        VStack(spacing: 12) {
            MetricRow(
                title: "Primary Usage",
                value: snapshot.primary.usedPercent,
                label: snapshot.primary.resetDescription ?? "Session"
            )

            if let secondary = snapshot.secondary {
                MetricRow(
                    title: "Weekly Usage",
                    value: secondary.usedPercent,
                    label: secondary.resetDescription ?? "Week"
                )
            }

            if let tertiary = snapshot.tertiary {
                MetricRow(
                    title: "Opus Usage",
                    value: tertiary.usedPercent,
                    label: tertiary.resetDescription ?? "Premium"
                )
            }
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: Double
    let label: String

    var color: Color {
        if value >= 90 { return .red }
        if value >= 75 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * value / 100)
                }
            }
            .frame(height: 8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Reset Info View

struct ResetInfoView: View {
    let resetInfo: UsageResetInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Reset Type") {
                Text(resetInfo.resetType.rawValue.capitalized)
            }

            if let timeRemaining = resetInfo.timeUntilReset, timeRemaining > 0 {
                LabeledContent("Resets In") {
                    Text(resetInfo.resetDescription)
                        .foregroundStyle(.blue)
                }
            }

            if let duration = resetInfo.windowDuration {
                let hours = Int(duration / 3600)
                LabeledContent("Window Duration") {
                    Text("\(hours) hours")
                }
            }
        }
    }
}

// MARK: - Account Type Badge

struct AccountTypeBadge: View {
    let type: AccountType

    var color: Color {
        switch type {
        case .subscription: return .purple
        case .usageBased: return .blue
        case .freeTier: return .green
        case .enterprise: return .orange
        case .unknown: return .gray
        }
    }

    var body: some View {
        Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        ProviderDetailView(
            snapshot: EnhancedUsageSnapshot(
                provider: .claude,
                primary: RateWindow(usedPercent: 85, windowMinutes: 300),
                accountType: .subscription,
                accountEmail: "user@example.com",
                primaryReset: UsageResetInfo(
                    resetType: .sessionBased,
                    resetAt: Date().addingTimeInterval(3600),
                    windowDuration: 5 * 3600
                )
            )
        )
    }
    .environmentObject(iOSUsageStore())
}
