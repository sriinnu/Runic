import AppKit
import RunicCore
import SwiftUI

@MainActor
struct GeneralPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var appeared = false

    var body: some View {
        LiquidPreferencesPane {
            LiquidSection(title: "System") {
                PreferenceToggleRow(
                    title: "Start at Login",
                    subtitle: "Automatically opens Runic when you start your Mac.",
                    binding: self.$settings.launchAtLogin)
            }
            .liquidEntrance(appeared: self.appeared, index: 0)

            LiquidSection(title: "Usage") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
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

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
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
            .liquidEntrance(appeared: self.appeared, index: 1)

            LiquidSection(title: "Status") {
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
            .liquidEntrance(appeared: self.appeared, index: 2)

            LiquidSection(title: "Notifications") {
                PreferenceToggleRow(
                    title: "Session quota notifications",
                    subtitle: "Notifies when the 5-hour session quota hits 0% and when it becomes " +
                        "available again.",
                    binding: self.$settings.sessionQuotaNotificationsEnabled)
            }
            .liquidEntrance(appeared: self.appeared, index: 3)

            LiquidSection(title: "Display Settings") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Menu refresh rate")
                            .font(.body)

                        Picker("", selection: self.$settings.refreshFrequency) {
                            ForEach(RefreshFrequency.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("How often to automatically refresh usage data.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Chart style")
                            .font(.body)

                        Picker("", selection: self.$settings.chartStyle) {
                            Text("Line").tag(ChartStyle.line)
                            Text("Area").tag(ChartStyle.area)
                            Text("Bar").tag(ChartStyle.bar)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text("Visual style for usage charts and graphs.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Number format")
                            .font(.body)

                        Picker("", selection: self.$settings.numberFormat) {
                            Text("Abbreviated (45.2K)").tag(NumberFormat.abbreviated)
                            Text("Full (45,234)").tag(NumberFormat.full)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text("How to display large numbers in the UI.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Date format")
                            .font(.body)

                        Picker("", selection: self.$settings.dateFormat) {
                            Text("Relative (2h ago)").tag(DateFormat.relative)
                            Text("Absolute (Jan 31, 2:30 PM)").tag(DateFormat.absolute)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text("How to display timestamps throughout the app.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Theme")
                            .font(.body)

                        Picker("", selection: self.$settings.theme) {
                            Text("System").tag(Theme.system)
                            Text("Light").tag(Theme.light)
                            Text("Dark").tag(Theme.dark)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text("App appearance (requires restart).")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 4)

            HStack {
                Spacer()
                Button("Quit Runic") { NSApp.terminate(nil) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .liquidEntrance(appeared: self.appeared, index: 5)
        }
        .onAppear {
            guard !self.appeared else { return }
            withAnimation(.easeOut(duration: 0.6)) { self.appeared = true }
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
