import AppKit
import RunicCore
import SwiftUI

@MainActor
struct GeneralPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    var body: some View {
        PreferencesPane {
            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("System")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                PreferenceToggleRow(
                    title: "Start at Login",
                    subtitle: "Automatically opens Runic when you start your Mac.",
                    binding: self.$settings.launchAtLogin)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: self.$settings.costUsageEnabled) {
                            Text("Show cost summary")
                                .font(.body)
                        }
                        .toggleStyle(.checkbox)

                        Text("Reads local usage logs. Shows today + last 30 days cost in the menu.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)

                        if self.settings.costUsageEnabled {
                            Text("Auto-refresh: hourly · Timeout: 10m")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)

                            self.costStatusLine(provider: .claude)
                            self.costStatusLine(provider: .codex)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: self.$settings.openAIWebAccessEnabled) {
                            Text("Access OpenAI via web")
                                .font(.body)
                        }
                        .toggleStyle(.checkbox)

                        Text("Imports browser cookies for dashboard extras (credits history, code review).")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                PreferenceToggleRow(
                    title: "Check provider status",
                    subtitle: "Polls OpenAI/Claude status pages and Google Workspace for " +
                        "Gemini/Antigravity, surfacing incidents in the icon and menu.",
                    binding: self.$settings.statusChecksEnabled)
                PreferenceToggleRow(
                    title: "Vibrant menu bar icon",
                    subtitle: "Uses a data-reactive color ramp to show usage pressure at a glance.",
                    binding: self.$settings.menuBarVibrantIconEnabled)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Notifications")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                PreferenceToggleRow(
                    title: "Session quota notifications",
                    subtitle: "Notifies when the 5-hour session quota hits 0% and when it becomes " +
                        "available again.",
                    binding: self.$settings.sessionQuotaNotificationsEnabled)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                HStack {
                    Spacer()
                    Button("Quit Runic") { NSApp.terminate(nil) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }

    private func costStatusLine(provider: UsageProvider) -> some View {
        let name = ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName

        guard provider == .claude || provider == .codex else {
            return Text("\(name): unsupported")
                .font(.footnote)
                .foregroundStyle(.tertiary)
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
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        if let snapshot = self.store.tokenSnapshot(for: provider) {
            let updated = UsageFormatter.updatedString(from: snapshot.updatedAt)
            let cost = snapshot.last30DaysCostUSD.map { UsageFormatter.usdString($0) } ?? "—"
            return Text("\(name): \(updated) · 30d \(cost)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        if let error = self.store.tokenError(for: provider), !error.isEmpty {
            let truncated = UsageFormatter.truncatedSingleLine(error, max: 120)
            return Text("\(name): \(truncated)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        if let lastAttempt = self.store.tokenLastAttemptAt(for: provider) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .abbreviated
            let when = rel.localizedString(for: lastAttempt, relativeTo: Date())
            return Text("\(name): last attempt \(when)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        return Text("\(name): no data yet")
            .font(.footnote)
            .foregroundStyle(.tertiary)
    }
}
