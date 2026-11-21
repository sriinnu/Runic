import AppKit
import KeyboardShortcuts
import RunicCore
import SwiftUI

@MainActor
struct GeneralPane: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var launchAtLoginStatus: String?
    @State private var isInstallingCLI = false
    @State private var cliStatus: String?

    var body: some View {
        LiquidPreferencesPane {
            SettingsGroupCard(title: "Startup & Shortcut") {
                PreferenceToggleRow(
                    title: "Start at Login",
                    subtitle: "Open Runic when your Mac starts.",
                    binding: self.launchAtLoginBinding)

                if let launchAtLoginStatus = self.launchAtLoginStatus {
                    Text(launchAtLoginStatus)
                        .font(self.fonts.footnote)
                        .foregroundStyle(.orange)
                }

                Divider()

                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    HStack(alignment: .center, spacing: RunicSpacing.sm) {
                        Text("Open menu")
                            .font(self.fonts.callout.weight(.medium))
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .openMenu)
                    }
                    Text("Trigger the menu bar menu from anywhere.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }

            SettingsGroupCard(title: "Refresh & Safety") {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Refresh cadence")
                        .font(self.fonts.callout.weight(.medium))

                    RunicSegmentedPicker(
                        selection: self.$settings.refreshFrequency,
                        cases: RefreshFrequency.allCases,
                        label: \.label)

                    if self.settings.refreshFrequency == .manual {
                        Text("Auto-refresh is off; use the menu's Refresh command.")
                            .font(self.fonts.footnote)
                            .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    }

                    if let badgeText = self.store.autoRefreshDisableBadgeText() {
                        Text(badgeText)
                            .font(self.fonts.caption2.weight(.medium))
                            .padding(.horizontal, RunicSpacing.xs)
                            .padding(.vertical, RunicSpacing.xxs)
                            .background(Capsule(style: .continuous).fill(self.runicTheme.menuSubtleFill))
                            .overlay(Capsule(style: .continuous).stroke(
                                self.runicTheme.menuSeparatorColor.opacity(0.55),
                                lineWidth: 0.7))
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }

                    Text("Auto-refresh pauses during sleep or lock and can switch to Manual below.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    PreferenceToggleRow(
                        title: "Switch to Manual when idle",
                        subtitle: "If your Mac is idle for the threshold below, Runic switches auto-refresh to Manual.",
                        binding: self.$settings.autoDisableRefreshWhenIdleEnabled)

                    PreferenceStepperRow(
                        title: "Idle threshold",
                        subtitle: nil,
                        step: 1,
                        range: 1...60,
                        valueLabel: { "\($0) min" },
                        value: self.$settings.autoDisableRefreshWhenIdleMinutes)
                        .disabled(!self.settings.autoDisableRefreshWhenIdleEnabled)
                        .opacity(self.settings.autoDisableRefreshWhenIdleEnabled ? 1 : 0.5)
                }

                PreferenceToggleRow(
                    title: "Switch to Manual on sleep/lock",
                    subtitle: "When your Mac sleeps or locks, auto-refresh moves to Manual to avoid background checks.",
                    binding: self.$settings.autoDisableRefreshOnSleepEnabled)

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    PreferenceToggleRow(
                        title: "Warn after repeated auto-refreshes",
                        subtitle: "Sends a notification after the configured number of auto-refresh cycles.",
                        binding: self.$settings.autoRefreshWarningEnabled)

                    PreferenceStepperRow(
                        title: "Warning threshold",
                        subtitle: nil,
                        step: 1,
                        range: 5...100,
                        valueLabel: { "\($0) runs" },
                        value: self.$settings.autoRefreshWarningThreshold)
                        .disabled(!self.settings.autoRefreshWarningEnabled)
                        .opacity(self.settings.autoRefreshWarningEnabled ? 1 : 0.5)
                }

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    PreferenceToggleRow(
                        title: "Skip inactive providers",
                        subtitle: "Pauses auto-refresh for providers with no usage changes for the threshold below.",
                        binding: self.$settings.autoSuspendInactiveProvidersEnabled)

                    PreferenceStepperRow(
                        title: "Inactive threshold",
                        subtitle: nil,
                        step: 30,
                        range: 30...10080,
                        valueLabel: { Self.inactiveThresholdLabel(for: $0) },
                        value: self.$settings.autoSuspendInactiveProvidersMinutes)
                        .disabled(!self.settings.autoSuspendInactiveProvidersEnabled)
                        .opacity(self.settings.autoSuspendInactiveProvidersEnabled ? 1 : 0.5)
                }
            }

            SettingsGroupCard(title: "Usage, Status & Notifications") {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    PreferenceToggleRow(
                        title: "Show cost summary",
                        subtitle: "Shows local cost totals in Analyst and Operator menu modes.",
                        binding: self.$settings.costUsageEnabled)

                    if self.settings.costUsageEnabled {
                        Text("Auto-refresh: hourly · Timeout: 10m")
                            .font(self.fonts.footnote)
                            .foregroundStyle(self.runicTheme.subduedSecondaryText)
                        self.costStatusLine(provider: .claude)
                        self.costStatusLine(provider: .codex)
                    }
                }

                PreferenceToggleRow(
                    title: "Check provider status",
                    subtitle: "Polls provider status pages for active incidents.",
                    binding: self.$settings.statusChecksEnabled)

                PreferenceToggleRow(
                    title: "Session quota notifications",
                    subtitle: "Notifies when your 5-hour session quota depletes or resets.",
                    binding: self.$settings.sessionQuotaNotificationsEnabled)
            }

            SettingsGroupCard(title: "CLI & Configuration") {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    HStack(spacing: RunicSpacing.sm) {
                        Button {
                            Task { await self.installCLI() }
                        } label: {
                            if self.isInstallingCLI {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Install CLI", systemImage: "terminal")
                            }
                        }
                        .buttonStyle(.runicBordered)
                        .disabled(self.isInstallingCLI)

                        if let status = self.cliStatus {
                            Text(status)
                                .font(self.fonts.footnote)
                                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                                .lineLimit(2)
                        }
                    }

                    Text("Symlinks RunicCLI to /usr/local/bin or /opt/homebrew/bin as runic.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }

                Divider()

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Config file")
                        .font(self.fonts.callout.weight(.medium))

                    Text(
                        "Provider endpoint URLs and log paths live in one JSON file that Runic watches. " +
                            "Edit it and changes apply instantly — no rebuild, no restart.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(RunicConfigStore.storageURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                        .textSelection(.enabled)

                    HStack(spacing: RunicSpacing.sm) {
                        Button {
                            RunicConfigStore.openInEditor()
                        } label: {
                            Label("Open Config", systemImage: "doc.text")
                        }
                        .buttonStyle(.runicBordered)

                        Button {
                            RunicConfigStore.revealInFinder()
                        } label: {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        .buttonStyle(.runicBordered)

                        Button {
                            self.reloadConfig()
                        } label: {
                            Label("Reload Now", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.runicBordered)
                    }

                    Text(self.configStatusLine)
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }
        }
        .onAppear {
            self.settings.launchAtLogin = LaunchAtLoginManager.isEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            self.settings.launchAtLogin = LaunchAtLoginManager.isEnabled()
        }
    }

    private var configStatusLine: String {
        let count = self.store.appliedConfig.activeOverrideCount
        let overrides = count == 1 ? "1 override active" : "\(count) overrides active"
        return "Watching for changes · \(overrides)"
    }

    private func reloadConfig() {
        Task { @MainActor in
            await self.store.configChanged(RunicConfigStore.load())
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { self.settings.launchAtLogin },
            set: { enabled in
                self.launchAtLoginStatus = self.settings.setLaunchAtLoginFromPreferences(enabled)
                    ? nil : "macOS did not apply this change. Check System Settings > Login Items."
            })
    }

    private static func inactiveThresholdLabel(for minutes: Int) -> String {
        let inactiveMinutes = max(1, minutes)
        if inactiveMinutes % 60 == 0 {
            return "\(inactiveMinutes / 60) hr"
        }
        return "\(inactiveMinutes) min"
    }

    private func installCLI() async {
        if self.isInstallingCLI { return }
        self.isInstallingCLI = true
        defer { self.isInstallingCLI = false }

        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/RunicCLI")
        let fm = FileManager.default
        guard fm.fileExists(atPath: helperURL.path) else {
            self.cliStatus = "RunicCLI not found in app bundle."
            return
        }

        let destinations = [
            "/usr/local/bin/runic",
            "/opt/homebrew/bin/runic",
        ]

        var results: [String] = []
        for dest in destinations {
            let dir = (dest as NSString).deletingLastPathComponent
            guard fm.fileExists(atPath: dir) else { continue }
            guard fm.isWritableFile(atPath: dir) else {
                results.append("No write access: \(dir)")
                continue
            }

            if fm.fileExists(atPath: dest) {
                if Self.isLink(atPath: dest, pointingTo: helperURL.path) {
                    results.append("Installed: \(dir)")
                } else {
                    results.append("Exists: \(dir)")
                }
                continue
            }

            do {
                try fm.createSymbolicLink(atPath: dest, withDestinationPath: helperURL.path)
                results.append("Installed: \(dir)")
            } catch {
                results.append("Failed: \(dir)")
            }
        }

        self.cliStatus = results.isEmpty
            ? "No writable bin dirs found."
            : results.joined(separator: " · ")
    }

    private static func isLink(atPath path: String, pointingTo destination: String) -> Bool {
        guard let link = try? FileManager.default.destinationOfSymbolicLink(atPath: path) else { return false }
        let dir = (path as NSString).deletingLastPathComponent
        let resolved = URL(fileURLWithPath: link, relativeTo: URL(fileURLWithPath: dir))
            .standardizedFileURL
            .path
        return resolved == destination
    }

    private func costStatusLine(provider: UsageProvider) -> some View {
        let name = ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName

        guard provider == .claude || provider == .codex else {
            return Text("\(name): unsupported")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
        }

        if self.store.isTokenRefreshInFlight(for: provider) {
            let elapsed: String = {
                guard let startedAt = self.store.tokenLastAttemptAt(for: provider) else { return "" }
                let seconds = max(0, Date().timeIntervalSince(startedAt))
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = seconds < 60 ? [.second] : [.minute, .second]
                formatter.unitsStyle = .abbreviated
                return formatter.string(from: seconds).map { " (\($0))" } ?? ""
            }()
            return Text("\(name): fetching…\(elapsed)")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
        }
        if let snapshot = self.store.tokenSnapshot(for: provider) {
            let updated = UsageFormatter.updatedString(
                from: snapshot.updatedAt,
                style: self.settings.dateFormat.formatterStyle)
            let cost = snapshot.last30DaysCostUSD.map { UsageFormatter.usdString($0) } ?? "—"
            return Text("\(name): \(updated) · 30d \(cost)")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
        }
        if let error = self.store.tokenError(for: provider), !error.isEmpty {
            let truncated = UsageFormatter.truncatedSingleLine(error, max: 120)
            return Text("\(name): \(truncated)")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
        }
        if let lastAttempt = self.store.tokenLastAttemptAt(for: provider) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .abbreviated
            let when = rel.localizedString(for: lastAttempt, relativeTo: Date())
            return Text("\(name): last attempt \(when)")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
        }
        return Text("\(name): no data yet")
            .font(self.fonts.footnote)
            .foregroundStyle(self.runicTheme.subduedSecondaryText)
    }
}
