import AppKit
import RunicCore
import SwiftUI

@MainActor
struct PerformancePane: View {
    @Environment(\.runicFonts) private var fonts
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @Environment(\.runicTheme) private var runicTheme

    @AppStorage("performanceTrackingEnabled") private var performanceTrackingEnabled = true
    @AppStorage("rawMetricsRetentionDays") private var rawMetricsRetentionDays = 30
    @AppStorage("aggregatedStatsRetentionYears") private var aggregatedStatsRetentionYears = 1

    @State private var databaseSize: String = "Calculating..."
    @State private var isVacuuming = false
    @State private var isClearingData = false
    @State private var vacuumStatus: String?
    @State private var clearDataStatus: String?
    @State private var appeared = false

    var body: some View {
        LiquidPreferencesPane {
            LiquidSection(title: "Performance Monitoring") {
                PreferenceToggleRow(
                    title: "Enable local performance notes",
                    subtitle: "Stores latency, quality ratings, and error events locally on this Mac.",
                    binding: self.$performanceTrackingEnabled)

                if !self.performanceTrackingEnabled {
                    Text(
                        "Performance tracking is disabled. Historical data is preserved, " +
                            "but new metrics won't be collected.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(.orange)
                        .padding(.vertical, RunicSpacing.xs)
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 0)

            LiquidSection(title: "Local Cache & Retention") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    Text("Provider JSONL logs are never deleted by Runic. Historical usage is " +
                        "summarized into a local ledger cache so old logs do not need to be rescanned every time.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Raw metrics retention")
                            .font(self.fonts.body)

                        Picker("", selection: self.$rawMetricsRetentionDays) {
                            Text("30 days").tag(30)
                            Text("60 days").tag(60)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)

                        Text("How long to keep detailed latency and error records.")
                            .font(self.fonts.footnote)
                            .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aggregated stats retention")
                            .font(self.fonts.body)

                        Picker("", selection: self.$aggregatedStatsRetentionYears) {
                            Text("1 year").tag(1)
                            Text("2 years").tag(2)
                            Text("5 years").tag(5)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)

                        Text("How long to keep daily performance summaries.")
                            .font(self.fonts.footnote)
                            .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                    }

                    Text("Retention is applied automatically once a day; \"Clear Old Data\" below " +
                        "runs the same cleanup immediately.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 1)

            LiquidSection(title: "Database Management") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    HStack {
                        Text("Current database size:")
                            .font(self.fonts.body)
                        Text(self.databaseSize)
                            .font(self.fonts.body.weight(.semibold))
                            .foregroundStyle(self.runicTheme.secondaryText)
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
                                .font(self.fonts.footnote)
                                .foregroundStyle(status.contains("Success") ? .green : .red)
                        }
                    }

                    Text("Optimizes database file by reclaiming unused space.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))

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
                                .font(self.fonts.footnote)
                                .foregroundStyle(status.contains("Success") ? .green : .red)
                        }
                    }

                    Text("Removes old local performance notes only. Provider JSONL logs and token " +
                        "ledgers are left alone.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 2)

            LiquidSection(title: "Privacy") {
                Text("Runic does not collect analytics, crash reports, or anonymous usage stats.")
                    .font(self.fonts.body.weight(.semibold))
                Text("Usage and performance history stay on this machine unless you export it, " +
                    "copy diagnostics, or configure a webhook. Your data, your tokens, your cost.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .liquidEntrance(appeared: self.appeared, index: 3)
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
                in: .userDomainMask).first!
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
                try await storage.deleteOldData(
                    olderThan: self.rawMetricsRetentionDays,
                    aggregatedStatsOlderThanYears: self.aggregatedStatsRetentionYears)
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
