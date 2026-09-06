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
    @State private var expandedAddAccount: Set<UsageProvider> = []

    var body: some View {
        List {
            ForEach(self.providers, id: \.self) { provider in
                let fields = self.settingsFields(provider)
                let toggles = self.settingsToggles(provider)
                let isEnabled = self.isEnabled(provider).wrappedValue
                let isFirstProvider = provider == self.providers.first
                let isLastProvider = provider == self.providers.last
                let shouldShowDivider = provider != self.providers.last
                let cnSibling = provider.chinaSibling
                let hasTrailingContent = (isEnabled && !(fields.isEmpty && toggles.isEmpty)) || cnSibling != nil
                let showDividerOnProviderRow = shouldShowDivider && !hasTrailingContent
                let providerAddsBottomPadding = isLastProvider && !hasTrailingContent

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
                        let showDivider = shouldShowDivider && toggles.isEmpty && isLastField && cnSibling == nil
                        let fieldAddsBottomPadding = isLastProvider && toggles.isEmpty && isLastField &&
                            cnSibling == nil

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
                        let showDivider = shouldShowDivider && isLastToggle && cnSibling == nil
                        let toggleAddsBottomPadding = isLastProvider && isLastToggle && cnSibling == nil

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

                if let cnSibling {
                    self.regionalSiblingSection(
                        sibling: cnSibling,
                        shouldShowDivider: shouldShowDivider,
                        isLastProvider: isLastProvider)
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

    @ViewBuilder
    private func regionalSiblingSection(
        sibling: UsageProvider,
        shouldShowDivider: Bool,
        isLastProvider: Bool) -> some View
    {
        let siblingEnabled = self.isEnabled(sibling).wrappedValue
        let siblingFields = self.settingsFields(sibling)

        if siblingEnabled {
            ProviderListProviderRowView(
                provider: sibling,
                store: self.store,
                isEnabled: self.isEnabled(sibling),
                subtitle: self.subtitle(sibling),
                usageStatus: self.usageStatus(sibling),
                sourceLabel: self.sourceLabel(sibling),
                statusLabel: self.statusLabel(sibling),
                errorDisplay: self.errorDisplay(sibling),
                isErrorExpanded: self.isErrorExpanded(sibling),
                onCopyError: self.onCopyError)
                .padding(.leading, ProviderListMetrics.regionalSiblingIndent)
                .listRowInsets(self.rowInsets(withDivider: false, addTopPadding: false, addBottomPadding: false))
                .listRowSeparator(.hidden)

            let lastFieldID = siblingFields.last?.id
            ForEach(siblingFields) { field in
                let isLastField = field.id == lastFieldID
                let showDivider = shouldShowDivider && isLastField
                let addsBottomPadding = isLastProvider && isLastField

                ProviderListFieldRowView(provider: sibling, field: field)
                    .id(self.rowID(provider: sibling, suffix: field.id))
                    .padding(.leading, ProviderListMetrics.regionalSiblingIndent)
                    .padding(.bottom, showDivider ? ProviderListMetrics.dividerBottomInset : 0)
                    .listRowInsets(self.rowInsets(
                        withDivider: showDivider,
                        addTopPadding: false,
                        addBottomPadding: addsBottomPadding))
                    .listRowSeparator(.hidden)
                    .providerSectionDivider(isVisible: showDivider)
            }
        } else {
            ProviderListAddRegionalAccountView(
                provider: sibling,
                displayName: self.store.metadata(for: sibling).displayName,
                isExpanded: self.addAccountExpandedBinding(for: sibling),
                fields: siblingFields)
                .padding(.leading, ProviderListMetrics.regionalSiblingIndent)
                .padding(.bottom, shouldShowDivider ? ProviderListMetrics.dividerBottomInset : 0)
                .listRowInsets(self.rowInsets(
                    withDivider: shouldShowDivider,
                    addTopPadding: false,
                    addBottomPadding: isLastProvider))
                .listRowSeparator(.hidden)
                .providerSectionDivider(isVisible: shouldShowDivider)
        }
    }

    private func addAccountExpandedBinding(for provider: UsageProvider) -> Binding<Bool> {
        Binding(
            get: { self.expandedAddAccount.contains(provider) },
            set: { expanded in
                if expanded {
                    self.expandedAddAccount.insert(provider)
                } else {
                    self.expandedAddAccount.remove(provider)
                }
            })
    }
}
