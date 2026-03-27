import AppKit
import RunicCore
import SwiftUI

@MainActor
struct CustomProvidersPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var providers: [CustomProviderConfig] = []
    @State private var showingAddProvider = false
    @State private var editingProvider: CustomProviderConfig?
    @State private var confirmDelete: CustomProviderConfig?

    var body: some View {
        PreferencesListPane {
            VStack(alignment: .leading, spacing: RunicSpacing.lg) {
                // Header with add button
                HStack {
                    Text("Custom API Providers")
                        .font(RunicFont.headline)

                    Spacer()

                    Button {
                        self.showingAddProvider = true
                    } label: {
                        Label("Add Provider", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)

                if self.providers.isEmpty {
                    VStack(spacing: RunicSpacing.md) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No custom providers configured")
                            .font(RunicFont.headline)
                            .foregroundStyle(.secondary)

                        Text("Add a custom API provider to track usage from APIs not natively supported by Runic.")
                            .font(RunicFont.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RunicSpacing.xl)
                } else {
                    // Provider list
                    ForEach(self.providers) { provider in
                        CustomProviderRow(
                            provider: provider,
                            snapshot: self.store.customProviderSnapshots[provider.id],
                            onToggle: { enabled in self.toggleProvider(provider, enabled: enabled) },
                            onEdit: { self.editingProvider = provider },
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
        .sheet(isPresented: self.$showingAddProvider) {
            CustomProviderEditorView(
                provider: nil,
                onSave: { provider in
                    self.addProvider(provider)
                    self.showingAddProvider = false
                },
                onCancel: { self.showingAddProvider = false })
        }
        .sheet(item: self.$editingProvider) { provider in
            CustomProviderEditorView(
                provider: provider,
                onSave: { updated in
                    self.updateProvider(updated)
                    self.editingProvider = nil
                },
                onCancel: { self.editingProvider = nil })
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

    private func addProvider(_ provider: CustomProviderConfig) {
        do {
            try CustomProviderStore.addProvider(provider)
            self.loadProviders()
            Task { await self.store.refreshCustomProvider(id: provider.id) }
        } catch {
            print("Failed to add provider: \(error)")
        }
    }

    private func updateProvider(_ provider: CustomProviderConfig) {
        do {
            try CustomProviderStore.updateProvider(provider)
            self.loadProviders()
            Task { await self.store.refreshCustomProvider(id: provider.id) }
        } catch {
            print("Failed to update provider: \(error)")
        }
    }

    private func deleteProvider(_ provider: CustomProviderConfig) {
        do {
            try CustomProviderStore.removeProvider(id: provider.id)
            self.loadProviders()
            self.store.clearCustomProviderSnapshot(id: provider.id)
        } catch {
            print("Failed to delete provider: \(error)")
        }
    }

    private func toggleProvider(_ provider: CustomProviderConfig, enabled: Bool) {
        var updated = provider
        updated.enabled = enabled
        self.updateProvider(updated)
    }
}

// MARK: - Custom Provider Row

@MainActor
private struct CustomProviderRow: View {
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
                    .font(RunicFont.body)
                    .fontWeight(.medium)

                if let snapshot = self.snapshot {
                    if let error = snapshot.error {
                        Text(error)
                            .font(RunicFont.caption)
                            .foregroundStyle(.red)
                    } else {
                        HStack(spacing: 4) {
                            if let quota = snapshot.usageData.quota, let used = snapshot.usageData.used {
                                let percent = quota > 0 ? (used / quota) * 100 : 0
                                Text("\(Int(percent))% used")
                                    .font(RunicFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("•")
                                .font(RunicFont.caption)
                                .foregroundStyle(.tertiary)
                            Text("Updated \(snapshot.updatedAt.relativeDescription())")
                                .font(RunicFont.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Text("No data")
                        .font(RunicFont.caption)
                        .foregroundStyle(.tertiary)
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
        if interval < 60 { return "just now" }
        else if interval < 3600 { return "\(Int(interval / 60))m ago" }
        else if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        else { return "\(Int(interval / 86400))d ago" }
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
    let provider: CustomProviderConfig?
    let onSave: (CustomProviderConfig) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var icon: String = "server.rack"
    @State private var apiToken: String = ""
    @State private var usageEndpointURL: String = ""

    var body: some View {
        VStack {
            Text(self.provider == nil ? "Add Custom Provider" : "Edit Provider")
                .font(RunicFont.headline)
                .padding()
            Form {
                TextField("Provider Name", text: self.$name)
                TextField("Icon (SF Symbol)", text: self.$icon)
                SecureField("API Token", text: self.$apiToken)
                TextField("Usage Endpoint URL", text: self.$usageEndpointURL)
            }
            .padding()
            HStack {
                Button("Cancel") { self.onCancel() }
                Button(self.provider == nil ? "Add" : "Save") {
                    // Simplified save logic
                    self.onSave(CustomProviderConfig(
                        id: self.provider?.id ?? UUID().uuidString,
                        name: self.name,
                        icon: self.icon,
                        enabled: self.provider?.enabled ?? true,
                        auth: AuthConfig(
                            type: .bearer,
                            headerName: "Authorization",
                            tokenKeychain: "custom-\(self.name)"),
                        endpoints: EndpointConfig(usage: UsageEndpoint(
                            url: self.usageEndpointURL,
                            mapping: ResponseMapping()))))
                }
                .disabled(self.name.isEmpty || self.apiToken.isEmpty || self.usageEndpointURL.isEmpty)
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
}
