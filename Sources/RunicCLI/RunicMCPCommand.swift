import Foundation
import MCP
import RunicCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum RunicMCPCommand {
    static func run(_ args: [String]) async {
        do {
            switch args.first ?? "help" {
            case "serve":
                guard args.count == 1 else { throw CommandError.usage }
                try await self.serve()
            case "add":
                guard args.count == 2 else { throw CommandError.usage }
                let package = try RunicMCPPluginRegistry.add(args[1])
                print("Added \(package.manifest.name) (\(package.manifest.id))")
            case "remove":
                guard args.count == 2 else { throw CommandError.usage }
                try RunicMCPPluginRegistry.remove(args[1])
                print("Removed \(args[1])")
            case "enable", "disable":
                guard args.count == 2 else { throw CommandError.usage }
                let enabled = args[0] == "enable"
                try RunicMCPPluginRegistry.setEnabled(enabled, id: args[1])
                print("\(enabled ? "Enabled" : "Disabled") \(args[1])")
            case "list":
                guard args.count == 1 else { throw CommandError.usage }
                print("runic_limits\tRunic built-in")
                print("runic_health\tRunic built-in")
                let packages = RunicMCPPluginRegistry.packages()
                for package in packages {
                    print(
                        "\(package.manifest.id)\t\(package.enabled ? "enabled" : "disabled")\t" +
                            "\(package.discovered ? "mcpservers" : "registered")\t\(package.directory.path)")
                }
                let invalidDiscovered = Set(RunicMCPPluginRegistry.invalidDiscoveredPaths())
                for path in invalidDiscovered.sorted() {
                    print("invalid\tmcpservers\t\(path)")
                }
                for registration in RunicMCPPluginRegistry.registrations()
                    where !packages.contains(where: { $0.directory.path == registration.path }) &&
                    !invalidDiscovered.contains(registration.path)
                {
                    print("invalid\t\(registration.path)\t(remove with: runic mcp remove <path>)")
                }
            case "help", "--help", "-h":
                print(self.help)
            default:
                throw CommandError.usage
            }
        } catch {
            RunicCLI.exit(code: 1, message: error.localizedDescription)
        }
    }

    private static let help = """
    Runic MCP (local stdio server)
      runic mcp serve                 Start the MCP server for an AI client
      runic mcp list                  List built-in and installed capabilities
      runic mcp add <folder>          Register a local plugin package
      runic mcp remove <id|path>      Unregister a plugin without deleting its files
      runic mcp enable|disable <id>   Toggle an installed plugin
    """

    private enum CommandError: LocalizedError {
        case usage

        var errorDescription: String? {
            "Invalid MCP command. Run 'runic mcp help'."
        }
    }

    private static func serve() async throws {
        let service = RunicMCPService()
        let server = Server(
            name: "runic",
            version: "1.0.0",
            capabilities: .init(tools: .init(listChanged: false)))
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: service.tools())
        }
        await server.withMethodHandler(CallTool.self) { parameters in
            await service.call(name: parameters.name, arguments: parameters.arguments ?? [:])
        }
        try await server.start(transport: StdioTransport())
        await server.waitUntilCompleted()
    }
}

struct RunicMCPService {
    let stateURL: URL
    let registryURL: URL

    init(
        stateURL: URL = RunicMCPStateStore.defaultURL,
        registryURL: URL = RunicMCPPluginRegistry.defaultURL)
    {
        self.stateURL = stateURL
        self.registryURL = registryURL
    }

