import RunicCore
import SwiftUI

@MainActor
struct ProviderListView: View {
    @Environment(\.runicFonts) private var fonts
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
        let topInset = addTopPadding ? ProviderListMetrics.sectionEdgeInset : base.top
        let bottomInset = addBottomPadding
            ? ProviderListMetrics.sectionEdgeInset
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
