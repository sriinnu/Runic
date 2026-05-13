import AppKit
import RunicCore
import SwiftUI

@MainActor
struct GeneralPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var appeared = false
    @State private var diagnosticsStatus: String?
    @State private var guardrailStatus: String?

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
                                .font(RunicFont.body)
                        }
                        .toggleStyle(.checkbox)

                        Text("Reads local usage logs. Shows today + last 30 days cost in the menu.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)

                        if self.settings.costUsageEnabled {
                            Text("Auto-refresh: hourly · Timeout: 10m")
                                .font(RunicFont.footnote)
                                .foregroundStyle(.tertiary)

                            self.costStatusLine(provider: .claude)
                            self.costStatusLine(provider: .codex)
                        }
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Toggle(isOn: self.$settings.openAIWebAccessEnabled) {
                            Text("Access OpenAI via web")
                                .font(RunicFont.body)
                        }
                        .toggleStyle(.checkbox)

                        Text("Imports browser cookies for dashboard extras (credits history, code review).")
                            .font(RunicFont.footnote)
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
                            .font(RunicFont.body)

                        Picker("", selection: self.$settings.refreshFrequency) {
                            ForEach(RefreshFrequency.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("How often to automatically refresh usage data.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Chart style")
                            .font(RunicFont.body)

                        Picker("", selection: self.$settings.chartStyle) {
                            Text("Line").tag(ChartStyle.line)
                            Text("Area").tag(ChartStyle.area)
                            Text("Bar").tag(ChartStyle.bar)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text("Visual style for usage charts and graphs.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Number format")
                            .font(RunicFont.body)

                        Picker("", selection: self.$settings.numberFormat) {
                            Text("Abbreviated (45.2K)").tag(NumberFormat.abbreviated)
                            Text("Full (45,234)").tag(NumberFormat.full)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text("How to display large numbers in the UI.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Date format")
                            .font(RunicFont.body)

                        Picker("", selection: self.$settings.dateFormat) {
                            Text("Relative (2h ago)").tag(DateFormat.relative)
                            Text("Absolute (Jan 31, 2:30 PM)").tag(DateFormat.absolute)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text("How to display timestamps throughout the app.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        AppearancePreviewCard(
                            theme: self.settings.theme,
                            fontFamily: self.settings.selectedFontFamily,
                            providers: Array(self.store.enabledProviders().prefix(4)))
                            .id(self.settings.visualSettingsRevision)
                            .padding(.bottom, RunicSpacing.xs)

                        Text("Theme")
                            .font(RunicFont.body)

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
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                        self.settings.theme = theme
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 560, alignment: .leading)

                        Text("Custom skins apply immediately to Runic panels; System/Light/Dark follow macOS chrome.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("Font")
                            .font(RunicFont.body)

                        Picker("", selection: self.$settings.selectedFontFamily) {
                            ForEach(RunicFontChoice.availableChoices()) { choice in
                                Text(choice.displayName)
                                    .font(choice.previewFont)
                                    .tag(choice.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 360)

                        Text("Drop .ttf/.otf files in Resources/Fonts to add more.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
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
            withAnimation(.easeOut(duration: 0.6)) { self.appeared = true }
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

    private func costStatusLine(provider: UsageProvider) -> some View {
        let name = ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName

        guard provider == .claude || provider == .codex else {
            return Text("\(name): unsupported")
                .font(RunicFont.footnote)
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
                .font(RunicFont.footnote)
                .foregroundStyle(.tertiary)
        }
        if let snapshot = self.store.tokenSnapshot(for: provider) {
            let updated = UsageFormatter.updatedString(from: snapshot.updatedAt)
            let cost = snapshot.last30DaysCostUSD.map { UsageFormatter.usdString($0) } ?? "—"
            return Text("\(name): \(updated) · 30d \(cost)")
                .font(RunicFont.footnote)
                .foregroundStyle(.tertiary)
        }
        if let error = self.store.tokenError(for: provider), !error.isEmpty {
            let truncated = UsageFormatter.truncatedSingleLine(error, max: 120)
            return Text("\(name): \(truncated)")
                .font(RunicFont.footnote)
                .foregroundStyle(.tertiary)
        }
        if let lastAttempt = self.store.tokenLastAttemptAt(for: provider) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .abbreviated
            let when = rel.localizedString(for: lastAttempt, relativeTo: Date())
            return Text("\(name): last attempt \(when)")
                .font(RunicFont.footnote)
                .foregroundStyle(.tertiary)
        }
        return Text("\(name): no data yet")
            .font(RunicFont.footnote)
            .foregroundStyle(.tertiary)
    }
}

private struct ThemeChoiceButton: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let palette = self.theme.palette
        Button(action: self.action) {
            HStack(spacing: RunicSpacing.xs) {
                ThemeSwatch(palette: palette, isSelected: self.isSelected)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(palette.displayName)
                        .font(RunicFont.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(palette.tagline)
                        .font(RunicFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xs)
            .frame(minHeight: 50, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                    .fill(self.isSelected ? palette.accent.opacity(0.14) : Color.primary.opacity(0.035)))
            .overlay(
                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                    .stroke(
                        self.isSelected ? palette.accent.opacity(0.72) : Color.primary.opacity(0.08),
                        lineWidth: self.isSelected ? 1.3 : 0.7))
        }
        .buttonStyle(.plain)
        .help(palette.displayName)
    }
}

private struct ThemeSwatch: View {
    let palette: RunicThemePalette
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                .fill(palette.menuSurfaceGradient)
            HStack(spacing: 3) {
                ForEach(Array(palette.swatchColors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 5)
            Image(systemName: palette.symbolName)
                .font(RunicFont.caption.weight(.bold))
                .foregroundStyle(palette.primaryText)
                .shadow(color: .black.opacity(0.22), radius: 1, x: 0, y: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                .stroke(self.isSelected ? palette.highlight : palette.menuSeparatorColor, lineWidth: 1))
    }
}

private struct AppearancePreviewCard: View {
    let theme: Theme
    let fontFamily: String
    let providers: [UsageProvider]

    var body: some View {
        let palette = self.theme.palette
        let selectedProvider = self.previewProviders.first ?? .codex
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(spacing: RunicSpacing.xxs) {
                self.providerChip(title: "Overview", systemImage: "square.grid.2x2", tint: palette.secondary, isSelected: false)
                self.providerChip(
                    title: self.providerLabel(selectedProvider),
                    provider: selectedProvider,
                    tint: self.providerColor(selectedProvider),
                    isSelected: true)
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(palette.menuSeparatorColor)
                .frame(height: 1)

            HStack(spacing: RunicSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: RunicCornerRadius.md, style: .continuous)
                        .fill(palette.menuSubtleFill)
                    if let icon = ProviderBrandIcon.image(for: selectedProvider, size: 24) {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: RunicCornerRadius.md, style: .continuous)
                        .stroke(palette.menuSeparatorColor, lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.providerLabel(selectedProvider))
                        .font(RunicFont.body.weight(.bold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)
                    Text("\(palette.displayName) · \(self.fontLabel)")
                        .font(RunicFont.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                    Text("Top model · 42M tokens · 118 req")
                        .font(RunicFont.caption2)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer()

                Text("Pro")
                    .font(RunicFont.caption.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, RunicSpacing.xs)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(palette.accent.opacity(0.22)))
            }
            .padding(RunicSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: RunicCornerRadius.md, style: .continuous)
                    .fill(palette.menuCardGradient))
            .overlay(
                RoundedRectangle(cornerRadius: RunicCornerRadius.md, style: .continuous)
                    .stroke(palette.menuSeparatorColor, lineWidth: 1))

            HStack(spacing: RunicSpacing.xs) {
                self.metricPreview(title: "Session", value: "42%", color: palette.accent, fill: 0.42)
                self.metricPreview(title: "Weekly", value: "71%", color: palette.highlight, fill: 0.71)
            }

            VStack(spacing: 0) {
                self.actionPreviewRow(title: "Usage timeline", systemImage: "chart.xyaxis.line")
                self.actionPreviewRow(title: "Models", systemImage: "square.stack.3d.up")
            }
            .padding(.top, 1)
        }
        .padding(RunicSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RunicCornerRadius.md, style: .continuous)
                .fill(palette.menuSurfaceGradient))
        .overlay(
            RoundedRectangle(cornerRadius: RunicCornerRadius.md, style: .continuous)
                .stroke(palette.menuSeparatorColor, lineWidth: 1))
        .runicColorScheme(palette)
    }

    private var previewProviders: [UsageProvider] {
        self.providers.isEmpty ? [.codex, .claude, .gemini, .vercelai] : self.providers
    }

    private var fontLabel: String {
        switch self.fontFamily {
        case RunicFontChoice.sfPro.id: RunicFontChoice.sfPro.displayName
        case RunicFontChoice.sfMono.id: RunicFontChoice.sfMono.displayName
        default: self.fontFamily
        }
    }

    private func metricPreview(title: String, value: String, color: Color, fill: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
            HStack {
                Text(title)
                    .font(RunicFont.caption)
                    .foregroundStyle(self.theme.palette.secondaryText)
                Spacer()
                Text(value)
                    .font(RunicFont.caption.weight(.semibold))
                    .foregroundStyle(self.theme.palette.primaryText)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(self.theme.palette.menuTrackColor)
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: max(8, proxy.size.width * min(max(fill, 0), 1)))
                }
            }
            .frame(height: 6)
        }
        .padding(RunicSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                .fill(self.theme.palette.menuSubtleFill))
        .overlay(
            RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                .stroke(self.theme.palette.menuSeparatorColor.opacity(0.72), lineWidth: 0.7))
    }

    private func providerChip(
        title: String,
        systemImage: String? = nil,
        provider: UsageProvider? = nil,
        tint: Color,
        isSelected: Bool)
        -> some View
    {
        HStack(spacing: 5) {
            if let provider, let icon = ProviderBrandIcon.image(for: provider, size: 14) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(RunicFont.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(RunicFont.caption.weight(.semibold))
                .foregroundStyle(isSelected ? self.theme.palette.primaryText : self.theme.palette.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(isSelected ? tint.opacity(0.24) : self.theme.palette.menuSubtleFill))
        .overlay(
            Capsule(style: .continuous)
                .stroke(isSelected ? tint.opacity(0.55) : self.theme.palette.menuSeparatorColor.opacity(0.45), lineWidth: 0.7))
    }

    private func actionPreviewRow(title: String, systemImage: String) -> some View {
        HStack(spacing: RunicSpacing.xs) {
            Image(systemName: systemImage)
                .font(RunicFont.caption.weight(.semibold))
                .foregroundStyle(self.theme.palette.secondaryText)
                .frame(width: 16)
            Text(title)
                .font(RunicFont.caption.weight(.semibold))
                .foregroundStyle(self.theme.palette.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(RunicFont.caption2.weight(.semibold))
                .foregroundStyle(self.theme.palette.secondaryText)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(self.theme.palette.menuSeparatorColor.opacity(0.55))
                .frame(height: 0.7)
        }
    }

    private func providerColor(_ provider: UsageProvider) -> Color {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private func providerLabel(_ provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
    }
}

private struct RunicOperationsCenterView: View {
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
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            HStack(spacing: RunicSpacing.xs) {
                self.summaryPill(
                    title: "Credentials",
                    value: "\(health.count(where: { $0.credentialState == .connected || $0.credentialState == .configured || $0.credentialState == .local }))/\(max(health.count, 1))",
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
                    .font(RunicFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(Array(health.prefix(6))) { row in
                    ProviderHealthCompactRow(row: row)
                }
                if health.count > 6 {
                    Text("+ \(health.count - 6) more providers")
                        .font(RunicFont.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                Text("Recommended next actions")
                    .font(RunicFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(recommendations.prefix(4)) { recommendation in
                    HStack(alignment: .top, spacing: RunicSpacing.xs) {
                        Image(systemName: recommendation.systemImage)
                            .font(RunicFont.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(recommendation.title)
                                .font(RunicFont.caption.weight(.semibold))
                            Text(recommendation.detail)
                                .font(RunicFont.caption2)
                                .foregroundStyle(.secondary)
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
                        .font(RunicFont.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func summaryPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: RunicSpacing.xxs) {
            Image(systemName: systemImage)
                .font(RunicFont.caption)
            Text(title)
                .font(RunicFont.caption2)
            Text(value)
                .font(RunicFont.caption2.weight(.semibold))
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
                        .font(RunicFont.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(self.row.source)
                        .font(RunicFont.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("\(self.row.credentialDetail) · \(self.row.dataDetail)")
                    .font(RunicFont.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: RunicSpacing.xs)

            Text(self.row.credentialState.label)
                .font(RunicFont.caption2.weight(.semibold))
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
