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
    @State private var mcpPlugins: [RunicMCPPluginPackage] = []
    @State private var invalidMCPPluginPaths: [String] = []
    @State private var mcpPluginMessage: String?
    @State private var showingAddServerSheet = false
    @State private var newServerName = ""
    @State private var newServerPort = 8001
    @State private var testWebhookResult: WebhookTestResult?

    private var collectorPath: String {
        OTelGenAICollectorConfiguration.defaultOutputFile().path
    }

    private var runicMCPHelperPath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/RunicCLI").path
    }

    private var runicMCPHelperAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: self.runicMCPHelperPath)
    }

    private var koshaPath: String {
        NSString(string: "~/.kosha/registry.json").expandingTildeInPath
    }

    private var isRepositoryPathValid: Bool {
        Self.gitDirectory(for: self.githubRepositoryPath) != nil
    }

    static func gitDirectory(for repositoryPath: String) -> String? {
        let repository = repositoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repository.isEmpty else { return nil }
        let marker = URL(fileURLWithPath: repository, isDirectory: true).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: marker.path, isDirectory: &isDirectory) else { return nil }
        if isDirectory.boolValue { return marker.standardizedFileURL.path }
        guard let content = try? String(contentsOf: marker, encoding: .utf8),
              let line = content.split(whereSeparator: \.isNewline).first,
              line.hasPrefix("gitdir:")
        else { return nil }
        let path = String(line.dropFirst("gitdir:".count)).trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }
        let resolved = URL(fileURLWithPath: path, relativeTo: marker.deletingLastPathComponent()).standardizedFileURL
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory), isDirectory.boolValue
        else { return nil }
        return resolved.path
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
                title: "Runic MCP",
                caption: "Let AI clients read Runic's latest local limits and refresh health. " +
                    "Add trusted local tool packages without rebuilding Runic.",
                contentSpacing: PreferencesLayoutMetrics.sectionSpacing)
            {
                IntegrationRow(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: "Local MCP server",
                    status: self.runicMCPHelperAvailable ? "Ready" : "Unavailable",
                    detail: "Built-in tools: runic_limits and runic_health. " +
                        "Your AI client starts Runic on demand through stdio.",
                    actions: {
                        IntegrationCopyButton(
                            title: "Copy client config",
                            value: self.runicMCPClientConfig,
                            copiedValue: self.$copiedValue,
                            onCopy: self.copy)
                            .disabled(!self.runicMCPHelperAvailable)
                    })

                HStack(spacing: RunicSpacing.sm) {
                    Label("Local tool packages", systemImage: "shippingbox")
                        .font(self.fonts.callout.weight(.semibold))
                    Spacer()
                    Button {
                        self.addLocalMCPPlugin()
                    } label: {
                        Label("Add folder", systemImage: "plus")
                    }
                    .buttonStyle(.runicBordered)
                    .controlSize(.small)
                }
                if self.mcpPlugins.isEmpty, self.invalidMCPPluginPaths.isEmpty {
                    IntegrationEmptyState(
                        icon: "shippingbox",
                        title: "No local packages",
                        detail: "Add a folder containing runic-mcp-plugin.json and an executable.")
                } else {
                    ForEach(self.mcpPlugins, id: \.manifest.id) { package in
                        HStack(spacing: RunicSpacing.sm) {
                            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                                Text(package.manifest.name)
                                    .font(self.fonts.callout.weight(.semibold))
                                Text("\(package.manifest.id) · \(package.manifest.tools.count) tools")
                                    .font(self.fonts.footnote)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                            }
                            Spacer()
                            Toggle("Enabled", isOn: Binding(
                                get: { package.enabled },
                                set: { self.setMCPPlugin(package.manifest.id, enabled: $0) }))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            Button("Remove") { self.removeMCPPlugin(package.manifest.id) }
                                .buttonStyle(.runicBordered)
                                .controlSize(.small)
                        }
                    }
                    ForEach(self.invalidMCPPluginPaths, id: \.self) { path in
                        HStack(spacing: RunicSpacing.sm) {
                            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                                Text("Package unavailable")
                                    .font(self.fonts.callout.weight(.semibold))
                                Text(path)
                                    .font(self.fonts.footnote)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Button("Remove") { self.removeMCPPluginRegistration(path) }
                                .buttonStyle(.runicBordered)
                                .controlSize(.small)
                        }
                    }
                }
                if let message = self.mcpPluginMessage {
                    Text(message)
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
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
                    .buttonStyle(.runicBordered)
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
                    RunicSegmentedPicker(
                        selection: self.$webhookFormat,
                        options: [("slack", "Slack"), ("discord", "Discord"), ("generic", "Generic")])
                        .frame(maxWidth: 320)
                }
                HStack(spacing: RunicSpacing.sm) {
                    Button {
                        self.testWebhook()
                    } label: {
                        Label("Test", systemImage: "paperplane")
                    }
                    .buttonStyle(.runicBordered)
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
                            .buttonStyle(.runicBordered)
                            .controlSize(.small)
                            Button("Auto-detect") {
                                self.autoDetectRepository()
                            }
                            .buttonStyle(.runicBordered)
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
            self.loadMCPPlugins()
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
        Self.insightsCommand(for: self.githubRepositoryPath)
    }

    private var runicMCPClientConfig: String {
        let quoted = self.runicMCPHelperPath.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"mcpServers\":{\"runic\":{\"command\":\"\(quoted)\",\"args\":[\"mcp\",\"serve\"]}}}"
    }

    private func loadMCPPlugins() {
        self.mcpPlugins = RunicMCPPluginRegistry.packages()
        self.invalidMCPPluginPaths = RunicMCPPluginRegistry.registrations()
            .map(\.path)
            .filter { path in !self.mcpPlugins.contains(where: { $0.directory.path == path }) }
    }

    private func addLocalMCPPlugin() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add package"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let package = try RunicMCPPluginRegistry.add(url.path)
            self.mcpPluginMessage = "Added \(package.manifest.name). Restart your MCP client to refresh its tool list."
            self.loadMCPPlugins()
        } catch {
            self.mcpPluginMessage = error.localizedDescription
        }
    }

    private func setMCPPlugin(_ id: String, enabled: Bool) {
        do {
            try RunicMCPPluginRegistry.setEnabled(enabled, id: id)
            self.mcpPluginMessage = "Restart your MCP client to refresh its tool list."
            self.loadMCPPlugins()
        } catch {
            self.mcpPluginMessage = error.localizedDescription
        }
    }

    private func removeMCPPlugin(_ id: String) {
        do {
            try RunicMCPPluginRegistry.remove(id)
            self.mcpPluginMessage = "Removed \(id). Its folder was left untouched. " +
                "Restart your MCP client to refresh its tool list."
            self.loadMCPPlugins()
        } catch {
            self.mcpPluginMessage = error.localizedDescription
        }
    }

    private func removeMCPPluginRegistration(_ path: String) {
        do {
            try RunicMCPPluginRegistry.removeRegistration(path: path)
            self.mcpPluginMessage = "Removed unavailable package registration. Its folder was left untouched."
            self.loadMCPPlugins()
        } catch {
            self.mcpPluginMessage = error.localizedDescription
        }
    }

    static func insightsCommand(for repositoryPath: String) -> String {
        guard let gitDirectory = self.gitDirectory(for: repositoryPath) else {
            return "runic insights --with-commits --json --pretty"
        }
        let quoted = "'\(gitDirectory.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
        return "runic insights --with-commits --git-directory \(quoted) --json --pretty"
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
