import AppKit
import KeyboardShortcuts
import RunicCore
import SwiftUI

@MainActor
struct AdvancedPane: View {
    @Environment(\.runicFonts) private var fonts
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var isInstallingCLI = false
    @State private var cliStatus: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        PreferencesPane {
            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Refresh cadence")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .textCase(.uppercase)
                Picker("", selection: self.$settings.refreshFrequency) {
                    ForEach(RefreshFrequency.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if self.settings.refreshFrequency == .manual {
                    Text("Auto-refresh is off; use the menu's Refresh command.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
                if let badgeText = self.store.autoRefreshDisableBadgeText() {
                    Text(badgeText)
                        .font(self.fonts.caption2.weight(.medium))
                        .padding(.horizontal, RunicSpacing.xs)
                        .padding(.vertical, RunicSpacing.xxs)
                        .background(Capsule(style: .continuous).fill(self.runicTheme.menuSubtleFill))
                        .overlay(Capsule(style: .continuous).stroke(self.runicTheme.menuSeparatorColor.opacity(0.55), lineWidth: 0.7))
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
                Text("Auto-refresh can switch to Manual when your Mac is idle or sleeps/locks. Adjust below.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Auto-refresh safety")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Toggle(isOn: self.$settings.autoDisableRefreshWhenIdleEnabled) {
                        Text("Switch to Manual when idle")
                            .font(self.fonts.body)
                    }
                    .toggleStyle(.checkbox)

                    Text("If your Mac is idle for the threshold below, Runic switches auto-refresh to Manual.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
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

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Toggle(isOn: self.$settings.autoDisableRefreshOnSleepEnabled) {
                        Text("Switch to Manual on sleep/lock")
                            .font(self.fonts.body)
                    }
                    .toggleStyle(.checkbox)

                    Text("When your Mac sleeps or locks, auto-refresh moves to Manual to avoid background checks.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Toggle(isOn: self.$settings.autoRefreshWarningEnabled) {
                        Text("Warn after repeated auto-refreshes")
                            .font(self.fonts.body)
                    }
                    .toggleStyle(.checkbox)

                    Text("Sends a notification after the configured number of auto-refresh cycles.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
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

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Toggle(isOn: self.$settings.autoSuspendInactiveProvidersEnabled) {
                        Text("Skip inactive providers")
                            .font(self.fonts.body)
                    }
                    .toggleStyle(.checkbox)

                    Text("Pauses auto-refresh for providers with no usage changes for the threshold below.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
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
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Auto-refresh also switches to Manual when your Mac sleeps or is locked.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Keyboard shortcut")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .textCase(.uppercase)
                HStack(alignment: .center, spacing: RunicSpacing.sm) {
                    Text("Open menu")
                        .font(self.fonts.body)
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .openMenu)
                }
                Text("Trigger the menu bar menu from anywhere.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                HStack(spacing: RunicSpacing.sm) {
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
                            .font(self.fonts.footnote)
                            .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                Text("Symlink RunicCLI to /usr/local/bin and /opt/homebrew/bin as runic.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
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
