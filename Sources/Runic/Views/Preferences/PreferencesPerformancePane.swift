import AppKit
import RunicCore
import SwiftUI

@MainActor
struct PerformancePane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    @AppStorage("performanceTrackingEnabled") private var performanceTrackingEnabled = true
    @AppStorage("rawMetricsRetentionDays") private var rawMetricsRetentionDays = 30
    @AppStorage("aggregatedStatsRetentionYears") private var aggregatedStatsRetentionYears = 1
    @AppStorage("qualityRatingPromptsEnabled") private var qualityRatingPromptsEnabled = true
    @AppStorage("qualityRatingFrequency") private var qualityRatingFrequency = QualityRatingFrequency.every
    @AppStorage("maxPromptsPerHour") private var maxPromptsPerHour = 3
    @AppStorage("anonymousUsageStatsEnabled") private var anonymousUsageStatsEnabled = false

    @State private var databaseSize: String = "Calculating..."
    @State private var isVacuuming = false
    @State private var isClearingData = false
    @State private var vacuumStatus: String?
    @State private var clearDataStatus: String?
    @State private var appeared = false

    enum QualityRatingFrequency: String, CaseIterable, Identifiable {
        case every = "every"
        case over1000 = "over_1000"
        case over5000 = "over_5000"

        var id: String { self.rawValue }

        var label: String {
            switch self {
            case .every: return "After every response"
            case .over1000: return "Only >1000 tokens"
            case .over5000: return "Only >5000 tokens"
            }
        }
    }

    var body: some View {
        LiquidPreferencesPane {
            LiquidSection(title: "Performance Monitoring") {
                PreferenceToggleRow(
                    title: "Enable performance tracking",
                    subtitle: "Records latency, quality ratings, and error events for all AI requests.",
                    binding: self.$performanceTrackingEnabled)

                if !self.performanceTrackingEnabled {
                    Text("Performance tracking is disabled. Historical data is preserved but new metrics won't be collected.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.vertical, RunicSpacing.xs)
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 0)

            LiquidSection(title: "Data Retention") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Raw metrics retention")
                            .font(.body)

                        Picker("", selection: self.$rawMetricsRetentionDays) {
                            Text("30 days").tag(30)
                            Text("60 days").tag(60)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)

                        Text("How long to keep detailed latency and error records.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aggregated stats retention")
                            .font(.body)

                        Picker("", selection: self.$aggregatedStatsRetentionYears) {
                            Text("1 year").tag(1)
                            Text("2 years").tag(2)
                            Text("5 years").tag(5)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)

                        Text("How long to keep daily performance summaries.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 1)

            LiquidSection(title: "Quality Rating Prompts") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    PreferenceToggleRow(
                        title: "Show rating prompts",
                        subtitle: "Ask for quality ratings after AI responses to track model performance.",
                        binding: self.$qualityRatingPromptsEnabled)

                    if self.qualityRatingPromptsEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prompt frequency")
                                .font(.body)

                            Picker("", selection: self.$qualityRatingFrequency) {
                                ForEach(QualityRatingFrequency.allCases) { freq in
                                    Text(freq.label).tag(freq)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 400)

                            Text("When to show rating prompts based on response size.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }

                        PreferenceStepperRow(
                            title: "Max prompts per hour",
                            subtitle: "Limits how often rating prompts appear to avoid interruptions.",
                            step: 1,
                            range: 1...10,
                            valueLabel: { "\($0) prompts" },
                            value: self.$maxPromptsPerHour)
                    }
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 2)

            LiquidSection(title: "Database Management") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    HStack {
                        Text("Current database size:")
                            .font(.body)
                        Text(self.databaseSize)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: RunicSpacing.sm) {
                        Button {
                            self.vacuumDatabase()
                        } label: {
                            if self.isVacuuming {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, RunicSpacing.xxs)
                            }
                            Text("Vacuum Database")
                        }
                        .buttonStyle(.bordered)
                        .disabled(self.isVacuuming || self.isClearingData)

                        if let status = self.vacuumStatus {
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(status.contains("Success") ? .green : .red)
                        }
                    }

                    Text("Optimizes database file by reclaiming unused space.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)

                    Divider()
                        .padding(.vertical, RunicSpacing.xs)

                    HStack(spacing: RunicSpacing.sm) {
                        Button {
                            self.clearOldData()
                        } label: {
                            if self.isClearingData {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, RunicSpacing.xxs)
                            }
                            Text("Clear Old Data")
                        }
                        .buttonStyle(.bordered)
                        .disabled(self.isVacuuming || self.isClearingData)

                        if let status = self.clearDataStatus {
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(status.contains("Success") ? .green : .red)
                        }
                    }

                    Text("Removes metrics older than configured retention periods.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 3)

            LiquidSection(title: "Privacy") {
                PreferenceToggleRow(
                    title: "Share anonymous usage statistics",
                    subtitle: "Helps improve Runic by sharing aggregated performance metrics (no personal data).",
                    binding: self.$anonymousUsageStatsEnabled)

                if self.anonymousUsageStatsEnabled {
                    Text("Only aggregate statistics are shared. Request IDs, prompts, and responses are never included.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, RunicSpacing.xs)
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 4)
        }
        .onAppear {
            self.calculateDatabaseSize()
            guard !self.appeared else { return }
            withAnimation(.easeOut(duration: 0.6)) { self.appeared = true }
        }
    }

    private func calculateDatabaseSize() {
        Task {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            let dbPath = appSupport.appendingPathComponent("Runic/performance.db")

            if let attributes = try? FileManager.default.attributesOfItem(atPath: dbPath.path),
               let fileSize = attributes[.size] as? Int64
            {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB, .useGB]
                formatter.countStyle = .file
                self.databaseSize = formatter.string(fromByteCount: fileSize)
            } else {
                self.databaseSize = "0 KB"
            }
        }
    }

    private func vacuumDatabase() {
        guard !self.isVacuuming else { return }

        Task {
            self.isVacuuming = true
            self.vacuumStatus = "Optimizing..."

            do {
                let storage = PerformanceStorageImpl()
                try await storage.vacuum()
                self.vacuumStatus = "Success: Database optimized"
                self.calculateDatabaseSize()
            } catch {
                self.vacuumStatus = "Error: \(error.localizedDescription)"
            }

            self.isVacuuming = false

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.vacuumStatus = nil
        }
    }

    private func clearOldData() {
        guard !self.isClearingData else { return }

        Task {
            self.isClearingData = true
            self.clearDataStatus = "Clearing..."

            do {
                let storage = PerformanceStorageImpl()
                try await storage.deleteOldData(olderThan: self.rawMetricsRetentionDays)
                self.clearDataStatus = "Success: Old data removed"
                self.calculateDatabaseSize()
            } catch {
                self.clearDataStatus = "Error: \(error.localizedDescription)"
            }

            self.isClearingData = false

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.clearDataStatus = nil
        }
    }
}
