import AppKit
import RunicCore
import SwiftUI

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
