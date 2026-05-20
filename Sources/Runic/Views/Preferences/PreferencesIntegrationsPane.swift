import AppKit
import RunicCore
import SwiftUI

@MainActor
struct IntegrationsPane: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    @AppStorage("defaultWebhookURL") private var defaultWebhookURL = ""
    @AppStorage("webhookFormat") private var webhookFormat = "slack"
    @AppStorage("githubIntegrationEnabled") private var githubIntegrationEnabled = false
    @AppStorage("githubRepositoryPath") private var githubRepositoryPath = ""

    @State private var copiedValue: String?
    @State private var mcpServers: [MCPServer] = []
    @State private var showingAddServerSheet = false
    @State private var newServerName = ""
    @State private var newServerPort = 8001
    @State private var testWebhookResult: WebhookTestResult?

    private var collectorPath: String {
        OTelGenAICollectorConfiguration.defaultOutputFile().path
    }

    private var koshaPath: String {
        NSString(string: "~/.kosha/registry.json").expandingTildeInPath
    }

    private var repositoryGitPath: String {
        (self.githubRepositoryPath as NSString).appendingPathComponent(".git")
    }

    private var isRepositoryPathValid: Bool {
        !self.githubRepositoryPath.isEmpty && FileManager.default.fileExists(atPath: self.repositoryGitPath)
    }

    var body: some View {
        PreferencesPane {
            SettingsSection(
                title: "Scriptable Access",
                caption: "Runic exposes local usage through the bundled CLI and local JSONL files. " +
                    "Nothing here starts a network service.",
                contentSpacing: PreferencesLayoutMetrics.sectionSpacing)
            {
                IntegrationRow(
                    icon: "terminal",
                    title: "CLI JSON API",
                    status: "Ready",
                    detail: "Use the command-line helper for scripts, CI, dashboards, and local automations.",
                    actions: {
                        IntegrationCopyButton(
                            title: "Copy JSON command",
                            value: "runic usage --format json --pretty",
                            copiedValue: self.$copiedValue,
                            onCopy: self.copy)
                        IntegrationLinkButton(title: "CLI docs", systemImage: "book", url: self.docsURL("cli.md"))
                    })
                IntegrationRow(
                    icon: "waveform.path.ecg.rectangle",
                    title: "OpenTelemetry GenAI ledger",
                    status: FileManager.default.fileExists(atPath: self.collectorPath) ? "Found" : "Ready",
                    detail: "The collector writes sanitized metric JSONL here. " +
                        "Prompts and responses are not persisted.",
                    path: self.collectorPath,
                    actions: {
                        IntegrationCopyButton(
                            title: "Copy path",
                            value: self.collectorPath,
                            copiedValue: self.$copiedValue,
                            onCopy: self.copy)
                        IntegrationRevealButton(path: self.collectorPath)
                    })
                AdditionalUsageLogPathsEditor(paths: self.$settings.otelGenAILogPaths)
            }
            PreferencesDivider()
            SettingsSection(
                title: "MCP Profiles",
                caption: "Save connection details for MCP bridges you run outside Runic, " +
                    "then copy launch commands for desktop clients.",
                contentSpacing: PreferencesLayoutMetrics.sectionSpacing)
            {
                HStack(spacing: RunicSpacing.sm) {
                    Label("Configured servers", systemImage: "server.rack")
                        .font(self.fonts.callout.weight(.semibold))
                    Spacer()
                    Button {
                        self.showingAddServerSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if self.mcpServers.isEmpty {
                    IntegrationEmptyState(
                        icon: "terminal",
                        title: "No MCP profiles",
                        detail: "Add a local profile for a bridge process you manage separately.")
                } else {
                    VStack(spacing: RunicSpacing.sm) {
                        ForEach(self.mcpServers) { server in
                            IntegrationMCPServerRow(
                                server: server,
                                copiedValue: self.$copiedValue,
                                onCopy: self.copy,
                                onRemove: self.removeMCPServer)
                        }
                    }
                }
            }
            PreferencesDivider()
            SettingsSection(
                title: "Alert Webhooks",
                caption: "Keep a default target handy, test it, and use it when creating alert rules in Analytics.",
                contentSpacing: PreferencesLayoutMetrics.sectionSpacing)
            {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Default webhook URL")
                        .font(self.fonts.callout.weight(.semibold))
                    TextField("https://hooks.slack.com/services/...", text: self.$defaultWebhookURL)
                        .textFieldStyle(.roundedBorder)
                    Text("Saved locally. Alert rules still choose whether to notify by webhook.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Payload format")
                        .font(self.fonts.callout.weight(.semibold))
                    Picker("", selection: self.$webhookFormat) {
                        Text("Slack").tag("slack")
                        Text("Discord").tag("discord")
                        Text("Generic").tag("generic")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
                HStack(spacing: RunicSpacing.sm) {
                    Button {
                        self.testWebhook()
                    } label: {
                        Label("Test", systemImage: "paperplane")
                    }
                    .buttonStyle(.bordered)
                    .disabled(self.defaultWebhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let result = self.testWebhookResult {
                        Label(
                            result.message,
                            systemImage: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(self.fonts.footnote)
                            .foregroundStyle(result.isSuccess ? .green : .red)
                    }
                }
            }
            PreferencesDivider()

            SettingsSection(
                title: "GitHub & Projects",
                caption: "Correlate local usage with nearby commits for project-level insights. " +
                    "Runic reads git metadata locally.",
                contentSpacing: PreferencesLayoutMetrics.sectionSpacing)
            {
                PreferenceToggleRow(
                    title: "Link commits to usage",
                    subtitle: "Enables the preferred repository path below for copyable CLI insights commands.",
                    binding: self.$githubIntegrationEnabled)

                if self.githubIntegrationEnabled {
                    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                        Text("Repository path")
                            .font(self.fonts.callout.weight(.semibold))
                        HStack(spacing: RunicSpacing.xs) {
                            TextField("/path/to/repo", text: self.$githubRepositoryPath)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                self.chooseRepository()
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button("Auto-detect") {
                                self.autoDetectRepository()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        GitRepositoryStatus(
                            repositoryPath: self.githubRepositoryPath,
                            isValid: self.isRepositoryPathValid)
                    }

                    HStack(spacing: RunicSpacing.sm) {
                        IntegrationCopyButton(
                            title: "Copy insights command",
                            value: self.githubInsightsCommand,
                            copiedValue: self.$copiedValue,
                            onCopy: self.copy)
                            .disabled(!self.isRepositoryPathValid)
                        IntegrationLinkButton(
                            title: "GitHub",
                            systemImage: "arrow.up.right.square",
                            url: URL(string: "https://github.com/sriinnu/Runic"))
                    }
                }
            }

            PreferencesDivider()

            SettingsSection(
                title: "Detected Local Integrations",
                caption: "These are read-only inputs Runic already understands.",
                contentSpacing: PreferencesLayoutMetrics.sectionSpacing)
            {
                IntegrationRow(
                    icon: "sparkles",
                    title: "Kosha model registry",
                    status: FileManager.default.fileExists(atPath: self.koshaPath) ? "Found" : "Optional",
                    detail: "Runic reads Kosha locally for model context metadata when the registry exists.",
                    path: self.koshaPath,
                    actions: {
                        IntegrationCopyButton(
                            title: "Copy path",
                            value: self.koshaPath,
                            copiedValue: self.$copiedValue,
                            onCopy: self.copy)
                        IntegrationRevealButton(path: self.koshaPath)
                    })
                IntegrationRow(
                    icon: "key",
                    title: "Provider API keys",
                    status: "Keychain",
                    detail: "API-backed providers are configured in Providers and stored in macOS Keychain.",
                    actions: {
                        IntegrationLinkButton(
                            title: "Provider docs",
                            systemImage: "book",
                            url: self.docsURL("providers.md"))
                    })
            }
        }
        .onAppear {
            self.loadMCPServers()
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

    private var githubInsightsCommand: String {
        let path = self.githubRepositoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty {
            return "runic insights --with-commits --format json --pretty"
        }
        return "runic insights --with-commits --git-directory \"\(path)/.git\" --json --pretty"
    }

    private func docsURL(_ filename: String) -> URL? {
        let path = FileManager.default.currentDirectoryPath
        let repoDoc = URL(fileURLWithPath: path).appendingPathComponent("docs").appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: repoDoc.path) {
            return repoDoc
        }
        return URL(string: "https://github.com/sriinnu/Runic/tree/main/docs/\(filename)")
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        self.copiedValue = text
    }

    private func testWebhook() {
        let trimmedURL = self.defaultWebhookURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }

        Task {
            await MainActor.run {
                self.testWebhookResult = WebhookTestResult(message: "Testing...", isSuccess: true)
            }
            guard let url = URL(string: trimmedURL), url.scheme?.hasPrefix("http") == true else {
                await MainActor.run {
                    self.testWebhookResult = WebhookTestResult(message: "Invalid URL", isSuccess: false)
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 5
            request.httpBody = IntegrationWebhookPayload.data(format: self.webhookFormat)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    self.testWebhookResult = WebhookTestResult(
                        message: "Success: \(status)",
                        isSuccess: (200..<300).contains(status))
                }
            } catch {
                await MainActor.run {
                    self.testWebhookResult = WebhookTestResult(
                        message: "Failed: \(error.localizedDescription)",
                        isSuccess: false)
                }
            }
        }
    }

    private func autoDetectRepository() {
        let candidates = [
            FileManager.default.currentDirectoryPath,
            NSString(string: "~/Sriinnu/AI/Runic").expandingTildeInPath,
            NSString(string: "~/Sriinnu").expandingTildeInPath,
        ]

        for candidate in candidates {
            if let repository = self.findRepository(startingAt: candidate) {
                self.githubRepositoryPath = repository
                return
            }
        }
    }

    private func chooseRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a Git repository"

        if panel.runModal() == .OK, let url = panel.url {
            self.githubRepositoryPath = url.path
        }
    }

    private func findRepository(startingAt path: String) -> String? {
        var currentPath = path
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: (currentPath as NSString).appendingPathComponent(".git")) {
                return currentPath
            }
            let parent = (currentPath as NSString).deletingLastPathComponent
            guard parent != currentPath else { break }
            currentPath = parent
        }
        return nil
    }

    private func addMCPServer() {
        let trimmedName = self.newServerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let server = MCPServer(
            id: UUID().uuidString,
            name: trimmedName,
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
        guard let data = UserDefaults.standard.data(forKey: "runicMCPServers.v1"),
              let servers = try? JSONDecoder().decode([MCPServer].self, from: data)
        else {
            return
        }
        self.mcpServers = servers
    }

    private func persistMCPServers() {
        guard let data = try? JSONEncoder().encode(self.mcpServers) else { return }
        UserDefaults.standard.set(data, forKey: "runicMCPServers.v1")
    }
}
