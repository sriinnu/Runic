import AppKit
import RunicCore
import SwiftUI

// Structural lint debt: provider settings/history sidebar needs file-level split.
struct ProviderUsageStatus {
    let text: String
    let style: Style

    enum Style {
        case success
        case error
        case neutral
    }
}

enum ProviderListMetrics {
    static let contentInset: CGFloat = 16
    static let listHeaderCornerRadius: CGFloat = RunicCornerRadius.md
    static let listHeaderPadding: EdgeInsets = .init(
        top: RunicSpacing.xs,
        leading: RunicSpacing.md,
        bottom: RunicSpacing.xs,
        trailing: RunicSpacing.md)
    static let listHeaderBackgroundOpacity: Double = 0.26
    static let listHeaderBorderOpacity: Double = 0.2
    static let rowSpacing: CGFloat = RunicSpacing.sm
    static let reorderHandleSize: CGFloat = 12
    static let reorderDotSize: CGFloat = 4
    static let reorderDotSpacing: CGFloat = 4
    static let rowInsets = EdgeInsets(
        top: RunicSpacing.xxs,
        leading: contentInset,
        bottom: RunicSpacing.xxs,
        trailing: contentInset)
    static let sectionEdgeInset: CGFloat = RunicSpacing.md
    static let dividerBottomInset: CGFloat = RunicSpacing.xxs
    static let checkboxSize: CGFloat = 20
    static let iconSize: CGFloat = 34
    static let dividerLeadingInset: CGFloat = contentInset
    static let dividerTrailingInset: CGFloat = contentInset
    static let providerCardPadding = EdgeInsets(
        top: RunicSpacing.sm,
        leading: RunicSpacing.sm,
        bottom: RunicSpacing.sm,
        trailing: RunicSpacing.sm)
    static let providerCardBackgroundOpacity: Double = 0.55
    static let providerCardBorderOpacity: Double = 0.25
    static let providerCardCornerRadius: CGFloat = RunicCornerRadius.md
    static let providerInsightsCardCornerRadius: CGFloat = RunicCornerRadius.sm
    static let providerInsightsGridItemMinWidth: CGFloat = 210
    static let providerInsightsChipCornerRadius: CGFloat = RunicCornerRadius.sm
    static let providerInsightsChipSpacing: CGFloat = RunicSpacing.xxs
    static let providerInsightsChipPadding: CGFloat = RunicSpacing.xs

    static let supplementalCardPadding = EdgeInsets(
        top: RunicSpacing.sm,
        leading: RunicSpacing.sm,
        bottom: RunicSpacing.sm,
        trailing: RunicSpacing.sm)
    static let supplementalCardBackgroundOpacity: Double = 0.28
    static let supplementalCardBorderOpacity: Double = 0.18
    static let fieldMaxWidth: CGFloat = 420
    static let errorCardPadding: CGFloat = RunicSpacing.sm
    static let statusBadgePaddingH: CGFloat = RunicSpacing.xs
    static let statusBadgePaddingV: CGFloat = RunicSpacing.xxxs
    static let errorCardCornerRadius: CGFloat = RunicCornerRadius.sm
    static let insightsCardPadding: CGFloat = RunicSpacing.xs
    static let insightsLineSpacing: CGFloat = RunicSpacing.xxxs
    static let insightsLabelWidth: CGFloat = 84
    static let sidebarStatusLabelWidth: CGFloat = 62
    static let sidebarCardCornerRadius: CGFloat = RunicCornerRadius.md
    static let sidebarCardPadding: CGFloat = RunicSpacing.md
    static let sidebarCardBackgroundOpacity: Double = 0.36
    static let sidebarCardBorderOpacity: Double = 0.22
    static let sidebarMicroCardCornerRadius: CGFloat = RunicCornerRadius.sm
    static let sidebarMicroCardBackgroundOpacity: Double = 0.52
    static let sidebarMicroCardBorderOpacity: Double = 0.2
    static let sidebarSectionSpacing: CGFloat = RunicSpacing.md
    static let sidebarContentGap: CGFloat = RunicSpacing.sm
}

@MainActor
struct ProvidersPane: View {
    @Environment(\.runicFonts) private var fonts
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var expandedErrors: Set<UsageProvider> = []
    @State private var settingsStatusTextByID: [String: String] = [:]
    @State private var settingsLastAppActiveRunAtByID: [String: Date] = [:]
    @State private var activeConfirmation: ProviderSettingsConfirmationState?
    @State private var sidebarSelection: UsageProvider?
    @Environment(\.runicTheme) private var runicTheme

    private var providers: [UsageProvider] {
        self.settings.orderedProviders()
    }

