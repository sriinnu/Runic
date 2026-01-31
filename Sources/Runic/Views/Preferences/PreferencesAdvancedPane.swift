import AppKit
import RunicCore
import KeyboardShortcuts
import SwiftUI

@MainActor
struct AdvancedPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var isInstallingCLI = false
    @State private var cliStatus: String?

    var body: some View {
        PreferencesPane {
            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Refresh cadence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Picker("", selection: self.$settings.refreshFrequency) {
                    ForEach(RefreshFrequency.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if self.settings.refreshFrequency == .manual {
                    Text("Auto-refresh is off; use the menu's Refresh command.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let badgeText = self.store.autoRefreshDisableBadgeText() {
                    Text(badgeText)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                }
                Text("Auto-refresh can switch to Manual when your Mac is idle or sleeps/locks. Adjust below.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Auto-refresh safety")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: self.$settings.autoDisableRefreshWhenIdleEnabled) {
                        Text("Switch to Manual when idle")
                            .font(.body)
                    }
                    .toggleStyle(.checkbox)

                    Text("If your Mac is idle for the threshold below, Runic switches auto-refresh to Manual.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

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

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: self.$settings.autoDisableRefreshOnSleepEnabled) {
                        Text("Switch to Manual on sleep/lock")
                            .font(.body)
                    }
                    .toggleStyle(.checkbox)

                    Text("When your Mac sleeps or locks, auto-refresh moves to Manual to avoid background checks.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: self.$settings.autoRefreshWarningEnabled) {
                        Text("Warn after repeated auto-refreshes")
                            .font(.body)
                    }
                    .toggleStyle(.checkbox)

                    Text("Sends a notification after the configured number of auto-refresh cycles.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

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

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: self.$settings.autoSuspendInactiveProvidersEnabled) {
                        Text("Skip inactive providers")
                            .font(.body)
                    }
                    .toggleStyle(.checkbox)

                    Text("Pauses auto-refresh for providers with no usage changes for the threshold below.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

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

                Text("Auto-refresh can read local logs or browser cookies depending on provider settings.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Auto-refresh also switches to Manual when your Mac sleeps or is locked.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                PreferenceToggleRow(
                    title: "Show usage as used",
                    subtitle: "Progress bars fill as you consume quota (instead of showing remaining).",
                    binding: self.$settings.usageBarsShowUsed)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Usage metrics")
                        .font(.body)
                    Picker("", selection: self.$settings.usageMetricDisplayMode) {
                        ForEach(UsageMetricDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Pick bars, percent, or both in the menu card.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PreferenceToggleRow(
                    title: "Show credits + extra usage",
                    subtitle: "Show Codex Credits and Claude Extra usage sections in the menu.",
                    binding: self.$settings.showOptionalCreditsAndExtraUsage)
                PreferenceToggleRow(
                    title: "Merge Icons",
                    subtitle: "Use a single menu bar icon with a provider switcher.",
                    binding: self.$settings.mergeIcons)
                PreferenceToggleRow(
                    title: "Switcher shows icons",
                    subtitle: "Show provider icons in the switcher (otherwise show a weekly progress line).",
                    binding: self.$settings.switcherShowsIcons)
                    .disabled(!self.settings.mergeIcons)
                    .opacity(self.settings.mergeIcons ? 1 : 0.5)
                PreferenceToggleRow(
                    title: "Menu bar shows percent",
                    subtitle: "Replace critter bars with provider branding icons and a percentage.",
                    binding: self.$settings.menuBarShowsBrandIconWithPercent)
                PreferenceToggleRow(
                    title: "Surprise me",
                    subtitle: "Check if you like your agents having some fun up there.",
                    binding: self.$settings.randomBlinkEnabled)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Insights")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                PreferenceStepperRow(
                    title: "Menu list size",
                    subtitle: "Limits insight rows shown in the menu before “More…”.",
                    step: 1,
                    range: 2...8,
                    valueLabel: { "\($0) items" },
                    value: self.$settings.insightsMenuMaxItems)
                PreferenceStepperRow(
                    title: "Report window",
                    subtitle: "Used when opening the Insights report.",
                    step: 1,
                    range: 1...30,
                    valueLabel: { "Last \($0) days" },
                    value: self.$settings.insightsReportDays)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Keyboard shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .center, spacing: 12) {
                    Text("Open menu")
                        .font(.body)
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .openMenu)
                }
                Text("Trigger the menu bar menu from anywhere.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                HStack(spacing: 12) {
                    Button {
                        Task { await self.installCLI() }
                    } label: {
                        if self.isInstallingCLI {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Install CLI")
                        }
                    }
                    .disabled(self.isInstallingCLI)

                    if let status = self.cliStatus {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
                Text("Symlink RunicCLI to /usr/local/bin and /opt/homebrew/bin as runic.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                PreferenceToggleRow(
                    title: "Show Debug Settings",
                    subtitle: "Expose troubleshooting tools in the Debug tab.",
                    binding: self.$settings.debugMenuEnabled)
            }
        }
    }

    private static func inactiveThresholdLabel(for minutes: Int) -> String {
        let inactiveMinutes = max(1, minutes)
        if inactiveMinutes % 60 == 0 {
            return "\(inactiveMinutes / 60) hr"
        }
        return "\(inactiveMinutes) min"
    }
}

extension AdvancedPane {
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
}
