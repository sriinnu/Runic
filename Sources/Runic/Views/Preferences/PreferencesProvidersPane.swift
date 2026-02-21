import AppKit
import RunicCore
import SwiftUI

private struct ProviderUsageStatus {
    let text: String
    let style: Style

    enum Style {
        case success
        case error
        case neutral
    }
}

private enum ProviderListMetrics {
    static let contentInset: CGFloat = PreferencesLayoutMetrics.paneHorizontal
    static let rowSpacing: CGFloat = RunicSpacing.sm  // 12pt - horizontal spacing between elements
    static let providerVerticalSpacing: CGFloat = RunicSpacing.md  // 16pt - vertical spacing between providers
    static let sectionSpacing: CGFloat = RunicSpacing.md  // 16pt - spacing between provider sections
    static let reorderHandleSize: CGFloat = 12
    static let reorderDotSize: CGFloat = 4
    static let reorderDotSpacing: CGFloat = 4
    static let rowInsets = EdgeInsets(
        top: RunicSpacing.xs,  // 8pt
        leading: contentInset,
        bottom: RunicSpacing.xs,  // 8pt
        trailing: contentInset)
    static let dividerBottomInset: CGFloat = RunicSpacing.xs  // 8pt
    static let checkboxSize: CGFloat = 20
    static let iconSize: CGFloat = 32  // 32pt
    static let dividerLeadingInset: CGFloat = contentInset
    static let dividerTrailingInset: CGFloat = contentInset
    static let fieldHorizontalPadding: CGFloat = RunicSpacing.xs  // 8pt
    static let fieldVerticalPadding: CGFloat = RunicSpacing.xxs  // 4pt
    static let errorCardPadding: CGFloat = RunicSpacing.sm  // 12pt
    static let statusBadgePaddingH: CGFloat = RunicSpacing.xs  // 8pt
    static let statusBadgePaddingV: CGFloat = RunicSpacing.xxs  // 4pt
    static let rowBackgroundCornerRadius: CGFloat = RunicCornerRadius.md
    static let errorCardCornerRadius: CGFloat = RunicCornerRadius.sm
}