    var body: some View {
        Group {
            if self.settings.providersPaneSidebar {
                self.sidebarLayout
            } else {
                self.listLayout
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            self.runSettingsDidBecomeActiveHooks()
        }
        .alert(
            self.activeConfirmation?.title ?? "",
            isPresented: Binding(
                get: { self.activeConfirmation != nil },
                set: { isPresented in
                    if !isPresented { self.activeConfirmation = nil }
                }),
            actions: {
                if let active = self.activeConfirmation {
                    Button(active.confirmTitle) {
                        active.onConfirm()
                        self.activeConfirmation = nil
                    }
                    Button("Cancel", role: .cancel) { self.activeConfirmation = nil }
                }
            },
            message: {
                if let active = self.activeConfirmation {
                    Text(active.message)
                }
            })
    }

    // MARK: - List layout (default)

    private var listLayout: some View {
        PreferencesListPane(horizontalPadding: 0, verticalPadding: 0) {
            VStack(spacing: ProviderListMetrics.sidebarSectionSpacing) {
                self.listLayoutHeader
                if let notice = self.settings.providerCredentialMigrationNotice {
                    self.credentialMigrationNoticeCard(notice)
                }

                ProviderListView(
                    providers: self.providers,
                    store: self.store,
                    isEnabled: { provider in self.binding(for: provider) },
                    subtitle: { provider in self.providerSubtitle(provider) },
                    usageStatus: { provider in self.providerUsageStatus(provider) },
                    sourceLabel: { provider in self.providerSourceLabel(provider) },
                    statusLabel: { provider in self.providerStatusLabel(provider) },
                    settingsToggles: { provider in self.extraSettingsToggles(for: provider) },
                    settingsFields: { provider in self.extraSettingsFields(for: provider) },
                    errorDisplay: { provider in self.providerErrorDisplay(provider) },
                    isErrorExpanded: { provider in self.expandedBinding(for: provider) },
                    onCopyError: { text in self.copyToPasteboard(text) },
                    moveProviders: { fromOffsets, toOffset in
                        self.settings.moveProvider(fromOffsets: fromOffsets, toOffset: toOffset)
                    })
            }
        }
    }

    private var listLayoutHeader: some View {
        HStack(alignment: .top, spacing: RunicSpacing.sm) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(self.runicTheme.secondaryText)

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                Text("Built-in providers")
                    .font(self.fonts.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Switch to sidebar layout for per-day history cards and model or project drill-down details.")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(ProviderListMetrics.listHeaderPadding)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.listHeaderCornerRadius, style: .continuous)
                .fill(self.runicTheme.menuSubtleFill.opacity(ProviderListMetrics.listHeaderBackgroundOpacity + 0.18)))
        .overlay(
            RoundedRectangle(cornerRadius: ProviderListMetrics.listHeaderCornerRadius, style: .continuous)
                .strokeBorder(
                    self.runicTheme.menuSeparatorColor.opacity(ProviderListMetrics.listHeaderBorderOpacity + 0.12),
                    lineWidth: 1))
        .padding(.horizontal, ProviderListMetrics.contentInset)
    }

    private func credentialMigrationNoticeCard(_ notice: String) -> some View {
        Label {
            Text(notice)
                .font(self.fonts.caption)
                .foregroundStyle(self.runicTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "key.fill")
                .foregroundStyle(.orange)
        }
        .padding(ProviderListMetrics.listHeaderPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.listHeaderCornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.10)))
        .overlay(
            RoundedRectangle(cornerRadius: ProviderListMetrics.listHeaderCornerRadius, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.28), lineWidth: 1))
        .padding(.horizontal, ProviderListMetrics.contentInset)
    }

    // MARK: - Sidebar layout

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(selection: self.$sidebarSelection) {
                ForEach(self.providers, id: \.self) { provider in
                    ProviderSidebarRow(
                        provider: provider,
                        store: self.store,
                        isEnabled: self.binding(for: provider).wrappedValue,
                        isSelected: self.sidebarSelection == provider)
                        .tag(provider)
                }
                .onMove { fromOffsets, toOffset in
                    self.settings.moveProvider(fromOffsets: fromOffsets, toOffset: toOffset)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160, idealWidth: 180)
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    self.runicTheme.menuSurfaceGradient
                    if self.runicTheme.isTerminalHUD {
                        RunicTerminalScanlineOverlay(opacity: 0.45)
                    }
                }
                .opacity(0.55)
            }
            .onAppear {
                self.normalizeSidebarSelection()
            }
            .onChange(of: self.providers) { _, _ in
                self.normalizeSidebarSelection()
            }
        } detail: {
            if let selected = self.sidebarSelection {
                ProviderSidebarDetailView(
                    provider: selected,
                    store: self.store,
                    isEnabled: self.binding(for: selected),
                    subtitle: self.providerSubtitle(selected),
                    usageStatus: self.providerUsageStatus(selected),
                    sourceLabel: self.providerSourceLabel(selected),
                    statusLabel: self.providerStatusLabel(selected),
                    settingsToggles: self.extraSettingsToggles(for: selected),
                    settingsFields: self.extraSettingsFields(for: selected),
                    errorDisplay: self.providerErrorDisplay(selected),
                    isErrorExpanded: self.expandedBinding(for: selected),
                    onCopyError: { text in self.copyToPasteboard(text) })
            } else {
                Text("Select a provider")
                    .font(self.fonts.title3)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func normalizeSidebarSelection() {
        guard !self.providers.isEmpty else {
            self.sidebarSelection = nil
            return
        }

        if let selected = self.sidebarSelection, self.providers.contains(selected) {
            return
        }

        self.sidebarSelection = self.providers.first
    }

    private func binding(for provider: UsageProvider) -> Binding<Bool> {
        let meta = self.store.metadata(for: provider)
        return Binding(
            get: { self.settings.isProviderEnabled(provider: provider, metadata: meta) },
            set: { self.settings.setProviderEnabled(provider: provider, metadata: meta, enabled: $0) })
    }

    private func providerSubtitle(_ provider: UsageProvider) -> String {
        let meta = self.store.metadata(for: provider)
        let cliName = meta.cliName
        let coverageSuffix = ProviderInsightsComposer.coverageSummaryLabel(
            for: provider,
            store: self.store).map { " • \($0)" } ?? ""
        let version = self.store.version(for: provider)
        var versionText = version ?? "not detected"
        if provider == .claude, let parenRange = versionText.range(of: "(") {
            versionText = versionText[..<parenRange.lowerBound].trimmingCharacters(in: .whitespaces)
        }

        if cliName == "codex" {
            return "\(versionText)\(coverageSuffix)"
        }

        // Cursor is web-based, no CLI version to detect
        if provider == .cursor || provider == .minimax {
            return "web\(coverageSuffix)"
        }
        let apiBackedProviders: Set<UsageProvider> = [
            .zai,
            .openrouter,
            .vercelai,
            .groq,
            .deepseek,
            .fireworks,
            .mistral,
            .perplexity,
            .kimi,
            .auggie,
            .together,
            .cohere,
            .xai,
            .cerebras,
            .sambanova,
            .azure,
            .bedrock,
        ]
        if apiBackedProviders.contains(provider) {
            return "api\(coverageSuffix)"
        }

        var detail = "\(cliName) \(versionText)"
        if provider == .antigravity {
            detail += " • experimental"
        }
        return "\(detail)\(coverageSuffix)"
    }

    private func providerUsageStatus(_ provider: UsageProvider) -> ProviderUsageStatus {
        if let snapshot = self.store.snapshot(for: provider) {
            let relative = snapshot.updatedAt.relativeDescription()
            return ProviderUsageStatus(text: "usage fetched \(relative)", style: .success)
        } else if self.store.isStale(provider: provider) {
            return ProviderUsageStatus(text: "last fetch failed", style: .error)
        } else {
            return ProviderUsageStatus(text: "usage not fetched yet", style: .neutral)
        }
    }

    private func providerSourceLabel(_ provider: UsageProvider) -> String {
        self.store.sourceLabel(for: provider)
    }

    private func providerStatusLabel(_ provider: UsageProvider) -> String {
        if let snapshot = self.store.snapshot(for: provider) {
            return snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened)
        }
        if self.store.isStale(provider: provider) {
            return "failed"
        }
        return "waiting"
    }

    private func providerErrorDisplay(_ provider: UsageProvider) -> ProviderErrorDisplay? {
        guard self.store.isStale(provider: provider), let raw = self.store.error(for: provider) else { return nil }
        return ProviderErrorDisplay(
            preview: self.truncated(raw, prefix: ""),
            full: raw)
    }

    private func extraSettingsToggles(for provider: UsageProvider) -> [ProviderSettingsToggleDescriptor] {
        guard let impl = ProviderCatalog.implementation(for: provider) else { return [] }
        let context = self.makeSettingsContext(provider: provider)
        return impl.settingsToggles(context: context)
            .filter { $0.isVisible?() ?? true }
    }

    private func extraSettingsFields(for provider: UsageProvider) -> [ProviderSettingsFieldDescriptor] {
        let context = self.makeSettingsContext(provider: provider)
        let providerFields = ProviderCatalog.implementation(for: provider)?
            .settingsFields(context: context) ?? []
        return (providerFields + [self.otelUsageLogField(provider: provider, context: context)])
            .filter { $0.isVisible?() ?? true }
    }

    private func otelUsageLogField(
        provider: UsageProvider,
        context: ProviderSettingsContext) -> ProviderSettingsFieldDescriptor
    {
        ProviderSettingsFieldDescriptor(
            id: "\(provider.rawValue)-otel-genai-log-paths",
            title: "Usage log paths",
            subtitle: "JSON/JSONL OpenTelemetry GenAI files or folders. " +
                "The local collector ledger is read automatically.",
            kind: .plain,
            placeholder: "~/Library/Logs/ai-usage.jsonl, /path/to/otel-logs",
            binding: context.stringBinding(\.otelGenAILogPaths),
            actions: [
                ProviderSettingsActionDescriptor(
                    id: "\(provider.rawValue)-refresh-otel-usage",
                    title: "Refresh usage",
                    style: .bordered,
                    isVisible: nil,
                    perform: {
                        await context.store.refresh(trigger: .manual, forceTokenUsage: true)
                    }),
            ],
            isVisible: nil)
    }

    private func makeSettingsContext(provider: UsageProvider) -> ProviderSettingsContext {
        ProviderSettingsContext(
            provider: provider,
            settings: self.settings,
            store: self.store,
            boolBinding: { keyPath in
                Binding(
                    get: { self.settings[keyPath: keyPath] },
                    set: { self.settings[keyPath: keyPath] = $0 })
            },
            stringBinding: { keyPath in
                Binding(
                    get: { self.settings[keyPath: keyPath] },
                    set: { self.settings[keyPath: keyPath] = $0 })
            },
            statusText: { id in
                self.settingsStatusTextByID[id]
            },
            setStatusText: { id, text in
                if let text {
                    self.settingsStatusTextByID[id] = text
                } else {
                    self.settingsStatusTextByID.removeValue(forKey: id)
                }
            },
            lastAppActiveRunAt: { id in
                self.settingsLastAppActiveRunAtByID[id]
            },
            setLastAppActiveRunAt: { id, date in
                if let date {
                    self.settingsLastAppActiveRunAtByID[id] = date
                } else {
                    self.settingsLastAppActiveRunAtByID.removeValue(forKey: id)
                }
            },
            requestConfirmation: { confirmation in
                self.activeConfirmation = ProviderSettingsConfirmationState(confirmation: confirmation)
            })
    }

    private func runSettingsDidBecomeActiveHooks() {
        for provider in UsageProvider.allCases {
            for toggle in self.extraSettingsToggles(for: provider) {
                guard let hook = toggle.onAppDidBecomeActive else { continue }
                Task { @MainActor in
                    await hook()
                }
            }
        }
    }

    private func truncated(_ text: String, prefix: String, maxLength: Int = 160) -> String {
        var message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.count > maxLength {
            let idx = message.index(message.startIndex, offsetBy: maxLength)
            message = "\(message[..<idx])…"
        }
        return prefix + message
    }

    private func expandedBinding(for provider: UsageProvider) -> Binding<Bool> {
        Binding(
            get: { self.expandedErrors.contains(provider) },
            set: { expanded in
                if expanded {
                    self.expandedErrors.insert(provider)
                } else {
                    self.expandedErrors.remove(provider)
                }
            })
    }

    private func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

@MainActor
private struct ProviderSettingsConfirmationState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void

    init(confirmation: ProviderSettingsConfirmation) {
        self.title = confirmation.title
        self.message = confirmation.message
        self.confirmTitle = confirmation.confirmTitle
        self.onConfirm = confirmation.onConfirm
    }
}

