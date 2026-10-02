import Foundation
import MCP
import RunicCore
import Testing
@testable import RunicCLI

struct RunicMCPTests {
    @Test
    func `limits and health use sanitized saved state`() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let stateURL = root.appendingPathComponent("mcp-state.json")
        let registryURL = root.appendingPathComponent("mcp-plugins.json")
        let now = Date()
        let state = RunicMCPState(
            generatedAt: now,
            refreshFrequency: "fiveMinutes",
            refreshStatus: "Auto-refresh: 5 min",
            lastRefreshAt: now,
            providers: [
                .init(
                    id: .codex,
                    updatedAt: now,
                    primary: nil,
                    secondary: nil,
                    tertiary: nil,
                    creditsRemaining: 57785.18,
                    balance: nil,
                    extraUsage: nil,
                    source: "Codex local",
                    hasError: false),
                .init(
                    id: .claude,
                    updatedAt: now.addingTimeInterval(-3600),
                    primary: nil,
                    secondary: nil,
                    tertiary: nil,
                    creditsRemaining: nil,
                    balance: nil,
                    extraUsage: nil,
                    source: "Claude web",
                    hasError: true),
                .init(
                    id: .gemini,
                    updatedAt: now,
                    primary: nil,
                    secondary: nil,
                    tertiary: nil,
                    creditsRemaining: nil,
                    balance: nil,
                    extraUsage: nil,
                    source: "Gemini local",
                    hasError: false),
            ])
        try RunicMCPStateStore.save(state, to: stateURL)
        #expect(RunicMCPStateStore.load(from: stateURL)?.providers.count == 3)
        let permissions = try FileManager.default
            .attributesOfItem(atPath: stateURL.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)

        let service = RunicMCPService(stateURL: stateURL, registryURL: registryURL)
        #expect(service.tools().map(\.name).contains("runic_limits"))
        let limits = await service.call(name: "runic_limits", arguments: [:])
        #expect(limits.isError == false)
        let limitsJSON = try #require(Self.text(limits))
        #expect(limitsJSON.contains("57785.18"))
        #expect(limitsJSON.contains("claude"))
        #expect(limitsJSON.contains("gemini"))
        #expect(!limitsJSON.contains("accountEmail"))

        let filtered = await service.call(name: "runic_limits", arguments: ["provider": .string("claude")])
        let filteredJSON = try #require(Self.text(filtered))
        #expect(filteredJSON.contains("claude"))
        #expect(!filteredJSON.contains("codex"))

