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
                            .buttonStyle(.bordered)
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
            .liquidEntrance(appeared: self.appeared, index: 1)

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
            .liquidEntrance(appeared: self.appeared, index: 2)

            LiquidSection(title: "Notifications") {
                PreferenceToggleRow(
                    title: "Session quota notifications",
                    subtitle: "Warns when session quota resets.",
                    binding: self.$settings.sessionQuotaNotificationsEnabled)
            }
            .liquidEntrance(appeared: self.appeared, index: 3)

            LiquidSection(title: "Display Settings") {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Menu refresh rate")
                            .font(self.preferenceTitleFont)

                        Picker("", selection: self.$settings.refreshFrequency) {
                            ForEach(RefreshFrequency.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("How often to automatically refresh usage data.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Chart style")
                            .font(self.preferenceTitleFont)

                        Picker("", selection: self.$settings.chartStyle) {
                            Text("Line").tag(ChartStyle.line)
                            Text("Area").tag(ChartStyle.area)
                            Text("Bar").tag(ChartStyle.bar)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text("Timeline charts can render as a line, filled area, or bars.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Number format")
                            .font(self.preferenceTitleFont)

                        Picker("", selection: self.$settings.numberFormat) {
                            Text("Abbreviated (45.2K)").tag(NumberFormat.abbreviated)
                            Text("Full (45,234)").tag(NumberFormat.full)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text("How to display large numbers in the UI.")
                            .font(self.preferenceHelpFont)
                            .foregroundStyle(self.preferenceHelpColor)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Date format")
                            .font(self.preferenceTitleFont)

                        Picker("", selection: self.$settings.dateFormat) {
                            Text("Relative (2h ago)").tag(DateFormat.relative)
                            Text("Absolute (Jan 31, 2:30 PM)").tag(DateFormat.absolute)
                        }
                        .pickerStyle(.segmented)
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
                                GridItem(.adaptive(minimum: 142, maximum: 176), spacing: RunicSpacing.xs),
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
            .liquidEntrance(appeared: self.appeared, index: 4)

            LiquidSection(title: "Operations") {
                RunicOperationsCenterView(
                    settings: self.settings,
                    store: self.store,
                    diagnosticsStatus: self.diagnosticsStatus,
                    guardrailStatus: self.guardrailStatus,
                    onCopyDiagnostics: self.copyDiagnostics,
                    onInstallGuardrails: self.installGuardrails)
            }
            .liquidEntrance(appeared: self.appeared, index: 5)

            HStack {
                Spacer()
                Button("Quit Runic") { NSApp.terminate(nil) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .liquidEntrance(appeared: self.appeared, index: 6)
        }
        .onAppear {
            guard !self.appeared else { return }
            withAnimation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion)) { self.appeared = true }
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
        self.runicTheme.isTerminalHUD
            ? .system(size: 14, weight: .semibold, design: .monospaced)
            : self.fonts.callout.weight(.medium)
    }

    private var preferenceHelpFont: Font {
        self.runicTheme.isTerminalHUD ? .system(size: 12, weight: .regular) : self.fonts.footnote
    }

    private var preferenceHelpDesign: Font.Design? {
        self.runicTheme.isTerminalHUD ? .default : nil
    }

    private var preferenceHelpTracking: CGFloat {
        self.runicTheme.isTerminalHUD ? 0 : RunicFont.activeRules.letterSpacing
    }

    private var preferenceHelpColor: Color {
        self.runicTheme.subduedSecondaryText
    }

    private var preferenceHelpLineSpacing: CGFloat {
        self.runicTheme.isTerminalHUD ? PreferencesTypographyMetrics.terminalBodyLineSpacing : 0
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
            let updated = UsageFormatter.updatedString(from: snapshot.updatedAt)
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

private struct RunicOperationsCenterView: View {
    @Environment(\.runicFonts) private var fonts
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    let diagnosticsStatus: String?
    let guardrailStatus: String?
    let onCopyDiagnostics: () -> Void
    let onInstallGuardrails: () -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let health = RunicDiagnosticsReport.providerHealthRows(settings: self.settings, store: self.store)
        let recommendations = RunicDiagnosticsReport.recommendations(settings: self.settings, store: self.store)
        let connected = health.count {
            $0.credentialState == .connected ||
                $0.credentialState == .configured ||
                $0.credentialState == .local
        }
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            HStack(spacing: RunicSpacing.xs) {
                self.summaryPill(
                    title: "Credentials",
                    value: "\(connected)/\(max(health.count, 1))",
                    systemImage: "key.horizontal")
                self.summaryPill(
                    title: "Alerts",
                    value: "\(AlertRuleStore.load().rules.count)",
                    systemImage: "bell.badge")
                self.summaryPill(
                    title: "Budgets",
                    value: "\(ProjectBudgetStore.getAllBudgets().count)",
                    systemImage: "target")
            }

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                Text("Provider health")
                    .font(self.fonts.caption.weight(.semibold))
                    .foregroundStyle(self.runicTheme.secondaryText)
                ForEach(Array(health.prefix(6))) { row in
                    ProviderHealthCompactRow(row: row)
                }
                if health.count > 6 {
                    Text("+ \(health.count - 6) more providers")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                Text("Recommended next actions")
                    .font(self.fonts.caption.weight(.semibold))
                    .foregroundStyle(self.runicTheme.secondaryText)
                ForEach(recommendations.prefix(4)) { recommendation in
                    HStack(alignment: .top, spacing: RunicSpacing.xs) {
                        RunicThemedSystemIcon(
                            systemName: recommendation.systemImage,
                            intent: .info,
                            font: self.fonts.caption,
                            width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(recommendation.title)
                                .font(self.fonts.caption.weight(.semibold))
                            Text(recommendation.detail)
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack(spacing: RunicSpacing.xs) {
                Button {
                    self.onInstallGuardrails()
                } label: {
                    Label("Install Guardrails", systemImage: "shield.checkered")
                }
                .buttonStyle(.bordered)

                Button {
                    self.onCopyDiagnostics()
                } label: {
                    Label("Copy Diagnostics", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                if let status = self.guardrailStatus ?? self.diagnosticsStatus {
                    Text(status)
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }
        }
    }

    private func summaryPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: RunicSpacing.xxs) {
            RunicThemedSystemIcon(
                systemName: systemImage,
                intent: .data,
                font: self.fonts.caption)
            Text(title)
                .font(self.fonts.caption2)
            Text(value)
                .font(self.fonts.caption2.weight(.semibold))
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.xxxs)
        .background(
            Capsule(style: .continuous)
                .fill(self.runicTheme.menuSubtleFill))
        .overlay(
            Capsule(style: .continuous)
                .stroke(self.runicTheme.menuSeparatorColor.opacity(0.55), lineWidth: 0.7))
    }
}

private struct ProviderHealthCompactRow: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let row: RunicProviderHealthRow

    var body: some View {
        HStack(alignment: .center, spacing: RunicSpacing.xs) {
            if let icon = ProviderBrandIcon.image(for: self.row.provider, size: 20) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: RunicSpacing.xxs) {
                    Text(self.row.name)
                        .font(self.fonts.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(self.row.source)
                        .font(self.fonts.caption2.weight(.medium))
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
                Text("\(self.row.credentialDetail) · \(self.row.dataDetail)")
                    .font(self.fonts.caption2)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: RunicSpacing.xs)

            Text(self.row.credentialState.label)
                .font(self.fonts.caption2.weight(.semibold))
                .foregroundStyle(self.stateColor)
                .padding(.horizontal, RunicSpacing.xs)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(self.stateColor.opacity(0.12)))
        }
        .padding(.vertical, 2)
    }

    private var brandColor: Color {
        let color = ProviderDescriptorRegistry.descriptor(for: self.row.provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private var stateColor: Color {
        switch self.row.credentialState {
        case .connected, .configured: .green
        case .local: .blue
        case .missing: .orange
        case .attention: .red
        }
    }
}
