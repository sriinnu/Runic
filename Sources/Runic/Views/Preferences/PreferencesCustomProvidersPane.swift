import AppKit
import RunicCore
import SwiftUI

@MainActor
struct CustomProvidersPane: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var providers: [CustomProviderConfig] = []
    @State private var editorSheet: EditorSheet?
    @State private var confirmDelete: CustomProviderConfig?
    @State private var actionError: String?

    /// Single sheet state so add/edit never stack two `.sheet` modifiers on one view
    /// (a known SwiftUI bug where the second silently wins).
    private enum EditorSheet: Identifiable {
        case add
        case edit(CustomProviderConfig)

        var id: String {
            switch self {
            case .add: "add"
            case let .edit(provider): "edit-\(provider.id)"
            }
        }
    }

    var body: some View {
        PreferencesListPane {
            VStack(alignment: .leading, spacing: RunicSpacing.lg) {
                // Header with add button
                HStack {
                    Text("Custom API Providers")
                        .font(self.fonts.headline)

                    Spacer()

                    Button {
                        self.editorSheet = .add
                    } label: {
                        Label("Add Provider", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)

                if self.providers.isEmpty {
                    RunicEmptyStateView(
                        mood: .resting,
                        title: "No custom providers configured",
                        hint: "Add a custom API provider to track usage from APIs not natively supported by Runic.",
                        layout: .prominent)
                } else {
                    // Provider list
                    ForEach(self.providers) { provider in
                        CustomProviderRow(
                            provider: provider,
                            snapshot: self.store.customProviderSnapshots[provider.id],
                            onToggle: { enabled in self.toggleProvider(provider, enabled: enabled) },
                            onEdit: { self.editorSheet = .edit(provider) },
                            onDelete: { self.confirmDelete = provider })
                            .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)

                        if provider.id != self.providers.last?.id {
                            Divider()
                                .padding(.leading, PreferencesLayoutMetrics.paneHorizontal + 44)
                        }
                    }
                }
            }
            .padding(.vertical, RunicSpacing.md)
        }
        .onAppear {
            self.loadProviders()
        }
        .sheet(item: self.$editorSheet) { sheet in
            switch sheet {
            case .add:
                CustomProviderEditorView(
                    provider: nil,
                    onSave: { provider in
                        let error = self.addProvider(provider)
                        if error == nil { self.editorSheet = nil }
                        return error
                    },
                    onCancel: { self.editorSheet = nil })
            case let .edit(provider):
                CustomProviderEditorView(
                    provider: provider,
                    onSave: { updated in
                        let error = self.updateProvider(updated)
                        if error == nil { self.editorSheet = nil }
                        return error
                    },
                    onCancel: { self.editorSheet = nil })
            }
        }
        .alert("Couldn't save provider", isPresented: Binding(
            get: { self.actionError != nil },
            set: { if !$0 { self.actionError = nil } }))
        {
            Button("OK", role: .cancel) { self.actionError = nil }
        } message: {
            if let actionError { Text(actionError) }
        }
        .alert("Delete Provider", isPresented: Binding(
                get: { self.confirmDelete != nil },
                set: { if !$0 { self.confirmDelete = nil } }))
        {
            Button("Cancel", role: .cancel) { self.confirmDelete = nil }
            Button("Delete", role: .destructive) {
                if let provider = self.confirmDelete {
                    self.deleteProvider(provider)
                }
                self.confirmDelete = nil
            }
            } message: {
                if let provider = self.confirmDelete {
                    Text("Are you sure you want to delete '\(provider.name)'? This action cannot be undone.")
                }
            }
    }

    // MARK: - Actions

    private func loadProviders() {
        self.providers = CustomProviderStore.getAllProviders()
    }

    /// Returns nil on success, or an error message to surface. Callers dismiss the
    /// editor sheet only on success (keeping the user's input on failure). Add/edit
    /// errors are shown INLINE in the editor — which sits in front of the pane —
    /// because an alert attached to the pane can be occluded by the open sheet on
    /// macOS and silently never appear.
    private func addProvider(_ provider: CustomProviderConfig) -> String? {
        do {
            try CustomProviderStore.addProvider(provider)
            self.loadProviders()
            Task { await self.store.refreshCustomProvider(id: provider.id) }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func updateProvider(_ provider: CustomProviderConfig) -> String? {
        do {
            try CustomProviderStore.updateProvider(provider)
            self.loadProviders()
            Task { await self.store.refreshCustomProvider(id: provider.id) }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func deleteProvider(_ provider: CustomProviderConfig) {
        do {
            try CustomProviderStore.removeProvider(id: provider.id)
            try? KeychainCustomProviderTokenStore().deleteToken(account: provider.auth.tokenKeychain)
            self.loadProviders()
            self.store.clearCustomProviderSnapshot(id: provider.id)
        } catch {
            self.actionError = error.localizedDescription
        }
    }

    private func toggleProvider(_ provider: CustomProviderConfig, enabled: Bool) {
        var updated = provider
        updated.enabled = enabled
        // No sheet is open here, so the pane alert surfaces correctly.
        if let error = self.updateProvider(updated) { self.actionError = error }
    }
}

// MARK: - Custom Provider Row

@MainActor
private struct CustomProviderRow: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let provider: CustomProviderConfig
    let snapshot: CustomProviderSnapshot?
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: RunicSpacing.sm) {
            Image(systemName: self.provider.icon)
                .font(.system(size: 24))
                .foregroundStyle(self.iconColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(self.provider.name)
                    .font(self.fonts.body)
                    .fontWeight(.medium)

                if let snapshot = self.snapshot {
                    if let error = snapshot.error {
                        Text(error)
                            .font(self.fonts.caption)
                            .foregroundStyle(.red)
                    } else {
                        HStack(spacing: 4) {
                            if let quota = snapshot.usageData.quota, let used = snapshot.usageData.used {
                                let percent = CustomProviderUsageDisplay.percentUsed(used: used, quota: quota)
                                Text("\(percent)% used")
                                    .font(self.fonts.caption)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                            }
                            Text("•")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                            Text("Updated \(snapshot.updatedAt.relativeDescription())")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                        }
                    }
                } else {
                    Text("No data")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                }
            }

            Spacer()

            HStack(spacing: RunicSpacing.xs) {
                Button { self.onEdit() } label: {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Edit provider")

                Button { self.onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Delete provider")

                Toggle("", isOn: Binding(
                    get: { self.provider.enabled },
                    set: { self.onToggle($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
        .padding(.vertical, RunicSpacing.sm)
    }

    private var iconColor: Color {
        if !self.provider.enabled { return .secondary }
        if let colorHex = provider.colorHex, let nsColor = NSColor(hexString: colorHex) {
            return Color(nsColor: nsColor)
        }
        return .accentColor
    }
}

// MARK: - Helper Extensions

extension Date {
    fileprivate func relativeDescription() -> String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        if interval < 60 { return "just now" } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}

extension NSColor {
    fileprivate convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Custom Provider Editor View (Simplified)

@MainActor
private struct CustomProviderEditorView: View {
    @Environment(\.runicFonts) private var fonts
    let provider: CustomProviderConfig?
    /// Returns nil on success, or an error message shown inline in this editor.
    let onSave: (CustomProviderConfig) -> String?
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var icon: String = "server.rack"
    @State private var apiToken: String = ""
    @State private var usageEndpointURL: String = ""
    @State private var saveError: String?
    private let tokenStore: CustomProviderTokenStoring = KeychainCustomProviderTokenStore()

    var body: some View {
        VStack {
            Text(self.provider == nil ? "Add Custom Provider" : "Edit Provider")
                .font(self.fonts.headline)
                .padding()
            Form {
                TextField("Provider Name", text: self.$name)
                TextField("Icon (SF Symbol)", text: self.$icon)
                SecureField("API Token", text: self.$apiToken)
                TextField("Usage Endpoint URL", text: self.$usageEndpointURL)
            }
            .padding()
            if let saveError {
                Text(saveError)
                    .font(self.fonts.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            HStack {
                Button("Cancel") { self.onCancel() }
                Button(self.provider == nil ? "Add" : "Save") {
                    self.save()
                }
                .disabled(!self.canSave)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            if let p = provider {
                self.name = p.name
                self.icon = p.icon
                self.usageEndpointURL = p.endpoints.usage?.url ?? ""
            }
        }
    }

    private var canSave: Bool {
        !self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !self.usageEndpointURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (self.provider != nil || !self.apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func save() {
        let id = self.provider?.id ?? UUID().uuidString
        let account = self.provider?.auth.tokenKeychain ?? "custom-\(id)-api-token"
        do {
            try self.tokenStore.storeToken(self.apiToken, account: account)
            let error = self.onSave(CustomProviderConfig(
                id: id,
                name: self.name.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: self.icon.trimmingCharacters(in: .whitespacesAndNewlines),
                enabled: self.provider?.enabled ?? true,
                auth: AuthConfig(
                    type: .bearer,
                    headerName: "Authorization",
                    tokenKeychain: account),
                endpoints: EndpointConfig(usage: UsageEndpoint(
                    url: self.usageEndpointURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    mapping: ResponseMapping()))))
            self.saveError = error
        } catch {
            self.saveError = "Could not save API token: \(error.localizedDescription)"
        }
    }
}
