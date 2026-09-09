import AppKit
import RunicCore
import SwiftUI

@MainActor
struct GeneralPane: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var appeared = false
    @State private var diagnosticsStatus: String?
    @State private var guardrailStatus: String?
    @State private var isImportingOpenAIWebCookies = false

    var body: some View {
        LiquidPreferencesPane {
            LiquidSection(title: "System") {
                PreferenceToggleRow(
                    title: "Start at Login",
                    subtitle: "Open Runic when your Mac starts.",
                    binding: self.launchAtLoginBinding)
            }
            .liquidEntrance(appeared: self.appeared, index: 0)

            LiquidSection(title: "Configuration") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Config file")
                            .font(self.preferenceTitleFont)

                        Text(
                            "Provider endpoint URLs and log paths live in one JSON file that Runic watches. " +
                                "Edit it and changes apply instantly — no rebuild, no restart.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)
                            .lineSpacing(self.preferenceHelpLineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(RunicConfigStore.storageURL.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(self.preferenceHelpColor)
                            .textSelection(.enabled)
                    }

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
                        .font(self.preferenceHelpFont)
                        .foregroundStyle(self.preferenceHelpColor)
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 1)

            LiquidSection(title: "Usage") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Toggle(isOn: self.$settings.costUsageEnabled) {
                            Text("Show cost summary")
                                .font(self.preferenceTitleFont)
                        }
                        .runicPreferenceToggleStyle()

                        Text("Shows local cost totals in the menu.")
                            .font(self.preferenceHelpFont)
                            .fontDesign(self.preferenceHelpDesign)
                            .tracking(self.preferenceHelpTracking)
                            .foregroundStyle(self.preferenceHelpColor)
                            .lineSpacing(self.preferenceHelpLineSpacing)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if self.settings.costUsageEnabled {
                            Text("Auto-refresh: hourly · Timeout: 10m")
                                .font(self.preferenceHelpFont)
                                .fontDesign(self.preferenceHelpDesign)
                                .tracking(self.preferenceHelpTracking)
                                .foregroundStyle(self.preferenceHelpColor)

                            self.costStatusLine(provider: .claude)
                            self.costStatusLine(provider: .codex)
                        }
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Toggle(isOn: self.$settings.openAIWebAccessEnabled) {
                            Text("Access OpenAI via web")
                                .font(self.preferenceTitleFont)
                        }
                        .runicPreferenceToggleStyle()

                        Text("Enable extras after manual cookie import.")
                            .font(self.preferenceHelpFont)
                            .fontDesign(self.preferenceHelpDesign)
                            .tracking(self.preferenceHelpTracking)
                            .foregroundStyle(self.preferenceHelpColor)
                            .lineSpacing(self.preferenceHelpLineSpacing)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: RunicSpacing.sm) {
                            Button {
                                self.importOpenAIWebCookies()
                            } label: {
                                if self.isImportingOpenAIWebCookies {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("Import Browser Cookies Now")
                            }
                            .buttonStyle(.runicBordered)
                            .disabled(self.isImportingOpenAIWebCookies || !self.settings.openAIWebAccessEnabled)

                            if let status = self.openAIWebStatusText {
                                Text(status)
                                    .font(self.preferenceHelpFont)
                                    .fontDesign(self.preferenceHelpDesign)
                                    .tracking(self.preferenceHelpTracking)
                                    .foregroundStyle(self.preferenceHelpColor)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 2)

            LiquidSection(title: "Status") {
                PreferenceToggleRow(
                    title: "Check provider status",
                    subtitle: "Polls provider status pages.",
                    binding: self.$settings.statusChecksEnabled)
                PreferenceToggleRow(
                    title: "Vibrant menu bar icon",
                    subtitle: "Shows usage pressure in the menu bar.",
                    binding: self.$settings.menuBarVibrantIconEnabled)
            }
            .liquidEntrance(appeared: self.appeared, index: 3)

            LiquidSection(title: "Notifications") {
                PreferenceToggleRow(
                    title: "Session quota notifications",
                    subtitle: "Warns when session quota resets.",
                    binding: self.$settings.sessionQuotaNotificationsEnabled)
            }
            .liquidEntrance(appeared: self.appeared, index: 4)

            LiquidSection(title: "Display Settings") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Menu refresh rate")
                            .font(self.preferenceTitleFont)

                        RunicSegmentedPicker(
                            selection: self.$settings.refreshFrequency,
                            cases: RefreshFrequency.allCases,
                            label: \.label)

                        Text("How often to automatically refresh usage data.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Chart style")
                            .font(self.preferenceTitleFont)

                        RunicSegmentedPicker(
                            selection: self.$settings.chartStyle,
                            options: [(ChartStyle.line, "Line"), (ChartStyle.area, "Area"), (ChartStyle.bar, "Bar")])
                            .frame(maxWidth: 360)

                        Text("Timeline charts can render as a line, filled area, or bars.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Number format")
                            .font(self.preferenceTitleFont)

                        RunicSegmentedPicker(
                            selection: self.$settings.numberFormat,
                            options: [
                                (NumberFormat.abbreviated, "Abbreviated (45.2K)"),
                                (NumberFormat.full, "Full (45,234)"),
                            ])
                            .frame(maxWidth: 360)

                        Text("How to display large numbers in the UI.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Date format")
                            .font(self.preferenceTitleFont)

                        RunicSegmentedPicker(
                            selection: self.$settings.dateFormat,
                            options: [
                                (DateFormat.relative, "Relative (2h ago)"),
                                (DateFormat.absolute, "Absolute (Jan 31, 2:30 PM)"),
                            ])
                            .frame(maxWidth: 360)

                        Text("How to display timestamps throughout the app.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        AppearancePreviewCard(
                            theme: self.settings.theme,
                            fontFamily: self.settings.selectedFontFamily,
                            providers: Array(self.store.enabledProviders().prefix(4)))
                            .id(self.settings.visualSettingsRevision)
                            .padding(.bottom, RunicSpacing.xs)

                        Text("Theme")
                            .font(self.preferenceTitleFont)

                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 122, maximum: 176), spacing: RunicSpacing.xs),
                            ],
                            alignment: .leading,
                            spacing: RunicSpacing.xs)
                        {
                            ForEach(Theme.allCases) { theme in
                                ThemeChoiceButton(
                                    theme: theme,
                                    isSelected: self.settings.theme == theme)
                                {
                                    withAnimation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion)) {
                                        self.settings.theme = theme
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 560, alignment: .leading)

                        Text("Custom skins apply immediately to Runic panels; System/Light/Dark follow macOS chrome.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Font")
                            .font(self.preferenceTitleFont)

                        let lockedFamily = RunicFontChoice.resolvedThemeFamily(
                            self.settings.theme.palette.style.typography.bodyFamily)
                        Picker("", selection: self.$settings.selectedFontFamily) {
                            ForEach(RunicFontChoice.availableChoices()) { choice in
                                Text(choice.displayName)
                                    .font(choice.previewFont)
                                    .tag(choice.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 360)
                        .disabled(lockedFamily != nil)
                        .opacity(lockedFamily == nil ? 1 : 0.55)

                        Text(lockedFamily == nil
                            ? "Install extra families with Font Book; Runic shows available local fonts here."
                            : "This theme uses a curated typography lock.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)

                        if let lockedFamily {
                            Text("\(self.settings.theme.label) locks menu typography to " +
                                "\(RunicFontChoice.displayName(for: lockedFamily)). " +
                                "The picker applies to unlocked themes.")
                                .font(self.preferenceHelpFont)
                                .foregroundStyle(self.preferenceHelpColor)
                        }

                        TypographyRulesPreview(
                            fontFamily: self.settings.selectedFontFamily,
                            theme: self.settings.theme)
                            .id(self.settings.visualSettingsRevision)
                            .padding(.top, RunicSpacing.xs)
                    }
                }
            }
            .liquidEntrance(appeared: self.appeared, index: 5)

            LiquidSection(title: "Operations") {
                RunicOperationsCenterView(
                    settings: self.settings,
                    store: self.store,
                    diagnosticsStatus: self.diagnosticsStatus,
                    guardrailStatus: self.guardrailStatus,
                    onCopyDiagnostics: self.copyDiagnostics,
                    onInstallGuardrails: self.installGuardrails)
            }
            .liquidEntrance(appeared: self.appeared, index: 6)

            HStack {
                Spacer()
                Button("Quit Runic") { NSApp.terminate(nil) }
                    .buttonStyle(.runicProminent)
                    .controlSize(.large)
            }
            .liquidEntrance(appeared: self.appeared, index: 7)
        }
        .onAppear {
            guard !self.appeared else { return }
            withAnimation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion)) { self.appeared = true }
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

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { self.settings.launchAtLogin },
            set: { self.settings.setLaunchAtLoginFromPreferences($0) })
    }

    private var preferenceTitleFont: Font {
        self.fonts.callout.weight(.medium)
    }

    private var preferenceHelpFont: Font {
        self.fonts.footnote
    }

    private var preferenceHelpDesign: Font.Design? {
        nil
    }

    private var preferenceHelpTracking: CGFloat {
        RunicFont.activeRules.letterSpacing
    }

    private var preferenceHelpColor: Color {
        self.runicTheme.subduedSecondaryText
    }

    private var preferenceHelpLineSpacing: CGFloat {
        0
    }

    private var openAIWebStatusText: String? {
        self.store.openAIDashboardCookieImportStatus ?? self.store.lastOpenAIDashboardError
    }

    private func importOpenAIWebCookies() {
        guard !self.isImportingOpenAIWebCookies else { return }
        self.isImportingOpenAIWebCookies = true
        Task { @MainActor in
            await self.store.importOpenAIDashboardBrowserCookiesNow()
            self.isImportingOpenAIWebCookies = false
        }
    }

    private func costStatusLine(provider: UsageProvider) -> some View {
        let name = ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName

        guard provider == .claude || provider == .codex else {
            return Text("\(name): unsupported")
                .font(self.preferenceHelpFont)
                .fontDesign(self.preferenceHelpDesign)
                .tracking(self.preferenceHelpTracking)
                .foregroundStyle(self.preferenceHelpColor)
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
                .font(self.preferenceHelpFont)
                .fontDesign(self.preferenceHelpDesign)
                .tracking(self.preferenceHelpTracking)
                .foregroundStyle(self.preferenceHelpColor)
        }
        if let snapshot = self.store.tokenSnapshot(for: provider) {
            let updated = UsageFormatter.updatedString(
                from: snapshot.updatedAt,
                style: self.settings.dateFormat.formatterStyle)
            let cost = snapshot.last30DaysCostUSD.map { UsageFormatter.usdString($0) } ?? "—"
            return Text("\(name): \(updated) · 30d \(cost)")
                .font(self.preferenceHelpFont)
                .fontDesign(self.preferenceHelpDesign)
                .tracking(self.preferenceHelpTracking)
                .foregroundStyle(self.preferenceHelpColor)
        }
        if let error = self.store.tokenError(for: provider), !error.isEmpty {
            let truncated = UsageFormatter.truncatedSingleLine(error, max: 120)
            return Text("\(name): \(truncated)")
                .font(self.preferenceHelpFont)
                .fontDesign(self.preferenceHelpDesign)
                .tracking(self.preferenceHelpTracking)
                .foregroundStyle(self.preferenceHelpColor)
        }
        if let lastAttempt = self.store.tokenLastAttemptAt(for: provider) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .abbreviated
            let when = rel.localizedString(for: lastAttempt, relativeTo: Date())
            return Text("\(name): last attempt \(when)")
                .font(self.preferenceHelpFont)
                .fontDesign(self.preferenceHelpDesign)
                .tracking(self.preferenceHelpTracking)
                .foregroundStyle(self.preferenceHelpColor)
        }
        return Text("\(name): no data yet")
            .font(self.preferenceHelpFont)
            .fontDesign(self.preferenceHelpDesign)
            .tracking(self.preferenceHelpTracking)
            .foregroundStyle(self.preferenceHelpColor)
    }
}