    func tools() -> [Tool] {
        let emptySchema: Value = .object(["type": .string("object"), "properties": .object([:])])
        var tools = [
            Tool(
                name: "runic_limits",
                description: "Read provider quota windows, reset times, credits, and balances " +
                    "from Runic's latest local snapshot.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "provider": .object([
                            "type": .string("string"),
                            "description": .string("Optional Runic provider ID; omit for all enabled providers."),
                        ]),
                    ]),
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)),
            Tool(
                name: "runic_health",
                description: "Read Runic's refresh status, snapshot age, data source, and safe provider error flags.",
                inputSchema: emptySchema,
                annotations: .init(readOnlyHint: true, openWorldHint: false)),
        ]
        for package in RunicMCPPluginRegistry.packages(at: self.registryURL) where package.enabled {
            for pluginTool in package.manifest.tools {
                guard let schema = try? Value(pluginTool.inputSchema) else { continue }
                tools.append(Tool(
                    name: "\(package.manifest.id)_\(pluginTool.name)",
                    description: pluginTool.description,
                    inputSchema: schema))
            }
        }
        return tools
    }

    func call(name: String, arguments: [String: Value]) async -> CallTool.Result {
        switch name {
        case "runic_limits":
            guard let state = RunicMCPStateStore.load(from: self.stateURL) else {
                return self.error("No Runic snapshot yet. Open Runic and refresh usage first.")
            }
            let provider = arguments["provider"]?.stringValue
            guard arguments["provider"] == nil || provider != nil else {
                return self.error("provider must be a string")
            }
            let providers = state.providers.filter { provider == nil || $0.id.rawValue == provider }
            guard !providers.isEmpty else { return self.error("Provider is not enabled or has no data.") }
            return self.result(LimitsResult(generatedAt: state.generatedAt, providers: providers))
        case "runic_health":
            guard let state = RunicMCPStateStore.load(from: self.stateURL) else {
                return self.error("No Runic snapshot yet. Open Runic and refresh usage first.")
            }
            return self.result(HealthResult(state: state, now: Date()))
        default:
            for package in RunicMCPPluginRegistry.packages(at: self.registryURL) where package.enabled {
                for tool in package.manifest.tools where name == "\(package.manifest.id)_\(tool.name)" {
                    do {
                        return try self.result(self.invoke(package: package, tool: tool.name, arguments: arguments))
                    } catch {
                        return self.error("Plugin \(package.manifest.id) failed: \(error.localizedDescription)")
                    }
                }
            }
            return self.error("Unknown Runic MCP tool: \(name)")
        }
    }

    private func result(_ value: some Encodable) -> CallTool.Result {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(value)
            let structured = try JSONDecoder().decode(Value.self, from: data)
            guard let jsonText = String(bytes: data, encoding: .utf8) else {
                return self.error("Could not encode Runic MCP result.")
            }
            return .init(
                content: [.text(text: jsonText, annotations: nil, _meta: nil)],
                structuredContent: Value?.some(structured),
                isError: false)
        } catch {
            return self.error("Could not encode Runic MCP result.")
        }
    }

    private func error(_ message: String) -> CallTool.Result {
        .init(content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
    }

    private func invoke(
        package: RunicMCPPluginPackage,
        tool: String,
        arguments: [String: Value]) throws -> Value
    {
        let input = try JSONEncoder().encode(PluginRequest(tool: tool, arguments: arguments))
        guard input.count <= 65536 else { throw PluginInvocationError.inputTooLarge }
        let process = Process()
        process.executableURL = package.executable
        process.currentDirectoryURL = package.directory
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()
        defer {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
        }
        stdin.fileHandleForWriting.write(input)
        stdin.fileHandleForWriting.closeFile()

        var output = Data()
        let deadline = Date().addingTimeInterval(10)
        while true {
            let remaining = max(0, Int32(deadline.timeIntervalSinceNow * 1000))
            guard remaining > 0 else { throw PluginInvocationError.timedOut }
            var descriptor = pollfd(
                fd: stdout.fileHandleForReading.fileDescriptor,
                events: Int16(POLLIN | POLLHUP | POLLERR),
                revents: 0)
            let ready = poll(&descriptor, 1, remaining)
            if ready == 0 { throw PluginInvocationError.timedOut }
            if ready < 0 {
                if errno == EINTR { continue }
                throw PluginInvocationError.failed
            }
            guard let chunk = try stdout.fileHandleForReading.read(upToCount: 8192), !chunk.isEmpty else {
                break
            }
            output.append(chunk)
            guard output.count <= 65536 else {
                throw PluginInvocationError.outputTooLarge
            }
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw PluginInvocationError.failed }
        return try JSONDecoder().decode(Value.self, from: output)
    }

    private struct PluginRequest: Encodable {
        let tool: String
        let arguments: [String: Value]
    }

    private enum PluginInvocationError: LocalizedError {
        case failed
        case inputTooLarge
        case outputTooLarge
        case timedOut

        var errorDescription: String? {
            switch self {
            case .failed: "Executable exited with an error."
            case .inputTooLarge: "Tool arguments exceed 64 KiB."
            case .outputTooLarge: "Executable returned more than 64 KiB."
            case .timedOut: "Executable did not finish within 10 seconds."
            }
        }
    }

    private struct LimitsResult: Encodable {
        let generatedAt: Date
        let providers: [RunicMCPState.Provider]
    }

    private struct HealthResult: Encodable {
        struct Provider: Encodable {
            let id: UsageProvider
            let updatedAt: Date?
            let ageSeconds: Int?
            let stale: Bool
            let creditsUpdatedAt: Date?
            let creditsAgeSeconds: Int?
            let creditsStale: Bool?
            let creditsHasError: Bool?
            let source: String?
            let hasError: Bool
        }

        let generatedAt: Date
        let snapshotAgeSeconds: Int
        let refreshFrequency: String
        let refreshStatus: String
        let lastRefreshAt: Date?
        let providers: [Provider]

        init(state: RunicMCPState, now: Date) {
            self.generatedAt = state.generatedAt
            self.snapshotAgeSeconds = max(0, Int(now.timeIntervalSince(state.generatedAt)))
            self.refreshFrequency = state.refreshFrequency
            self.refreshStatus = state.refreshStatus
            self.lastRefreshAt = state.lastRefreshAt
            let interval = switch state.refreshFrequency {
            case "oneMinute": 60
            case "twoMinutes": 120
            case "fiveMinutes": 300
            case "fifteenMinutes": 900
            default: 600
            }
            let staleAfter = max(900, interval * 3)
            self.providers = state.providers.map { entry in
                let age = entry.updatedAt.map { max(0, Int(now.timeIntervalSince($0))) }
                let creditsAge = entry.creditsUpdatedAt.map { max(0, Int(now.timeIntervalSince($0))) }
                return Provider(
                    id: entry.id,
                    updatedAt: entry.updatedAt,
                    ageSeconds: age,
                    stale: age.map { $0 > staleAfter } ?? true,
                    creditsUpdatedAt: entry.creditsUpdatedAt,
                    creditsAgeSeconds: creditsAge,
                    creditsStale: creditsAge.map { $0 > staleAfter },
                    creditsHasError: entry.creditsHasError,
                    source: entry.source,
                    hasError: entry.hasError)
            }
        }
    }
}