        let health = await service.call(name: "runic_health", arguments: [:])
        let healthJSON = try #require(Self.text(health))
        #expect(healthJSON.contains("\"stale\":true"))
        #expect(healthJSON.contains("\"hasError\":true"))
    }

    @Test
    func `local package can be added called disabled and removed`() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let registryURL = root.appendingPathComponent("registry.json")
        let packageURL = root.appendingPathComponent("sample")
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let manifest = """
        {"apiVersion":1,"id":"sample","name":"Sample","version":"1.0.0",
         "executable":"tool.sh","tools":[{"name":"hello","description":"Greeting",
         "inputSchema":{"type":"object","properties":{}}}]}
        """
        try manifest.write(
            to: packageURL.appendingPathComponent("runic-mcp-plugin.json"),
            atomically: true,
            encoding: .utf8)
        let script = packageURL.appendingPathComponent("tool.sh")
        try "#!/bin/sh\nread request\nprintf '{\"ok\":true,\"tool\":\"hello\"}'\n".write(
            to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)

        _ = try RunicMCPPluginRegistry.add(packageURL.path, at: registryURL)
        let service = RunicMCPService(stateURL: root.appendingPathComponent("none"), registryURL: registryURL)
        #expect(service.tools().map(\.name).contains("sample_hello"))
        let response = await service.call(name: "sample_hello", arguments: [:])
        #expect(response.isError == false)
        #expect(Self.text(response)?.contains("\"ok\":true") == true)

        try RunicMCPPluginRegistry.setEnabled(false, id: "sample", at: registryURL)
        #expect(!service.tools().map(\.name).contains("sample_hello"))
        try RunicMCPPluginRegistry.remove("sample", at: registryURL)
        #expect(FileManager.default.fileExists(atPath: script.path))

        _ = try RunicMCPPluginRegistry.add(packageURL.path, at: registryURL)
        try FileManager.default.removeItem(at: script)
        #expect(RunicMCPPluginRegistry.packages(at: registryURL).isEmpty)
        #expect(RunicMCPPluginRegistry.registrations(at: registryURL).count == 1)
        try RunicMCPPluginRegistry.remove(packageURL.path, at: registryURL)
        #expect(RunicMCPPluginRegistry.registrations(at: registryURL).isEmpty)
    }

    @Test
    func `mcpservers packages appear without registration and respect disabled state`() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let registryURL = root.appendingPathComponent("mcp-plugins.json")
        try RunicMCPPluginRegistry.ensureDiscoveryDirectory(at: registryURL)
        let discovery = RunicMCPPluginRegistry.discoveryDirectory(at: registryURL)
        let permissions = try FileManager.default
            .attributesOfItem(atPath: discovery.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o700)
        let packageURL = discovery.appendingPathComponent("sample")
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let manifest = """
        {"apiVersion":1,"id":"sample","name":"Sample","version":"1.0.0",
         "executable":"tool.sh","tools":[{"name":"hello","description":"Greeting",
         "inputSchema":{"type":"object","properties":{}}}]}
        """
        try manifest.write(
            to: packageURL.appendingPathComponent("runic-mcp-plugin.json"),
            atomically: true,
            encoding: .utf8)
        let script = packageURL.appendingPathComponent("tool.sh")
        try "#!/bin/sh\nread request\nprintf '{\"ok\":true}'\n".write(
            to: script,
            atomically: true,
            encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)

        let service = RunicMCPService(stateURL: root.appendingPathComponent("none"), registryURL: registryURL)
        #expect(RunicMCPPluginRegistry.registrations(at: registryURL).isEmpty)
        #expect(RunicMCPPluginRegistry.packages(at: registryURL).first?.discovered == true)
        #expect(service.tools().map(\.name).contains("sample_hello"))
        #expect(await (service.call(name: "sample_hello", arguments: [:])).isError == false)

        try RunicMCPPluginRegistry.setEnabled(false, id: "sample", at: registryURL)
        #expect(!service.tools().map(\.name).contains("sample_hello"))
        #expect(RunicMCPPluginRegistry.packages(at: registryURL).first?.enabled == false)
        try RunicMCPPluginRegistry.setEnabled(true, id: "sample", at: registryURL)
        #expect(service.tools().map(\.name).contains("sample_hello"))
        #expect(throws: RunicMCPPluginError.self) {
            try RunicMCPPluginRegistry.remove("sample", at: registryURL)
        }

        let duplicate = discovery.appendingPathComponent("sample-copy")
        try FileManager.default.copyItem(at: packageURL, to: duplicate)
        #expect(RunicMCPPluginRegistry.packages(at: registryURL).count(where: { $0.manifest.id == "sample" }) == 1)
        #expect(RunicMCPPluginRegistry.invalidDiscoveredPaths(at: registryURL)
            .contains { URL(fileURLWithPath: $0).lastPathComponent == "sample-copy" })
        try FileManager.default.removeItem(at: duplicate)

        try FileManager.default.removeItem(at: script)
        #expect(!service.tools().map(\.name).contains("sample_hello"))
        let invalid = RunicMCPPluginRegistry.invalidDiscoveredPaths(at: registryURL)
        #expect(invalid.count == 1)
        #expect(invalid.first.map { URL(fileURLWithPath: $0).lastPathComponent } == "sample")
    }

    private static func text(_ result: CallTool.Result) -> String? {
        guard let first = result.content.first, case let .text(text, _, _) = first else { return nil }
        return text
    }
}
