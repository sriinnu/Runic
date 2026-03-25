import AppKit
import RunicCore
import Security
import SwiftUI

@MainActor
struct IntegrationsPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    @AppStorage("vaayuAPIServerEnabled") private var vaayuAPIServerEnabled = false
    @AppStorage("vaayuAPIServerPort") private var vaayuAPIServerPort = 3000
    @State private var vaayuAPIKey = ""
    @AppStorage("defaultWebhookURL") private var defaultWebhookURL = ""
    @AppStorage("webhookFormat") private var webhookFormat = "slack"
    @AppStorage("githubIntegrationEnabled") private var githubIntegrationEnabled = false
    @AppStorage("githubRepositoryPath") private var githubRepositoryPath = ""

    @State private var mcpServers: [MCPServer] = []
    @State private var showingAddServerSheet = false
    @State private var newServerName = ""
    @State private var newServerPort = 8001
    @State private var testWebhookResult: String?
    @State private var generatedAPIKey: String?

    struct MCPServer: Identifiable, Codable, Hashable {
        let id: String
        var name: String
        var isRunning: Bool
        var port: Int

        var statusIndicator: String { "●" }
        var statusColor: Color { self.isRunning ? .green : .red }
    }

    var body: some View {
        PreferencesPane {
            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("vaayu Integration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    HStack {
                        Toggle("API Server", isOn: self.$vaayuAPIServerEnabled)
                            .toggleStyle(.switch)

                        Spacer()

                        if self.vaayuAPIServerEnabled {
                            Text("Running on port \(self.vaayuAPIServerPort)")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        } else {
                            Text("Stopped")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if self.vaayuAPIServerEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Port number")
                                .font(.body)

                            TextField("Port", value: self.$vaayuAPIServerPort, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 150)

                            Text("Default: 3000. Restart required after changing port.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("API Key")
                                    .font(.body)

                                Spacer()

                                if self.vaayuAPIKey.isEmpty {
                                    Button("Generate Key") {
                                        self.generateAPIKey()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                } else {
                                    Button {
                                        self.copyToClipboard(self.vaayuAPIKey)
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }

                            if !self.vaayuAPIKey.isEmpty {
                                Text(self.maskedAPIKey)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(.secondary)
                                    .padding(RunicSpacing.xs)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(RunicCornerRadius.xs)
                            }

                            if let generatedKey = self.generatedAPIKey {
                                Text("New key generated: \(generatedKey)")
                                    .font(.footnote)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Text("Exposes Runic usage data via REST API for external integrations.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("MCP Servers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(spacing: RunicSpacing.xs) {
                    HStack {
                        Text("Configured servers")
                            .font(.body)
                        Spacer()
                        Button {
                            self.showingAddServerSheet = true
                        } label: {
                            Label("Add Server", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if self.mcpServers.isEmpty {
                        VStack(spacing: RunicSpacing.xs) {
                            Image(systemName: "terminal")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                            Text("No MCP servers yet")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Add a server to manage connection details")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RunicSpacing.lg)
                    } else {
                        ForEach(self.mcpServers) { server in
                            HStack(spacing: RunicSpacing.sm) {
                                Text(server.statusIndicator)
                                    .foregroundStyle(server.statusColor)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                    Text(server.name)
                                        .font(.body)
                                    Text("Port \(server.port)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 4) {
                                    Button(server.isRunning ? "Stop" : "Start") {
                                        self.toggleMCPServer(server)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button {
                                        self.copyConnectionCommand(server)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)

                                    Button {
                                        self.removeMCPServer(server)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)
                                    .foregroundStyle(.red)
                                }
                            }
                            .padding(RunicSpacing.xs)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(RunicCornerRadius.sm)
                        }
                    }
                }

                Text("MCP servers enable Claude Desktop and other tools to access Runic data.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Webhooks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default webhook URL")
                            .font(.body)

                        TextField("https://hooks.slack.com/services/...", text: self.$defaultWebhookURL)
                            .textFieldStyle(.roundedBorder)

                        Text("Used for all alerts unless overridden in alert rule settings.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Webhook format")
                            .font(.body)

                        Picker("", selection: self.$webhookFormat) {
                            Text("Slack").tag("slack")
                            Text("Discord").tag("discord")
                            Text("Generic").tag("generic")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)

                        Text("Formats webhook payloads for different platforms.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: RunicSpacing.xs) {
                        Button("Test Webhook") {
                            self.testWebhook()
                        }
                        .buttonStyle(.bordered)
                        .disabled(self.defaultWebhookURL.isEmpty)

                        if let result = self.testWebhookResult {
                            Text(result)
                                .font(.footnote)
                                .foregroundStyle(result.contains("Success") ? .green : .red)
                        }
                    }
                }
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("GitHub Integration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    PreferenceToggleRow(
                        title: "Link commits to usage",
                        subtitle: "Correlates AI usage with git commits for project-level insights.",
                        binding: self.$githubIntegrationEnabled)

                    if self.githubIntegrationEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Repository path")
                                .font(.body)

                            HStack {
                                TextField("/path/to/repo", text: self.$githubRepositoryPath)
                                    .textFieldStyle(.roundedBorder)

                                Button("Auto-detect") {
                                    self.autoDetectRepository()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if !self.githubRepositoryPath.isEmpty {
                                if FileManager.default.fileExists(atPath: self.githubRepositoryPath + "/.git") {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Valid Git repository")
                                            .font(.footnote)
                                            .foregroundStyle(.green)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                        Text("Not a valid Git repository")
                                            .font(.footnote)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            self.loadMCPServers()
            self.vaayuAPIKey = VaayuKeychainHelper.load() ?? ""
            // Migrate any existing value out of UserDefaults
            let defaults = UserDefaults.standard
            if let legacyKey = defaults.string(forKey: "vaayuAPIKey"), !legacyKey.isEmpty {
                VaayuKeychainHelper.save(legacyKey)
                self.vaayuAPIKey = legacyKey
                defaults.removeObject(forKey: "vaayuAPIKey")
            }
        }
        .onChange(of: self.vaayuAPIKey) { _, newValue in
            if newValue.isEmpty {
                VaayuKeychainHelper.delete()
            } else {
                VaayuKeychainHelper.save(newValue)
            }
        }
        .sheet(isPresented: self.$showingAddServerSheet) {
            AddMCPServerSheet(
                name: self.$newServerName,
                port: self.$newServerPort,
                onAdd: {
                    self.addMCPServer()
                    self.showingAddServerSheet = false
                },
                onCancel: {
                    self.showingAddServerSheet = false
                })
        }
    }

    private var maskedAPIKey: String {
        guard self.vaayuAPIKey.count > 8 else { return self.vaayuAPIKey }
        let prefix = String(self.vaayuAPIKey.prefix(4))
        let suffix = String(self.vaayuAPIKey.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }

    private func generateAPIKey() {
        let key = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        self.vaayuAPIKey = key
        self.generatedAPIKey = key

        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self.generatedAPIKey = nil
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func toggleMCPServer(_ server: MCPServer) {
        if let index = self.mcpServers.firstIndex(where: { $0.id == server.id }) {
            self.mcpServers[index].isRunning.toggle()
            self.persistMCPServers()
        }
    }

    private func copyConnectionCommand(_ server: MCPServer) {
        let command = "mcp connect localhost:\(server.port)"
        self.copyToClipboard(command)
    }

    private func testWebhook() {
        guard !self.defaultWebhookURL.isEmpty else { return }

        Task {
            await MainActor.run { self.testWebhookResult = "Testing..." }
            guard let url = URL(string: self.defaultWebhookURL) else {
                await MainActor.run { self.testWebhookResult = "Invalid URL" }
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 5
            request.httpBody = Data("{\"text\":\"Runic webhook test\"}".utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    self.testWebhookResult = status > 0 ? "Success: \(status)" : "No response"
                }
            } catch {
                await MainActor.run {
                    self.testWebhookResult = "Failed: \(error.localizedDescription)"
                }
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { self.testWebhookResult = nil }
        }
    }

    private func autoDetectRepository() {
        // Try to find .git directory in current directory or parent directories
        var currentPath = FileManager.default.currentDirectoryPath
        var foundPath: String?

        for _ in 0..<5 {
            if FileManager.default.fileExists(atPath: currentPath + "/.git") {
                foundPath = currentPath
                break
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }

        if let path = foundPath {
            self.githubRepositoryPath = path
        }
    }

    private func addMCPServer() {
        let trimmedName = self.newServerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let server = MCPServer(
            id: UUID().uuidString,
            name: trimmedName,
            isRunning: false,
            port: max(1, self.newServerPort))
        self.mcpServers.append(server)
        self.newServerName = ""
        self.newServerPort = 8001
        self.persistMCPServers()
    }

    private func removeMCPServer(_ server: MCPServer) {
        self.mcpServers.removeAll { $0.id == server.id }
        self.persistMCPServers()
    }

    private func loadMCPServers() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "runicMCPServers.v1") else { return }
        if let servers = try? JSONDecoder().decode([MCPServer].self, from: data) {
            self.mcpServers = servers
        }
    }

    private func persistMCPServers() {
        guard let data = try? JSONEncoder().encode(self.mcpServers) else { return }
        UserDefaults.standard.set(data, forKey: "runicMCPServers.v1")
    }
}

@MainActor
private struct AddMCPServerSheet: View {
    @Binding var name: String
    @Binding var port: Int
    let onAdd: () -> Void
    let onCancel: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            Text("Add MCP Server")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Name")
                    .font(.subheadline.weight(.medium))
                TextField("Local MCP Server", text: self.$name)
                    .textFieldStyle(.roundedBorder)
                    .focused(self.$isNameFocused)
            }

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Port")
                    .font(.subheadline.weight(.medium))
                TextField("", value: self.$port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { self.onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { self.onAdd() }
                    .buttonStyle(.borderedProminent)
                    .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RunicSpacing.lg)
        .frame(width: 420)
        .onAppear { self.isNameFocused = true }
    }
}

// MARK: - Vaayu API Key Keychain Helper

private enum VaayuKeychainHelper {
    private static let service = "com.sriinnu.athena.Runic"
    private static let account = "vaayu-api-key"

    static func load() -> String? {
        var result: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty
        else {
            return nil
        }
        return token
    }

    @discardableResult
    static func save(_ value: String) -> Bool {
        delete()
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
