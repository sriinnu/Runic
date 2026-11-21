import AppKit
import RunicCore
import SwiftUI

@MainActor
struct PerformancePane: View {
    @Environment(\.runicFonts) private var fonts
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    var onSelectProvider: ((UsageProvider) -> Void)?
    @Environment(\.runicTheme) private var runicTheme

    @AppStorage("performanceTrackingEnabled") private var performanceTrackingEnabled = true
    @AppStorage("rawMetricsRetentionDays") private var rawMetricsRetentionDays = 30
    @AppStorage("aggregatedStatsRetentionYears") private var aggregatedStatsRetentionYears = 1

    @State private var databaseSize: String = "Calculating..."
    @State private var isVacuuming = false
    @State private var isClearingData = false
    @State private var vacuumStatus: String?
    @State private var clearDataStatus: String?
    @State private var diagnosticsStatus: String?
    @State private var guardrailStatus: String?

    var body: some View {
        LiquidPreferencesPane {
            SettingsGroupCard(
                title: "Provider Health & Diagnostics",
                caption: "Inspect active credentials, install default guardrails, or copy redacted diagnostics.")
            {
                RunicOperationsCenterView(
                    settings: self.settings,
                    store: self.store,
                    diagnosticsStatus: self.diagnosticsStatus,
                    guardrailStatus: self.guardrailStatus,
                    onCopyDiagnostics: self.copyDiagnostics,
                    onInstallGuardrails: self.installGuardrails,
                    onSelectProvider: self.onSelectProvider)
            }

            SettingsGroupCard(title: "Performance Monitoring") {
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
                }
            }

            SettingsGroupCard(title: "Local Cache & Retention") {
                Text("Provider JSONL logs are never deleted by Runic. Historical usage is " +
                    "summarized into a local ledger cache so old logs do not need to be rescanned every time.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Raw metrics retention")
                        .font(self.fonts.callout.weight(.medium))

                    RunicSegmentedPicker(
                        selection: self.$rawMetricsRetentionDays,
                        options: [(30, "30 days"), (60, "60 days"), (90, "90 days")])
                        .frame(maxWidth: 300)

                    Text("How long to keep detailed latency and error records.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Aggregated stats retention")
                        .font(self.fonts.callout.weight(.medium))

                    RunicSegmentedPicker(
                        selection: self.$aggregatedStatsRetentionYears,
                        options: [(1, "1 year"), (2, "2 years"), (5, "5 years")])
                        .frame(maxWidth: 300)

                    Text("How long to keep daily performance summaries.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }

                Text("Retention is applied automatically once a day; \"Clear Old Data\" below " +
                    "runs the same cleanup immediately.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsGroupCard(title: "Database Management") {
                HStack {
                    Text("Current database size:")
                        .font(self.fonts.callout.weight(.medium))
                    Text(self.databaseSize)
                        .font(self.fonts.callout.weight(.semibold))
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
                    .buttonStyle(.runicBordered)
                    .disabled(self.isVacuuming || self.isClearingData)

                    if let status = self.vacuumStatus {
                        Text(status)
                            .font(self.fonts.footnote)
                            .foregroundStyle(self.statusColor(for: status))
                    }
                }

                Text("Optimizes database file by reclaiming unused space.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)

                Divider()

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
                    .buttonStyle(.runicBordered)
                    .disabled(self.isVacuuming || self.isClearingData)

                    if let status = self.clearDataStatus {
                        Text(status)
                            .font(self.fonts.footnote)
                            .foregroundStyle(self.statusColor(for: status))
                    }
                }

                Text("Removes old local performance notes only. Provider JSONL logs and token ledgers are left alone.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsGroupCard(title: "Privacy") {
                Text("Runic does not collect analytics, crash reports, or anonymous usage stats.")
                    .font(self.fonts.callout.weight(.semibold))
                Text("Usage and performance history stay on this machine unless you export it, " +
                    "copy diagnostics, or configure a webhook. Your data, your tokens, your cost.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            self.calculateDatabaseSize()
        }
    }

    private func copyDiagnostics() {
        let report = RunicDiagnosticsReport.makeText(settings: self.settings, store: self.store)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        self.diagnosticsStatus = "Copied redacted diagnostics"
    }

    private func installGuardrails() {
        do {
            let count = try RunicDiagnosticsReport.installDefaultGuardrails()
            self.guardrailStatus = count == 0 ? "Guardrails already installed" : "Installed \(count) guardrails"
        } catch {
            self.guardrailStatus = "Failed: \(error.localizedDescription)"
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

    private func statusColor(for status: String) -> Color {
        if status.contains("Success") { return .green }
        if status.hasSuffix("...") { return self.runicTheme.secondaryText }
        return .red
    }
}
