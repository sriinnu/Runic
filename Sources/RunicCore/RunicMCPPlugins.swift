import Foundation

public indirect enum RunicJSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([RunicJSONValue])
    case object([String: RunicJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([RunicJSONValue].self) {
            self = .array(value)
        } else {
            self = try .object(container.decode([String: RunicJSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }
}

public struct RunicMCPPluginManifest: Codable, Sendable {
    public struct Tool: Codable, Sendable {
        public let name: String
        public let description: String
        public let inputSchema: RunicJSONValue
    }

    public let apiVersion: Int
    public let id: String
    public let name: String
    public let version: String
    public let executable: String
    public let tools: [Tool]
}

public struct RunicMCPPluginRegistration: Codable, Sendable {
    public let path: String
    public var enabled: Bool

    public init(path: String, enabled: Bool = true) {
        self.path = path
        self.enabled = enabled
    }
}

public struct RunicMCPPluginPackage: Sendable {
    public let directory: URL
    public let executable: URL
    public let manifest: RunicMCPPluginManifest
    public let enabled: Bool
}

public enum RunicMCPPluginError: Error, LocalizedError {
    case invalidPackage(String)
    case alreadyInstalled(String)
    case notInstalled(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidPackage(detail): "Invalid Runic MCP plugin: \(detail)"
        case let .alreadyInstalled(id): "Plugin \(id) is already installed."
        case let .notInstalled(id): "Plugin \(id) is not installed."
        }
    }
}

/// Local-path packages, like Pi's local extensions: add/remove the registration,
/// never copy or delete the user's plugin folder.
public enum RunicMCPPluginRegistry {
    public static var defaultURL: URL {
        RunicMCPStateStore.defaultURL.deletingLastPathComponent()
            .appendingPathComponent("mcp-plugins.json")
    }

    public static func registrations(at url: URL = defaultURL) -> [RunicMCPPluginRegistration] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([RunicMCPPluginRegistration].self, from: data)) ?? []
    }

    public static func packages(at url: URL = defaultURL) -> [RunicMCPPluginPackage] {
        self.registrations(at: url).compactMap { registration in
            try? self.loadPackage(at: URL(fileURLWithPath: registration.path), enabled: registration.enabled)
        }
    }

    public static func add(_ path: String, at url: URL = defaultURL) throws -> RunicMCPPluginPackage {
        let package = try self.loadPackage(at: URL(fileURLWithPath: path), enabled: true)
        var registrations = self.registrations(at: url)
        guard !registrations.contains(where: { $0.path == package.directory.path }),
              !self.packages(at: url).contains(where: { $0.manifest.id == package.manifest.id })
        else {
            throw RunicMCPPluginError.alreadyInstalled(package.manifest.id)
        }
        registrations.append(.init(path: package.directory.path))
        try self.save(registrations, to: url)
        return package
    }

    public static func remove(_ id: String, at url: URL = defaultURL) throws {
        let packages = self.packages(at: url)
        if let package = packages.first(where: { $0.manifest.id == id }) {
            try self.removeRegistration(path: package.directory.path, at: url)
        } else {
            try self.removeRegistration(path: id, at: url)
        }
    }

    /// Remove a broken or moved package by its registered path, without touching its files.
    public static func removeRegistration(path: String, at url: URL = defaultURL) throws {
        let registrations = self.registrations(at: url)
        guard registrations.contains(where: { $0.path == path }) else {
            throw RunicMCPPluginError.notInstalled(path)
        }
        try self.save(registrations.filter { $0.path != path }, to: url)
    }

    public static func setEnabled(_ enabled: Bool, id: String, at url: URL = defaultURL) throws {
        guard let package = self.packages(at: url).first(where: { $0.manifest.id == id }) else {
            throw RunicMCPPluginError.notInstalled(id)
        }
        var registrations = self.registrations(at: url)
        guard let index = registrations.firstIndex(where: { $0.path == package.directory.path }) else { return }
        registrations[index].enabled = enabled
        try self.save(registrations, to: url)
    }

    public static func loadPackage(at url: URL, enabled: Bool = true) throws -> RunicMCPPluginPackage {
        let directory = url.standardizedFileURL.resolvingSymlinksInPath()
        let manifestURL = directory.appendingPathComponent("runic-mcp-plugin.json")
        let manifest: RunicMCPPluginManifest
        do {
            manifest = try JSONDecoder().decode(
                RunicMCPPluginManifest.self, from: Data(contentsOf: manifestURL))
        } catch {
            throw RunicMCPPluginError.invalidPackage("missing or malformed runic-mcp-plugin.json")
        }
        guard manifest.apiVersion == 1,
              manifest.id != "runic",
              self.validIdentifier(manifest.id, allowHyphen: true, allowUnderscore: false),
              !manifest.name.isEmpty,
              !manifest.version.isEmpty,
              !manifest.tools.isEmpty
        else { throw RunicMCPPluginError.invalidPackage("invalid manifest identity or version") }

        let names = manifest.tools.map(\.name)
        guard Set(names).count == names.count,
              manifest.tools.allSatisfy({ tool in
                  self.validIdentifier(tool.name, allowHyphen: false, allowUnderscore: true) &&
                      !tool.description.isEmpty &&
                      self.isObjectSchema(tool.inputSchema)
              })
        else { throw RunicMCPPluginError.invalidPackage("invalid tool name or input schema") }

        guard !manifest.executable.hasPrefix("/"), !manifest.executable.isEmpty else {
            throw RunicMCPPluginError.invalidPackage("executable must be inside the package")
        }
        let executable = directory.appendingPathComponent(manifest.executable).resolvingSymlinksInPath()
        guard executable.path.hasPrefix(directory.path + "/"),
              FileManager.default.isExecutableFile(atPath: executable.path)
        else { throw RunicMCPPluginError.invalidPackage("executable is missing or outside the package") }
        return RunicMCPPluginPackage(
            directory: directory, executable: executable, manifest: manifest, enabled: enabled)
    }

    private static func isObjectSchema(_ value: RunicJSONValue) -> Bool {
        guard case let .object(object) = value else { return false }
        return object["type"] == .string("object")
    }

    private static func validIdentifier(
        _ value: String,
        allowHyphen: Bool,
        allowUnderscore: Bool) -> Bool
    {
        guard let first = value.first, first.isASCII, first.isLetter, value.count <= 48 else { return false }
        return value.allSatisfy { character in
            character.isASCII && (character.isLowercase || character.isNumber ||
                (allowUnderscore && character == "_") || (allowHyphen && character == "-"))
        }
    }

    private static func save(_ registrations: [RunicMCPPluginRegistration], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(registrations).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