@MainActor
struct ProvidersPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var expandedErrors: Set<UsageProvider> = []
    @State private var settingsStatusTextByID: [String: String] = [:]
    @State private var settingsLastAppActiveRunAtByID: [String: Date] = [:]
    @State private var activeConfirmation: ProviderSettingsConfirmationState?
    @State private var sidebarSelection: UsageProvider?

    private var providers: [UsageProvider] { self.settings.orderedProviders() }

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

    // MARK: - Sidebar layout

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(selection: self.$sidebarSelection) {
                ForEach(self.providers, id: \.self) { provider in
                    ProviderSidebarRow(
                        provider: provider,
                        store: self.store,
                        isEnabled: self.binding(for: provider).wrappedValue)
                        .tag(provider)
                }
                .onMove { fromOffsets, toOffset in
                    self.settings.moveProvider(fromOffsets: fromOffsets, toOffset: toOffset)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160, idealWidth: 180)
            .onAppear {
                if self.sidebarSelection == nil {
                    self.sidebarSelection = self.providers.first
                }
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
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
        let version = self.store.version(for: provider)
        var versionText = version ?? "not detected"
        if provider == .claude, let parenRange = versionText.range(of: "(") {
            versionText = versionText[..<parenRange.lowerBound].trimmingCharacters(in: .whitespaces)
        }

        if cliName == "codex" {
            return versionText
        }

        // Cursor is web-based, no CLI version to detect
        if provider == .cursor || provider == .minimax {
            return "web"
        }
        if provider == .zai {
            return "api"
        }

        var detail = "\(cliName) \(versionText)"
        if provider == .antigravity {
            detail += " • experimental"
        }
        return detail
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
        return "not yet"
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
        guard let impl = ProviderCatalog.implementation(for: provider) else { return [] }
        let context = self.makeSettingsContext(provider: provider)
        return impl.settingsFields(context: context)
            .filter { $0.isVisible?() ?? true }
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
private struct ProviderListView: View {
    let providers: [UsageProvider]
    @Bindable var store: UsageStore
    let isEnabled: (UsageProvider) -> Binding<Bool>
    let subtitle: (UsageProvider) -> String
    let usageStatus: (UsageProvider) -> ProviderUsageStatus
    let sourceLabel: (UsageProvider) -> String
    let statusLabel: (UsageProvider) -> String
    let settingsToggles: (UsageProvider) -> [ProviderSettingsToggleDescriptor]
    let settingsFields: (UsageProvider) -> [ProviderSettingsFieldDescriptor]
    let errorDisplay: (UsageProvider) -> ProviderErrorDisplay?
    let isErrorExpanded: (UsageProvider) -> Binding<Bool>
    let onCopyError: (String) -> Void
    let moveProviders: (IndexSet, Int) -> Void

    var body: some View {
        List {
            ForEach(self.providers, id: \.self) { provider in
                let fields = self.settingsFields(provider)
                let toggles = self.settingsToggles(provider)
                let isEnabled = self.isEnabled(provider).wrappedValue
                let isFirstProvider = provider == self.providers.first
                let isLastProvider = provider == self.providers.last
                let shouldShowDivider = provider != self.providers.last
                let showDividerOnProviderRow = shouldShowDivider &&
                    (!isEnabled || (fields.isEmpty && toggles.isEmpty))
                let providerAddsBottomPadding = isLastProvider && (!isEnabled || (fields.isEmpty && toggles.isEmpty))

                ProviderListProviderRowView(
                    provider: provider,
                    store: self.store,
                    isEnabled: self.isEnabled(provider),
                    subtitle: self.subtitle(provider),
                    usageStatus: self.usageStatus(provider),
                    sourceLabel: self.sourceLabel(provider),
                    statusLabel: self.statusLabel(provider),
                    errorDisplay: self.isEnabled(provider).wrappedValue ? self.errorDisplay(provider) : nil,
                    isErrorExpanded: self.isErrorExpanded(provider),
                    onCopyError: self.onCopyError)
                    .padding(.bottom, showDividerOnProviderRow ? ProviderListMetrics.dividerBottomInset : 0)
                    .listRowInsets(self.rowInsets(
                        withDivider: showDividerOnProviderRow,
                        addTopPadding: isFirstProvider,
                        addBottomPadding: providerAddsBottomPadding))
                    .listRowSeparator(.hidden)
                    .providerSectionDivider(isVisible: showDividerOnProviderRow)

                if isEnabled {
                    let lastFieldID = fields.last?.id
                    ForEach(fields) { field in
                        let isLastField = field.id == lastFieldID
                        let showDivider = shouldShowDivider && toggles.isEmpty && isLastField
                        let fieldAddsBottomPadding = isLastProvider && toggles.isEmpty && isLastField

                        ProviderListFieldRowView(provider: provider, field: field)
                            .id(self.rowID(provider: provider, suffix: field.id))
                            .padding(.bottom, showDivider ? ProviderListMetrics.dividerBottomInset : 0)
                            .listRowInsets(self.rowInsets(
                                withDivider: showDivider,
                                addTopPadding: false,
                                addBottomPadding: fieldAddsBottomPadding))
                            .listRowSeparator(.hidden)
                            .providerSectionDivider(isVisible: showDivider)
                    }
                    let lastToggleID = toggles.last?.id
                    ForEach(toggles) { toggle in
                        let isLastToggle = toggle.id == lastToggleID
                        let showDivider = shouldShowDivider && isLastToggle
                        let toggleAddsBottomPadding = isLastProvider && isLastToggle

                        ProviderListToggleRowView(provider: provider, toggle: toggle)
                            .id(self.rowID(provider: provider, suffix: toggle.id))
                            .padding(.bottom, showDivider ? ProviderListMetrics.dividerBottomInset : 0)
                            .listRowInsets(self.rowInsets(
                                withDivider: showDivider,
                                addTopPadding: false,
                                addBottomPadding: toggleAddsBottomPadding))
                            .listRowSeparator(.hidden)
                            .providerSectionDivider(isVisible: showDivider)
                    }
                }
            }
            .onMove { fromOffsets, toOffset in
                self.moveProviders(fromOffsets, toOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ProviderListScrollInsetFixer())
    }

    private func rowInsets(withDivider: Bool, addTopPadding: Bool, addBottomPadding: Bool) -> EdgeInsets {
        let base = ProviderListMetrics.rowInsets
        let topInset = addTopPadding ? PreferencesLayoutMetrics.paneVertical : base.top
        let bottomInset = addBottomPadding
            ? PreferencesLayoutMetrics.paneVertical
            : (withDivider ? ProviderListMetrics.dividerBottomInset : base.bottom)
        return EdgeInsets(
            top: topInset,
            leading: base.leading,
            bottom: bottomInset,
            trailing: base.trailing)
    }

    private func rowID(provider: UsageProvider, suffix: String) -> String {
        "\(provider.rawValue)-\(suffix)"
    }
}

@MainActor
private struct ProviderListBrandIcon: View {
    let provider: UsageProvider

    var body: some View {
        if let brand = ProviderBrandIcon.image(for: self.provider, size: ProviderListMetrics.iconSize) {
            Image(nsImage: brand)
                .resizable()
                .scaledToFit()
                .frame(width: ProviderListMetrics.iconSize, height: ProviderListMetrics.iconSize)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "circle.dotted")
                .font(.system(size: ProviderListMetrics.iconSize, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

@MainActor
private struct ProviderListProviderRowView: View {
    let provider: UsageProvider
    @Bindable var store: UsageStore
    @Binding var isEnabled: Bool
    let subtitle: String
    let usageStatus: ProviderUsageStatus
    let sourceLabel: String
    let statusLabel: String
    let errorDisplay: ProviderErrorDisplay?
    @Binding var isErrorExpanded: Bool
    let onCopyError: (String) -> Void
    @State private var isHovering = false
    @FocusState private var isToggleFocused: Bool

    var body: some View {
        let titleIndent = ProviderListMetrics.iconSize + RunicSpacing.sm  // Updated to use RunicSpacing.sm
        let isRefreshing = self.store.refreshingProviders.contains(self.provider)
        let showReorderHandle = self.isHovering || self.isToggleFocused

        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Toggle("", isOn: self.$isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }
                .focused(self.$isToggleFocused)

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    HStack(alignment: .center, spacing: RunicSpacing.sm) {
                        ProviderListBrandIcon(provider: self.provider)
                            .alignmentGuide(.top) { d in d[VerticalAlignment.center] }
                        Text(self.store.metadata(for: self.provider).displayName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .alignmentGuide(.top) { d in d[VerticalAlignment.center] }
                    }
                    Text(self.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, titleIndent)

                    HStack(alignment: .center, spacing: RunicSpacing.xs) {
                        Text(self.sourceLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                            Text("Refreshing…")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            self.usageStatusBadge
                                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                        }
                    }
                    .padding(.leading, titleIndent)
                }
                .contentShape(Rectangle())
                .onTapGesture { self.isEnabled.toggle() }

                if let errorDisplay {
                    ProviderErrorView(
                        title: "Last \(self.store.metadata(for: self.provider).displayName) fetch failed:",
                        display: errorDisplay,
                        isExpanded: self.$isErrorExpanded,
                        onCopy: { self.onCopyError(errorDisplay.full) })
                        .padding(.top, RunicSpacing.sm)
                        .padding(.leading, titleIndent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(RunicSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.rowBackgroundCornerRadius, style: .continuous)
                .fill(self.rowBackgroundColor)
        )
        .overlay(alignment: .topLeading) {
            ProviderListReorderHandle(isVisible: showReorderHandle)
                .offset(
                    x: -(ProviderListMetrics.reorderHandleSize + ProviderListMetrics.rowSpacing),
                    y: RunicSpacing.sm)
        }
        .onHover { isHovering in
            self.isHovering = isHovering
        }
    }

    private var usageStatusBadge: some View {
        let (color, backgroundColor) = self.usageStatusColors

        return Text(self.usageStatus.text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, ProviderListMetrics.statusBadgePaddingH)
            .padding(.vertical, ProviderListMetrics.statusBadgePaddingV)
            .background(backgroundColor)
            .foregroundStyle(color)
            .cornerRadius(RunicCornerRadius.xs)
    }

    private var usageStatusColors: (Color, Color) {
        switch self.usageStatus.style {
        case .success:
            return (.green, Color.green.opacity(0.15))
        case .error:
            return (.red, Color.red.opacity(0.15))
        case .neutral:
            return (.secondary, Color(nsColor: .controlBackgroundColor))
        }
    }

    private var rowBackgroundColor: Color {
        if self.isHovering {
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        } else if self.isEnabled {
            return Color(nsColor: .controlBackgroundColor).opacity(0.3)
        }
        return Color.clear
    }
}

@MainActor
private struct ProviderListReorderHandle: View {
    let isVisible: Bool

    var body: some View {
        VStack(spacing: ProviderListMetrics.reorderDotSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: ProviderListMetrics.reorderDotSpacing) {
                    Circle()
                        .frame(
                            width: ProviderListMetrics.reorderDotSize,
                            height: ProviderListMetrics.reorderDotSize)
                    Circle()
                        .frame(
                            width: ProviderListMetrics.reorderDotSize,
                            height: ProviderListMetrics.reorderDotSize)
                }
            }
        }
        .frame(width: ProviderListMetrics.reorderHandleSize, height: ProviderListMetrics.reorderHandleSize)
        .foregroundStyle(.tertiary)
        .opacity(self.isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: self.isVisible)
        .help("Drag to reorder")
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

@MainActor
private struct ProviderListSectionDividerView: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.5))
            .frame(height: 1)
            .padding(.leading, ProviderListMetrics.dividerLeadingInset)
            .padding(.trailing, ProviderListMetrics.dividerTrailingInset)
    }
}

extension View {
    @ViewBuilder
    fileprivate func providerSectionDivider(isVisible: Bool) -> some View {
        overlay(alignment: .bottom) {
            if isVisible {
                ProviderListSectionDividerView()
            }
        }
    }
}

@MainActor
private struct ProviderListToggleRowView: View {
    let provider: UsageProvider
    let toggle: ProviderSettingsToggleDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Toggle("", isOn: self.toggle.binding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }

            HStack(alignment: .top, spacing: RunicSpacing.sm) {
                Color.clear
                    .frame(width: ProviderListMetrics.iconSize, height: ProviderListMetrics.iconSize)

                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text(self.toggle.title)
                            .font(.body.weight(.medium))
                        Text(self.toggle.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if self.toggle.binding.wrappedValue {
                        if let status = self.toggle.statusText?(), !status.isEmpty {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(RunicSpacing.xs)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                )
                        }

                        let actions = self.toggle.actions.filter { $0.isVisible?() ?? true }
                        if !actions.isEmpty {
                            HStack(spacing: RunicSpacing.xs) {
                                ForEach(actions) { action in
                                    Button(action.title) {
                                        Task { @MainActor in
                                            await action.perform()
                                        }
                                    }
                                    .applyProviderSettingsButtonStyle(action.style)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(RunicSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.rowBackgroundCornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.2))
        )
        .onChange(of: self.toggle.binding.wrappedValue) { _, enabled in
            guard let onChange = self.toggle.onChange else { return }
            Task { @MainActor in
                await onChange(enabled)
            }
        }
        .task(id: self.toggle.binding.wrappedValue) {
            guard self.toggle.binding.wrappedValue else { return }
            guard let onAppear = self.toggle.onAppearWhenEnabled else { return }
            await onAppear()
        }
    }
}

@MainActor
private struct ProviderListFieldRowView: View {
    let provider: UsageProvider
    let field: ProviderSettingsFieldDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Color.clear
                .frame(width: ProviderListMetrics.checkboxSize, height: ProviderListMetrics.checkboxSize)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }

            HStack(alignment: .top, spacing: RunicSpacing.sm) {
                Color.clear
                    .frame(width: ProviderListMetrics.iconSize, height: ProviderListMetrics.iconSize)

                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text(self.field.title)
                            .font(.body.weight(.medium))
                        Text(self.field.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    switch self.field.kind {
                    case .plain:
                        TextField(self.field.placeholder ?? "", text: self.field.binding)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                            .padding(.horizontal, ProviderListMetrics.fieldHorizontalPadding)
                            .padding(.vertical, ProviderListMetrics.fieldVerticalPadding)
                    case .secure:
                        SecureField(self.field.placeholder ?? "", text: self.field.binding)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                            .padding(.horizontal, ProviderListMetrics.fieldHorizontalPadding)
                            .padding(.vertical, ProviderListMetrics.fieldVerticalPadding)
                    }

                    let actions = self.field.actions.filter { $0.isVisible?() ?? true }
                    if !actions.isEmpty {
                        HStack(spacing: RunicSpacing.xs) {
                            ForEach(actions) { action in
                                Button(action.title) {
                                    Task { @MainActor in
                                        await action.perform()
                                    }
                                }
                                .applyProviderSettingsButtonStyle(action.style)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(RunicSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.rowBackgroundCornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.2))
        )
    }
}

extension View {
    @ViewBuilder
    fileprivate func applyProviderSettingsButtonStyle(_ style: ProviderSettingsActionDescriptor.Style) -> some View {
        switch style {
        case .bordered:
            self.buttonStyle(.bordered)
        case .link:
            self.buttonStyle(.link)
        }
    }
}

private struct ProviderErrorDisplay: Sendable {
    let preview: String
    let full: String
}

@MainActor
private struct ProviderListScrollInsetFixer: NSViewRepresentable {
    private final class HitTestIgnoringView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> NSView {
        HitTestIgnoringView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            guard let scrollView = Self.findScrollView(from: nsView) else { return }
            if scrollView.automaticallyAdjustsContentInsets {
                scrollView.automaticallyAdjustsContentInsets = false
            }
            let zeroInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            let currentContentInsets = scrollView.contentInsets
            if currentContentInsets.top != 0 || currentContentInsets.left != 0 ||
               currentContentInsets.bottom != 0 || currentContentInsets.right != 0 {
                scrollView.contentInsets = zeroInsets
            }
            let currentScrollerInsets = scrollView.scrollerInsets
            if currentScrollerInsets.top != 0 || currentScrollerInsets.left != 0 ||
               currentScrollerInsets.bottom != 0 || currentScrollerInsets.right != 0 {
                scrollView.scrollerInsets = zeroInsets
            }
        }
    }

    private static func findScrollView(from view: NSView) -> NSScrollView? {
        var current: NSView? = view
        while let candidate = current {
            if let scroll = candidate as? NSScrollView { return scroll }
            if let found = candidate.subviews.compactMap({ $0 as? NSScrollView }).first {
                return found
            }
            current = candidate.superview
        }
        return nil
    }
}

@MainActor
private struct ProviderErrorView: View {
    let title: String
    let display: ProviderErrorDisplay
    @Binding var isExpanded: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                Text(self.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    self.onCopy()
                } label: {
                    HStack(alignment: .center, spacing: RunicSpacing.xxs) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                        Text("Copy")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copy error to clipboard")
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
            }

            Text(self.display.preview)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(RunicSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .fill(Color.orange.opacity(0.08))
                )

            if self.display.preview != self.display.full {
                Button(self.isExpanded ? "Hide details" : "Show details") { self.isExpanded.toggle() }
                    .buttonStyle(.link)
                    .font(.callout)
            }

            if self.isExpanded {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(self.display.full)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(ProviderListMetrics.errorCardPadding)
                }
                .frame(maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(ProviderListMetrics.errorCardPadding)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.03))
        )
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

// MARK: - Sidebar layout views

@MainActor
private struct ProviderSidebarRow: View {
    let provider: UsageProvider
    @Bindable var store: UsageStore
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
            if let brand = ProviderBrandIcon.image(for: self.provider, size: 20) {
                Image(nsImage: brand)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(self.isEnabled ? .primary : .tertiary)
            } else {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20, height: 20)
            }
            Text(self.store.metadata(for: self.provider).displayName)
                .font(.body)
                .foregroundStyle(self.isEnabled ? .primary : .secondary)
                .lineLimit(1)
        }
        .opacity(self.isEnabled ? 1 : 0.6)
    }
}

@MainActor
private struct ProviderSidebarDetailView: View {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RunicSpacing.md) {
                // Header
                HStack(spacing: RunicSpacing.sm) {
                    ProviderListBrandIcon(provider: self.provider)
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text(self.store.metadata(for: self.provider).displayName)
                            .font(.title2.weight(.semibold))
                        Text(self.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Enabled", isOn: self.$isEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider()

                // Status
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    HStack(spacing: RunicSpacing.xs) {
                        Text("Source:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(self.sourceLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    self.statusBadge
                }

                // Error
                if let errorDisplay, self.isEnabled {
                    ProviderErrorView(
                        title: "Last fetch failed:",
                        display: errorDisplay,
                        isExpanded: self.$isErrorExpanded,
                        onCopy: { self.onCopyError(errorDisplay.full) })
                }

                // Settings fields
                if self.isEnabled, !self.settingsFields.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                        ForEach(self.settingsFields) { field in
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                Text(field.title)
                                    .font(.body.weight(.medium))
                                Text(field.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                switch field.kind {
                                case .plain:
                                    TextField(field.placeholder ?? "", text: field.binding)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.callout)
                                case .secure:
                                    SecureField(field.placeholder ?? "", text: field.binding)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.callout)
                                }
                                self.fieldActions(field.actions)
                            }
                        }
                    }
                }

                // Settings toggles
                if self.isEnabled, !self.settingsToggles.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                        ForEach(self.settingsToggles) { toggle in
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                Toggle(isOn: toggle.binding) {
                                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                        Text(toggle.title)
                                            .font(.body.weight(.medium))
                                        Text(toggle.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)

                                if toggle.binding.wrappedValue {
                                    if let status = toggle.statusText?(), !status.isEmpty {
                                        Text(status)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(RunicSpacing.xs)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5)))
                                    }
                                    self.toggleActions(toggle.actions)
                                }
                            }
                        }
                    }
                }
            }
            .padding(RunicSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusBadge: some View {
        let (color, bg) = self.statusColors
        return Text(self.usageStatus.text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxs)
            .background(bg)
            .foregroundStyle(color)
            .cornerRadius(RunicCornerRadius.xs)
    }

    private var statusColors: (Color, Color) {
        switch self.usageStatus.style {
        case .success: return (.green, Color.green.opacity(0.15))
        case .error: return (.red, Color.red.opacity(0.15))
        case .neutral: return (.secondary, Color(nsColor: .controlBackgroundColor))
        }
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
}