@MainActor
private struct ProviderSidebarDetailView: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider
    @Bindable var store: UsageStore
    @Binding var isEnabled: Bool
    let subtitle: String
    let usageStatus: ProviderUsageStatus
    let sourceLabel: String
    let statusLabel: String
    let settingsToggles: [ProviderSettingsToggleDescriptor]
    let settingsFields: [ProviderSettingsFieldDescriptor]
    let errorDisplay: ProviderErrorDisplay?
    @Binding var isErrorExpanded: Bool
    let onCopyError: (String) -> Void
    @State private var diagnosticsCopyStatus: String?
    @State private var selectedSubview: ProviderDetailSubview = .overview
    @State private var historyMetricMode: ProviderHistoryMetricMode = .tokens
    @State private var historyMonthStart: Date = Self.monthStart(for: Date())
    @State private var historySnapshot: ProviderHistoryMonthSnapshot?
    @State private var historySelectedDay: Date?
    @State private var historyDayDetailMode: ProviderHistoryDayDetailMode = .summary
    @State private var historyIsLoading = false
    @State private var historyError: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let insightLines = ProviderInsightsComposer.lines(for: self.provider, store: self.store)
        let topModelLines = self.topModelLines
        let topProjectLines = self.topProjectLines

        ScrollView {
            VStack(alignment: .leading, spacing: ProviderListMetrics.sidebarSectionSpacing) {
                ProviderSidebarSectionCard {
                    VStack(alignment: .leading, spacing: RunicSpacing.md) {
                        HStack(alignment: .top, spacing: RunicSpacing.sm) {
                            ProviderListBrandIcon(provider: self.provider)
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                Text(self.store.metadata(for: self.provider).displayName)
                                    .font(self.fonts.title2.weight(.semibold))
                                Text(self.subtitle)
                                    .font(self.fonts.caption)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                            }
                            Spacer()
                            Toggle("Enabled", isOn: self.$isEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        Divider()

                        Picker("View", selection: self.$selectedSubview) {
                            ForEach(ProviderDetailSubview.allCases) { view in
                                Text(view.rawValue).tag(view)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if self.selectedSubview == .overview {
                    ProviderSidebarSectionCard {
                        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                ProviderSidebarSectionHeader(title: "Overview")
                                ProviderSidebarKeyValueRow(label: "Source", value: self.sourceLabel, helpText: nil)
                                ProviderSidebarKeyValueRow(label: "Updated", value: self.statusLabel, helpText: nil)
                                if let runtimeMetrics = self.runtimeMetrics {
                                    ProviderSidebarKeyValueRow(
                                        label: "Runtime",
                                        value: runtimeMetrics.lineText,
                                        helpText: runtimeMetrics.hoverText)
                                }
                                self.statusBadge
                            }

                            if !self.quickMetrics.isEmpty {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(minimum: 120), spacing: RunicSpacing.xs),
                                        GridItem(.flexible(minimum: 120), spacing: RunicSpacing.xs),
                                    ],
                                    alignment: .leading,
                                    spacing: RunicSpacing.xs)
                                {
                                    ForEach(self.quickMetrics) { metric in
                                        ProviderSidebarMetricChip(
                                            title: metric.title,
                                            value: metric.value,
                                            helpText: metric.helpText)
                                    }
                                }
                            }

                            HStack(spacing: RunicSpacing.xs) {
                                Button("Copy diagnostics") {
                                    self.copyDiagnostics()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Copy fetch path, reliability, anomaly, and budget/forecast details.")

                                if let diagnosticsCopyStatus {
                                    Text(diagnosticsCopyStatus)
                                        .font(self.fonts.caption2)
                                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                                }
                            }
                        }
                    }

                    if !insightLines.isEmpty {
                        ProviderSidebarSectionCard {
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                ProviderSidebarSectionHeader(title: "Insights")
                                ProviderInsightsView(lines: insightLines)
                            }
                        }
                    }

                    if !topModelLines.isEmpty || !topProjectLines.isEmpty {
                        ProviderSidebarSectionCard {
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                ProviderSidebarSectionHeader(title: "Activity leaders")
                                HStack(alignment: .top, spacing: RunicSpacing.md) {
                                    if !topModelLines.isEmpty {
                                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                            Text(self.modelSectionTitle)
                                                .font(self.fonts.caption2.weight(.semibold))
                                                .foregroundStyle(self.runicTheme.secondaryText)
                                            ForEach(Array(topModelLines.enumerated()), id: \.offset) { index, line in
                                                Text("\(index + 1). \(line)")
                                                    .font(self.fonts.caption)
                                                    .foregroundStyle(self.runicTheme.secondaryText)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    if !topProjectLines.isEmpty {
                                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                            Text("Projects")
                                                .font(self.fonts.caption2.weight(.semibold))
                                                .foregroundStyle(self.runicTheme.secondaryText)
                                            ForEach(Array(topProjectLines.enumerated()), id: \.offset) { index, line in
                                                Text("\(index + 1). \(line)")
                                                    .font(self.fonts.caption)
                                                    .foregroundStyle(self.runicTheme.secondaryText)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    self.historyContent
                }

                if let errorDisplay, self.isEnabled {
                    ProviderErrorView(
                        title: "Last fetch failed:",
                        display: errorDisplay,
                        isExpanded: self.$isErrorExpanded,
                        onCopy: { self.onCopyError(errorDisplay.full) })
                }

                if self.isEnabled, !self.settingsFields.isEmpty {
                    ProviderSidebarSectionCard {
                        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                            ProviderSidebarSectionHeader(title: "Settings fields")
                            ForEach(self.settingsFields) { field in
                                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                    Text(field.title)
                                        .font(self.fonts.body.weight(.medium))
                                    Text(field.subtitle)
                                        .font(self.fonts.caption)
                                        .foregroundStyle(self.runicTheme.secondaryText)
                                    switch field.kind {
                                    case .plain:
                                        TextField(field.placeholder ?? "", text: field.binding)
                                            .textFieldStyle(.roundedBorder)
                                            .font(self.fonts.callout)
                                    case .secure:
                                        SecureField(field.placeholder ?? "", text: field.binding)
                                            .textFieldStyle(.roundedBorder)
                                            .font(self.fonts.callout)
                                    }
                                    self.fieldActions(field.actions)
                                }
                            }
                        }
                    }
                }

                if self.isEnabled, !self.settingsToggles.isEmpty {
                    ProviderSidebarSectionCard {
                        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                            ProviderSidebarSectionHeader(title: "Settings toggles")
                            ForEach(self.settingsToggles) { toggle in
                                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                    Toggle(isOn: toggle.binding) {
                                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                            Text(toggle.title)
                                                .font(self.fonts.body.weight(.medium))
                                            Text(toggle.subtitle)
                                                .font(self.fonts.caption)
                                                .foregroundStyle(self.runicTheme.secondaryText)
                                        }
                                    }
                                    .toggleStyle(.checkbox)

                                    if toggle.binding.wrappedValue {
                                        if let status = toggle.statusText?(), !status.isEmpty {
                                            Text(status)
                                                .font(self.fonts.caption)
                                                .foregroundStyle(self.runicTheme.secondaryText)
                                                .padding(RunicSpacing.xs)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(
                                                    RoundedRectangle(
                                                        cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                                                        style: .continuous)
                                                        .fill(Color(
                                                            nsColor: .controlBackgroundColor).opacity(
                                                            ProviderListMetrics.sidebarMicroCardBackgroundOpacity)))
                                        }
                                        self.toggleActions(toggle.actions)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(RunicSpacing.lg)
        }
        .frame(maxWidth: .infinity, minHeight: 0, alignment: .topLeading)
        .clipped()
        .task(id: self.historyTaskID) {
            guard self.selectedSubview == .history else { return }
            await self.loadHistoryMonth()
        }
        .onChange(of: self.provider) { _, _ in
            self.selectedSubview = .overview
            self.historyMetricMode = .tokens
            self.historyMonthStart = Self.monthStart(for: Date())
            self.historySnapshot = nil
            self.historySelectedDay = nil
            self.historyDayDetailMode = .summary
            self.historyError = nil
            self.historyIsLoading = false
        }
    }
}

private extension ProviderSidebarDetailView {
    private var statusBadge: some View {
        let (color, bg) = self.statusColors
        return Text(self.usageStatus.text)
            .font(self.fonts.caption2.weight(.medium))
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxs)
            .background(bg)
            .foregroundStyle(color)
            .clipShape(.capsule)
    }

    private var statusColors: (Color, Color) {
        switch self.usageStatus.style {
        case .success: (.green, Color.green.opacity(0.15))
        case .error: (.red, Color.red.opacity(0.15))
        case .neutral: (.secondary, self.runicTheme.menuSubtleFill)
        }
    }

    private var historyTaskID: String {
        let monthKey = Int(self.historyMonthStart.timeIntervalSince1970)
        return "\(self.provider.rawValue)-\(self.selectedSubview.rawValue)-\(monthKey)"
    }

    private var historyContent: some View {
        ProviderSidebarSectionCard {
            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                HStack(alignment: .center, spacing: RunicSpacing.xs) {
                    ProviderHistoryNavigationButton(
                        systemName: "chevron.left",
                        enabled: true,
                        help: "Previous month")
                    {
                        self.shiftHistoryMonth(by: -1)
                    }

                    Text(self.historyMonthTitle)
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .frame(minWidth: 130, alignment: .leading)

                    ProviderHistoryNavigationButton(
                        systemName: "chevron.right",
                        enabled: self.canShiftHistoryForward,
                        help: "Next month")
                    {
                        self.shiftHistoryMonth(by: 1)
                    }

                    Spacer()

                    Picker("Metric", selection: self.$historyMetricMode) {
                        ForEach(ProviderHistoryMetricMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                if self.historyIsLoading, self.historySnapshot == nil {
                    HStack(spacing: RunicSpacing.xs) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading history…")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }
                    .padding(.vertical, RunicSpacing.xs)
                } else if let snapshot = self.historySnapshot {
                    if !snapshot.isSupported {
                        Text(snapshot.note ?? "History is not available for this provider yet.")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .padding(.vertical, RunicSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                                    style: .continuous)
                                    .fill(self.runicTheme.menuSubtleFill.opacity(
                                        ProviderListMetrics.sidebarCardBackgroundOpacity + 0.10)))
                    } else {
                        if let note = snapshot.note, !note.isEmpty {
                            Text(note)
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        }
                        Text(snapshot.days
                            .count == 1 ? "1 active day in \(self.historyMonthTitle)." :
                            "\(snapshot.days.count) active days in \(self.historyMonthTitle).")
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .padding(.bottom, RunicSpacing.xxs)

                        self.historyCalendarGrid
                        self.historyDayDetailCard
                    }
                } else {
                    Text("History is empty for this period.")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .padding(.vertical, RunicSpacing.xs)
                }

                if let historyError = self.historyError {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("History load failed")
                            .font(self.fonts.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        Text(historyError)
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .textSelection(.enabled)
                        Button("Retry") {
                            Task { await self.loadHistoryMonth(forceRefresh: true) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(RunicSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(
                            cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                            style: .continuous)
                            .fill(Color.red.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                            style: .continuous)
                            .strokeBorder(Color.red.opacity(0.28), lineWidth: 1))
                }

                Text(
                    "Local aggregated history only. Prompts, cookies, API keys, and raw payloads are never shown here.")
                    .font(self.fonts.caption2)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
            }
        }
    }

    private var historyCalendarGrid: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            let weekdays = self.weekdaySymbols
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: RunicSpacing.xxs), count: 7),
                spacing: RunicSpacing.xxs)
            {
                ForEach(weekdays, id: \.self) { symbol in
                    Text(symbol)
                        .font(self.fonts.caption2.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: RunicSpacing.xxs), count: 7),
                spacing: RunicSpacing.xxs)
            {
                ForEach(self.calendarDaysForMonth, id: \.self) { day in
                    let inMonth = self.historyCalendar.isDate(
                        day,
                        equalTo: self.historyMonthStart,
                        toGranularity: .month)
                    let normalizedDay = self.historyCalendar.startOfDay(for: day)
                    let summary = self.historySummaryByDay[normalizedDay]
                    let dayNumber = self.historyCalendar.component(.day, from: day)
                    let isSelected = self.historySelectedDay
                        .map { self.historyCalendar.isDate($0, inSameDayAs: day) } ?? false
                    ProviderHistoryCalendarDayCell(
                        dayNumber: dayNumber,
                        isInMonth: inMonth,
                        isSelected: isSelected,
                        hasActivity: summary != nil,
                        intensity: self.historyIntensity(for: summary),
                        action: { self.historySelectedDay = normalizedDay })
                        .help(self.historyDayHelp(for: day, summary: summary))
                }
            }
        }
    }

    private var historyDayDetailCard: some View {
        ProviderSidebarSectionCard {
            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: RunicSpacing.xs) {
                    Text("Day details")
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(0.25)
                    Spacer()
                    if self.selectedHistoryDaySummary != nil {
                        Picker("History detail", selection: self.$historyDayDetailMode) {
                            ForEach(ProviderHistoryDayDetailMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.mini)
                        .frame(maxWidth: 240)
                    }
                }

                if let selected = self.selectedHistoryDaySummary {
                    Text(selected.dayStart.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText)

                    if self.historyDayDetailMode == .summary {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 90), spacing: RunicSpacing.xs),
                                GridItem(.flexible(minimum: 90), spacing: RunicSpacing.xs),
                                GridItem(.flexible(minimum: 90), spacing: RunicSpacing.xs),
                            ],
                            alignment: .leading,
                            spacing: RunicSpacing.xs)
                        {
                            ProviderSidebarMetricChip(
                                title: "Requests",
                                value: self.decimalString(selected.requestCount),
                                helpText: "Count of requests recorded in local ledger logs.")
                            ProviderSidebarMetricChip(
                                title: "Tokens",
                                value: UsageFormatter.tokenSummaryString(selected.totals),
                                helpText: "Input, output, and cache token composition.")
                            if let spend = selected.totals.costUSD {
                                ProviderSidebarMetricChip(
                                    title: "Spend",
                                    value: UsageFormatter.usdString(spend),
                                    helpText: "Estimated day spend from ledger pricing.")
                            }
                        }

                        if self.hasModelBreakdown, let topModel = selected.topModel {
                            Text("Top model: \(self.historyModelLine(topModel))")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .textSelection(.enabled)
                        }

                        if self.hasProjectAttribution, let topProject = selected.topProject {
                            let project = self.projectDisplay(topProject)
                            Text("Top project: \(project.title)")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .textSelection(.enabled)
                                .help(project.helpText ?? "")
                        }
                    }

                    if self.historyDayDetailMode == .models {
                        if self.hasModelBreakdown, !selected.modelSummaries.isEmpty {
                            Text("Models used")
                                .font(self.fonts.caption2.weight(.medium))
                                .foregroundStyle(self.runicTheme.secondaryText)
                            ForEach(
                                Array(selected.modelSummaries.prefix(12).enumerated()),
                                id: \.offset)
                            { _, summary in
                                Text("• \(self.historyModelLine(summary))")
                                    .font(self.fonts.caption2)
                                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                                    .textSelection(.enabled)
                                    .help(self.historyModelLine(summary))
                            }
                        } else if self.hasModelBreakdown, !selected.modelsUsed.isEmpty {
                            Text("Models used: \(self.renderedModelsList(selected.modelsUsed).joined(separator: ", "))")
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                                .textSelection(.enabled)
                        } else {
                            Text(self
                                .hasModelBreakdown ? "No models recorded for this day." :
                                "Model attribution is not available for this provider.")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        }
                    }

                    if self.historyDayDetailMode == .projects {
                        if self.hasProjectAttribution, !selected.projectSummaries.isEmpty {
                            Text("Top projects")
                                .font(self.fonts.caption2.weight(.medium))
                                .foregroundStyle(self.runicTheme.secondaryText)
                            ForEach(
                                Array(selected.projectSummaries.prefix(12).enumerated()),
                                id: \.offset)
                            { _, summary in
                                let project = self.projectDisplay(summary)
                                Text("• \(self.historyProjectLine(summary))")
                                    .font(self.fonts.caption2)
                                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                                    .textSelection(.enabled)
                                    .help(project.helpText ?? "")
                            }
                        } else {
                            Text(self
                                .hasProjectAttribution ? "No projects recorded for this day." :
                                "Project attribution is not available for this provider.")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        }
                    }
                } else {
                    Text(self.historySelectedDay?
                        .formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()) ?? "No day selected")
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Text("No recorded activity for this day.")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                }
            }
        }
    }

    private var historyMonthTitle: String {
        self.historyMonthStart.formatted(.dateTime.month(.wide).year())
    }

    private var canShiftHistoryForward: Bool {
        self.historyMonthStart < Self.monthStart(for: Date())
    }

    private var historyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    private var weekdaySymbols: [String] {
        let symbols = self.historyCalendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let start = max(0, min(symbols.count - 1, self.historyCalendar.firstWeekday - 1))
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var calendarDaysForMonth: [Date] {
        guard let monthInterval = self.historyCalendar.dateInterval(of: .month, for: self.historyMonthStart),
              let firstWeek = self.historyCalendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastDayOfMonth = self.historyCalendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeek = self.historyCalendar.dateInterval(of: .weekOfMonth, for: lastDayOfMonth)
        else {
            return []
        }

        var days: [Date] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            days.append(cursor)
            guard let next = self.historyCalendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    private var historySummaryByDay: [Date: ProviderHistoryDaySnapshot] {
        guard let snapshot = self.historySnapshot else { return [:] }
        var map: [Date: ProviderHistoryDaySnapshot] = [:]
        for day in snapshot.days {
            map[self.historyCalendar.startOfDay(for: day.dayStart)] = day
        }
        return map
    }

    private var selectedHistoryDaySummary: ProviderHistoryDaySnapshot? {
        guard let snapshot = self.historySnapshot else { return nil }
        guard let selectedDay = self.historySelectedDay else { return snapshot.days.last }
        return snapshot.days.first { self.historyCalendar.isDate($0.dayStart, inSameDayAs: selectedDay) }
    }

    private var historyMaxMetricValue: Double {
        guard let snapshot = self.historySnapshot, !snapshot.days.isEmpty else { return 0 }
        return snapshot.days.reduce(0) { max($0, self.historyMetricValue(for: $1)) }
    }

    private func historyMetricValue(for day: ProviderHistoryDaySnapshot) -> Double {
        switch self.historyMetricMode {
        case .tokens:
            Double(day.totals.totalTokens)
        case .cost:
            max(0, day.totals.costUSD ?? 0)
        case .requests:
            Double(day.requestCount)
        }
    }

    private func historyIntensity(for day: ProviderHistoryDaySnapshot?) -> Double {
        guard let day else { return 0 }
        let maxValue = self.historyMaxMetricValue
        guard maxValue > 0 else { return 0.15 }
        return min(1, max(0.15, self.historyMetricValue(for: day) / maxValue))
    }

    private func historyDayHelp(for day: Date, summary: ProviderHistoryDaySnapshot?) -> String {
        var lines: [String] = [day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())]
        guard let summary else {
            lines.append("No recorded activity")
            return lines.joined(separator: "\n")
        }
        lines.append("Requests: \(self.decimalString(summary.requestCount))")
        lines.append("Tokens: \(UsageFormatter.tokenSummaryString(summary.totals))")
        if let spend = summary.totals.costUSD {
            lines.append("Spend: \(UsageFormatter.usdString(spend))")
        }
        if self.hasModelBreakdown, let topModel = summary.topModel {
            var modelLine = "Top model: \(UsageFormatter.modelDisplayName(topModel.model))"
            if let context = UsageFormatter.modelContextLabel(for: topModel.model) {
                modelLine += " · \(context)"
            }
            lines.append(modelLine)
        }
        if self.hasModelBreakdown, !summary.modelSummaries.isEmpty {
            let modelCount = min(3, summary.modelSummaries.count)
            for summary in summary.modelSummaries.prefix(modelCount) {
                let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
                var line = "Model: \(UsageFormatter.modelDisplayName(summary.model)) · \(tokens) tok"
                if let context = UsageFormatter.modelContextLabel(for: summary.model) {
                    line += " · \(context)"
                }
                lines.append(line)
            }
        }
        if self.hasProjectAttribution, let topProject = summary.topProject {
            var projectLine = "Top project: \(self.projectDisplay(topProject).title)"
            if let cost = topProject.totals.costUSD {
                projectLine += " · \(UsageFormatter.usdString(cost))"
            }
            lines.append(projectLine)
        }
        return lines.joined(separator: "\n")
    }

    private func renderedModelsList(_ modelsUsed: [String]) -> [String] {
        var seen: Set<String> = []
        var rendered: [String] = []
        for model in modelsUsed {
            let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            var text = UsageFormatter.modelDisplayName(trimmed)
            if let context = UsageFormatter.modelContextLabel(for: trimmed) {
                text += " \(context)"
            }
            rendered.append(text)
        }
        return rendered
    }

    private func historyModelLine(_ summary: UsageLedgerModelSummary) -> String {
        self.usageLine(
            title: UsageFormatter.modelDisplayName(summary.model),
            totals: summary.totals,
            requests: summary.entryCount,
            model: summary.model)
    }

    private func historyProjectLine(_ summary: UsageLedgerProjectSummary) -> String {
        let project = self.projectDisplay(summary)
        return self.usageLine(
            title: project.title,
            totals: summary.totals,
            requests: summary.entryCount)
    }

    private func shiftHistoryMonth(by delta: Int) {
        guard delta != 0 else { return }
        guard let shifted = self.historyCalendar.date(byAdding: .month, value: delta, to: self.historyMonthStart) else {
            return
        }
        let candidate = Self.monthStart(for: shifted)
        if delta > 0, candidate > Self.monthStart(for: Date()) {
            return
        }
        self.historyMonthStart = candidate
        self.historySnapshot = nil
        self.historySelectedDay = nil
        self.historyError = nil
    }

    private static func monthStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func loadHistoryMonth(forceRefresh: Bool = false) async {
        guard !self.historyIsLoading else { return }
        self.historyIsLoading = true
        self.historyError = nil
        let snapshot = await self.store.providerHistoryMonth(
            provider: self.provider,
            monthStart: self.historyMonthStart,
            forceRefresh: forceRefresh)
        self.historySnapshot = snapshot
        self.historyError = snapshot.error
        self.historyIsLoading = false
        self.selectDefaultHistoryDay(from: snapshot)
    }

    private func selectDefaultHistoryDay(from snapshot: ProviderHistoryMonthSnapshot) {
        guard !snapshot.days.isEmpty else {
            self.historySelectedDay = self.historyCalendar.startOfDay(for: self.historyMonthStart)
            return
        }
        if let selected = self.historySelectedDay,
           snapshot.days.contains(where: { self.historyCalendar.isDate($0.dayStart, inSameDayAs: selected) })
        {
            self.historySelectedDay = self.historyCalendar.startOfDay(for: selected)
            return
        }
        self.historySelectedDay = snapshot.days.map(\.dayStart).max()
    }

    private struct ProjectDisplay {
        let title: String
        let helpText: String?
    }

    private func projectDisplay(_ summary: UsageLedgerProjectSummary) -> ProjectDisplay {
        let displayName = RunicProjectDisplay.name(for: summary)
        let source = summary.projectNameSource ?? .unknown
        let confidence = summary.projectNameConfidence ?? .none
        let shouldAnnotateSource = source != .projectName && source != .budgetOverride
        let shouldAnnotateConfidence = confidence != .high
        let isUnknown = RunicProjectDisplay.isUnattributed(displayName)

        var details: [String] = []
        if shouldAnnotateSource {
            details.append("source: \(self.projectSourceLabel(source))")
        }
        if shouldAnnotateConfidence {
            details.append("confidence: \(self.projectConfidenceLabel(confidence))")
        }
        if isUnknown, let fingerprint = self.projectIDFingerprint(summary.projectID) {
            details.append("id: \(fingerprint)")
        }
        if let provenance = self.trimmed(summary.projectNameProvenance) {
            details.append("via: \(provenance)")
        }
        return ProjectDisplay(
            title: displayName,
            helpText: details.isEmpty ? nil : details.joined(separator: "\n"))
    }

    private func projectSourceLabel(_ source: UsageLedgerProjectNameSource) -> String {
        switch source {
        case .projectName: "project name"
        case .projectID: "project id"
        case .inferredFromPath: "path-derived"
        case .inferredFromName: "name-derived"
        case .budgetOverride: "budget override"
        case .unknown: "unknown"
        }
    }

    private func projectConfidenceLabel(_ confidence: UsageLedgerProjectNameConfidence) -> String {
        switch confidence {
        case .high: "high"
        case .medium: "medium"
        case .low: "low"
        case .none: "none"
        }
    }

    private func projectIDFingerprint(_ projectID: String?) -> String? {
        guard let projectID = projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !projectID.isEmpty else {
            return nil
        }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in projectID.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01B3
        }
        return String(format: "%08llx", hash)
    }

    @ViewBuilder
    private func fieldActions(_ actions: [ProviderSettingsActionDescriptor]) -> some View {
        let visible = actions.filter { $0.isVisible?() ?? true }
        if !visible.isEmpty {
            HStack(spacing: RunicSpacing.xs) {
                ForEach(visible) { action in
                    Button(action.title) {
                        Task { @MainActor in await action.perform() }
                    }
                    .applyProviderSettingsButtonStyle(action.style)
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func toggleActions(_ actions: [ProviderSettingsActionDescriptor]) -> some View {
        let visible = actions.filter { $0.isVisible?() ?? true }
        if !visible.isEmpty {
            HStack(spacing: RunicSpacing.xs) {
                ForEach(visible) { action in
                    Button(action.title) {
                        Task { @MainActor in await action.perform() }
                    }
                    .applyProviderSettingsButtonStyle(action.style)
                    .controlSize(.small)
                }
            }
        }
    }

    private struct QuickMetricItem: Identifiable {
        let id: String
        let title: String
        let value: String
        let helpText: String?
    }

    private var quickMetrics: [QuickMetricItem] {
        var items: [QuickMetricItem] = []
        let snapshot = self.store.snapshot(for: self.provider)
        let tokenSnapshot = self.store.tokenSnapshot(for: self.provider)
        let hasModelBreakdown = self.hasModelBreakdown
        let hasProjectAttribution = self.hasProjectAttribution

        if let today = self
            .tokenWindowValue(tokens: tokenSnapshot?.sessionTokens, cost: tokenSnapshot?.sessionCostUSD)
        {
            items.append(QuickMetricItem(
                id: "today",
                title: "Today",
                value: today,
                helpText: "Session cost and tokens."))
        }
        if let last30 = self.tokenWindowValue(
            tokens: tokenSnapshot?.last30DaysTokens,
            cost: tokenSnapshot?.last30DaysCostUSD)
        {
            items.append(QuickMetricItem(
                id: "30d",
                title: "30d",
                value: last30,
                helpText: "Last 30 days cost and tokens."))
        }
        if let spend = self.providerSpendValue(snapshot?.providerCost) {
            items.append(QuickMetricItem(
                id: "spend",
                title: "Spend",
                value: spend,
                helpText: "Provider billing usage."))
        }
        if hasModelBreakdown, let topModel = self.store.ledgerTopModel(for: self.provider) {
            let modelName = UsageFormatter.modelDisplayName(topModel.model)
            var value = self.modelLineValue(
                title: modelName,
                totals: topModel.totals,
                requests: topModel.entryCount)
            if let context = UsageFormatter.modelContextLabel(for: topModel.model) {
                value += " · \(context)"
            }
            items.append(QuickMetricItem(
                id: "top-model",
                title: "Top model",
                value: value,
                helpText: "Highest token usage model in the active insights window."))
        } else if !hasModelBreakdown, let windowModel = self.topWindowModel {
            let modelName = UsageFormatter.modelDisplayName(windowModel.label)
            let used = Int(windowModel.window.usedPercent.rounded())
            items.append(QuickMetricItem(
                id: "top-model-window",
                title: hasModelBreakdown ? "Top model" : "Top window",
                value: "\(modelName) · \(used)% used",
                helpText: hasModelBreakdown ?
                    "Most constrained model/category from live quota windows."
                    : "Top quota window from live fetch response."))
        }
        if hasProjectAttribution, let topProject = self.store.ledgerTopProject(for: self.provider) {
            let project = self.projectDisplay(topProject)
            let value = self.topProjectSummaryValue(topProject)
            items.append(QuickMetricItem(
                id: "top-project",
                title: "Top project",
                value: "\(project.title) · \(value)",
                helpText: "Highest token usage project in the active insights window."))
        }
        if let coverage = ProviderInsightsComposer.coverageSummaryLabel(for: self.provider, store: self.store) {
            let value = coverage.replacingOccurrences(of: "usage: ", with: "")
            items.append(QuickMetricItem(
                id: "coverage",
                title: "Data",
                value: value,
                helpText: "Provider coverage for model-level usage, token metrics, and project attribution."))
        }
        return items
    }

    private func tokenWindowValue(tokens: Int?, cost: Double?) -> String? {
        var parts: [String] = []
        if let cost, cost.isFinite, cost >= 0 {
            parts.append(UsageFormatter.usdString(cost))
        }
        if let tokens, tokens >= 0 {
            parts.append("\(UsageFormatter.tokenCountString(tokens)) tok")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private func providerSpendValue(_ providerCost: ProviderCostSnapshot?) -> String? {
        guard let providerCost else { return nil }
        let used = UsageFormatter.currencyString(providerCost.used, currencyCode: providerCost.currencyCode)
        if providerCost.limit > 0 {
            let limitText = UsageFormatter.currencyString(providerCost.limit, currencyCode: providerCost.currencyCode)
            return "\(used) / \(limitText)"
        }
        return used
    }

    private var topModelLines: [String] {
        let ranked = self.store.ledgerModelBreakdown(for: self.provider).sorted { lhs, rhs in
            if lhs.totals.totalTokens == rhs.totals.totalTokens {
                return UsageFormatter.modelDisplayName(lhs.model) < UsageFormatter.modelDisplayName(rhs.model)
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        if !ranked.isEmpty {
            guard self.hasModelBreakdown else {
                return []
            }
            return ranked.prefix(3).map { summary in
                let name = UsageFormatter.modelDisplayName(summary.model)
                return self.usageLine(
                    title: name,
                    totals: summary.totals,
                    requests: summary.entryCount,
                    model: summary.model)
            }
        }
        guard !self.hasModelBreakdown else {
            return []
        }
        return self.windowModelLines
    }

    private var modelSectionTitle: String {
        self.hasModelBreakdown ? "Models" : "Quota windows"
    }

    private var effectiveUsageCoverage: ProviderUsageCoverage {
        ProviderInsightsComposer.effectiveCoverage(for: self.provider, store: self.store)
    }

    private var hasModelBreakdown: Bool {
        self.effectiveUsageCoverage.supportsModelBreakdown
    }

    private var hasProjectAttribution: Bool {
        self.effectiveUsageCoverage.supportsProjectAttribution
    }

    private var topProjectLines: [String] {
        guard self.hasProjectAttribution else {
            return []
        }
        let ranked = self.store.ledgerProjectBreakdown(for: self.provider).sorted { lhs, rhs in
            if lhs.totals.totalTokens == rhs.totals.totalTokens {
                return RunicProjectDisplay.name(for: lhs) < RunicProjectDisplay.name(for: rhs)
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        return ranked.prefix(3).map { summary in
            let project = RunicProjectDisplay.name(for: summary)
            return self.usageLine(title: project, totals: summary.totals, requests: summary.entryCount)
        }
    }

    private func usageLine(
        title: String,
        totals: UsageLedgerTotals,
        requests: Int,
        model: String? = nil) -> String
    {
        let tokens = UsageFormatter.tokenSummaryString(totals)
        var parts = ["\(title)", "\(tokens)", "\(requests) req"]
        if let cost = totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: totals.totalTokens) {
                parts.append("~\(per1K)")
            }
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: requests) {
                parts.append("~\(perReq)")
            }
        }
        if let model, let context = UsageFormatter.modelContextLabel(for: model) {
            parts.append(context)
        }
        return parts.joined(separator: " · ")
    }

    private func topProjectSummaryValue(_ summary: UsageLedgerProjectSummary) -> String {
        var parts: [String] = []
        parts.append(UsageFormatter.tokenSummaryString(summary.totals))
        parts.append("\(summary.entryCount) req")
        if let cost = summary.totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: summary.entryCount) {
                parts.append("~\(perReq)")
            }
        }
        return parts.joined(separator: " · ")
    }

    private func modelLineValue(title: String, totals: UsageLedgerTotals, requests: Int) -> String {
        var parts: [String] = [title]
        parts.append(UsageFormatter.tokenSummaryString(totals))
        parts.append("\(requests) req")
        if let cost = totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: totals.totalTokens) {
                parts.append("~\(per1K)")
            }
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: requests) {
                parts.append("~\(perReq)")
            }
        }
        return parts.joined(separator: " · ")
    }

    private var windowModelLines: [String] {
        self.labeledQuotaWindows(from: self.store.snapshot(for: self.provider)).prefix(3).map { item in
            let modelName = UsageFormatter.modelDisplayName(item.label)
            let used = Int(item.window.usedPercent.rounded())
            let remaining = Int(item.window.remainingPercent.rounded())
            var parts = [modelName, "\(used)% used", "\(remaining)% left"]
            if let resetsAt = item.window.resetsAt {
                parts.append("reset \(UsageFormatter.resetCountdownDescription(from: resetsAt))")
            } else if let resetDescription = item.window.resetDescription?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !resetDescription.isEmpty
            {
                parts.append(resetDescription)
            }
            return parts.joined(separator: " · ")
        }
    }

    private var topWindowModel: (label: String, window: RateWindow)? {
        self.labeledQuotaWindows(from: self.store.snapshot(for: self.provider)).first
    }

    private func labeledQuotaWindows(from snapshot: UsageSnapshot?) -> [(label: String, window: RateWindow)] {
        guard let snapshot else { return [] }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self)
        var seen: Set<String> = []
        var labeled: [(label: String, window: RateWindow)] = []

        for window in windows {
            guard let label = window.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty
            else {
                continue
            }
            let normalized = label.lowercased()
            guard seen.insert(normalized).inserted else { continue }
            labeled.append((label, window))
        }

        return labeled.sorted { lhs, rhs in
            if lhs.window.usedPercent == rhs.window.usedPercent {
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
            return lhs.window.usedPercent > rhs.window.usedPercent
        }
    }

    private func decimalString(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private struct RuntimeMetricsData {
        let lineText: String
        let hoverText: String?
    }

    private var runtimeMetrics: RuntimeMetricsData? {
        let attempts = self.store.fetchAttempts(for: self.provider)
        guard !attempts.isEmpty || self.store.snapshot(for: self.provider) != nil else {
            return nil
        }

        var parts: [String] = []
        if let updatedAt = self.store.snapshot(for: self.provider)?.updatedAt {
            parts.append("success \(updatedAt.relativeDescription())")
        } else {
            parts.append("no success yet")
        }

        var hoverText: String?
        if !attempts.isEmpty {
            let retryCount = self.retryCount(from: attempts)
            if retryCount > 0 {
                parts.append("retry \(retryCount)")
            }
            if let activeAttempt = self.activeAttempt(from: attempts) {
                parts.append(Self.fetchKindLabel(activeAttempt.kind))
                if let strategyID = self.trimmed(activeAttempt.strategyID) {
                    hoverText = "Strategy: \(strategyID)"
                }
            }
        }

        return RuntimeMetricsData(
            lineText: parts.joined(separator: " · "),
            hoverText: hoverText)
    }

    private func retryCount(from attempts: [ProviderFetchAttempt]) -> Int {
        guard !attempts.isEmpty else { return 0 }
        if let successIndex = attempts
            .firstIndex(where: { $0.wasAvailable && self.trimmed($0.errorDescription) == nil })
        {
            return max(0, successIndex)
        }
        return max(0, attempts.count - 1)
    }

    private func activeAttempt(from attempts: [ProviderFetchAttempt]) -> ProviderFetchAttempt? {
        guard !attempts.isEmpty else { return nil }
        return attempts.first(where: { $0.wasAvailable && self.trimmed($0.errorDescription) == nil }) ??
            attempts.last(where: { $0.wasAvailable }) ??
            attempts.last
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func fetchKindLabel(_ kind: ProviderFetchKind) -> String {
        switch kind {
        case .cli: "cli"
        case .web: "web"
        case .oauth: "oauth"
        case .apiToken: "api"
        case .api: "api"
        case .localProbe: "local"
        case .webDashboard: "web"
        }
    }

    private func copyDiagnostics() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(self.diagnosticsReport, forType: .string)
        self.diagnosticsCopyStatus = "Copied"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.diagnosticsCopyStatus = nil
        }
    }

    private var diagnosticsReport: String {
        let metadata = self.store.metadata(for: self.provider)
        let attempts = self.store.fetchAttempts(for: self.provider)
        let snapshot = self.store.snapshot(for: self.provider)
        let forecast = self.store.ledgerSpendForecast(for: self.provider)
        let topProjectForecast = self.store.ledgerTopProjectSpendForecast(for: self.provider)
        let reliability = self.store.ledgerReliabilityScore(for: self.provider)
        let anomaly = self.store.ledgerAnomalySummary(for: self.provider)
        let iso = ISO8601DateFormatter()

        var lines: [String] = []
        lines.append("# \(metadata.displayName) Diagnostics")
        lines.append("provider: \(self.provider.rawValue)")
        lines.append("generated_at: \(iso.string(from: Date()))")
        lines.append("enabled: \(self.isEnabled ? "true" : "false")")
        lines.append("source: \(self.sourceLabel)")
        lines.append("updated: \(self.statusLabel)")
        if let runtime = self.runtimeMetrics?.lineText {
            lines.append("runtime: \(runtime)")
        }

        if let snapshot {
            lines.append("")
            lines.append("usage_snapshot:")
            lines.append("- updated_at: \(iso.string(from: snapshot.updatedAt))")
            lines.append("- primary_used_percent: \(Int(snapshot.primary.usedPercent.rounded()))")
            if let minutes = snapshot.primary.windowMinutes, minutes > 0 {
                lines.append("- primary_window_minutes: \(minutes)")
            }
            if let reset = snapshot.primary.resetsAt {
                lines.append("- primary_resets_at: \(iso.string(from: reset))")
            }
            if let cost = snapshot.providerCost {
                let used = UsageFormatter.currencyString(cost.used, currencyCode: cost.currencyCode)
                lines.append("- provider_spend_used: \(used)")
                if cost.limit > 0 {
                    let limit = UsageFormatter.currencyString(cost.limit, currencyCode: cost.currencyCode)
                    lines.append("- provider_spend_limit: \(limit)")
                }
                if let period = self.trimmed(cost.period) {
                    lines.append("- provider_spend_period: \(period)")
                }
            }
        }

        lines.append("")
        lines.append("fetch_path:")
        if attempts.isEmpty {
            lines.append("- none")
        } else {
            for attempt in attempts {
                let state = if !attempt.wasAvailable {
                    "unavailable"
                } else if let error = self.trimmed(attempt.errorDescription) {
                    "failed: \(error)"
                } else {
                    "ok"
                }
                lines.append("- \(attempt.strategyID) [\(Self.fetchKindLabel(attempt.kind))] \(state)")
            }
        }

        if let forecast {
            lines.append("")
            lines.append("provider_forecast:")
            lines.append("- projected_30d: \(UsageFormatter.usdString(forecast.projected30DayCostUSD))")
            lines.append("- average_daily: \(UsageFormatter.usdString(forecast.averageDailyCostUSD))")
            if let p50 = forecast.projectedCostP50USD {
                lines.append("- p50: \(UsageFormatter.usdString(p50))")
            }
            if let p80 = forecast.projectedCostP80USD {
                lines.append("- p80: \(UsageFormatter.usdString(p80))")
            }
            if let p95 = forecast.projectedCostP95USD {
                lines.append("- p95: \(UsageFormatter.usdString(p95))")
            }
            if let limit = forecast.budgetLimitUSD, limit > 0 {
                lines.append("- budget_limit: \(UsageFormatter.usdString(limit))")
                lines.append("- budget_status: \(self.budgetStatusText(forecast))")
            }
        }

        if let topProjectForecast {
            lines.append("")
            lines.append("top_project_forecast:")
            if let name = self.trimmed(topProjectForecast.projectName) {
                lines.append("- project: \(name)")
            }
            lines.append("- projected_30d: \(UsageFormatter.usdString(topProjectForecast.projected30DayCostUSD))")
            if let limit = topProjectForecast.budgetLimitUSD, limit > 0 {
                lines.append("- budget_limit: \(UsageFormatter.usdString(limit))")
                lines.append("- budget_status: \(self.budgetStatusText(topProjectForecast))")
            }
        }

        if let reliability {
            lines.append("")
            lines.append("reliability:")
            lines.append("- score: \(reliability.score)/100")
            lines.append("- grade: \(reliability.grade)")
            lines.append("- summary: \(reliability.summary)")
            if let signal = self.trimmed(reliability.primarySignal) {
                lines.append("- signal: \(signal)")
            }
        }

        if let anomaly {
            lines.append("")
            lines.append("anomaly:")
            if let spend = anomaly.spendAnomaly {
                lines.append("- spend: \(spend.severity.label) +\(Int((spend.percentIncrease * 100).rounded()))%")
            }
            if let token = anomaly.tokenAnomaly {
                lines.append("- tokens: \(token.severity.label) +\(Int((token.percentIncrease * 100).rounded()))%")
            }
            if let explanation = anomaly.explanation {
                lines.append("- headline: \(explanation.headline)")
                for detail in explanation.details {
                    lines.append("- detail: \(detail)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func budgetStatusText(_ forecast: UsageLedgerSpendForecast) -> String {
        if let eta = forecast.budgetETAInDays {
            return self.budgetBreachETAText(days: eta)
        }
        if forecast.budgetWillBreach {
            return "Breach risk"
        }
        return "On track"
    }

    private func budgetBreachETAText(days: Double) -> String {
        guard days.isFinite else { return "Breach ETA unavailable" }
        if days <= 0 { return "Breach now" }
        let now = Date()
        let etaDate = now.addingTimeInterval(days * 24 * 60 * 60)
        let countdown = UsageFormatter.resetCountdownDescription(from: etaDate, now: now)
        if countdown == "now" { return "Breach now" }
        return "Breach \(countdown)"
    }
}

// swiftlint:disable:this file_length
