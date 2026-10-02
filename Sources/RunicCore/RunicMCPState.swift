import Foundation

/// Sanitized, account-free data shared with the local Runic MCP process.
public struct RunicMCPState: Codable, Sendable {
    public struct Provider: Codable, Sendable {
        public let id: UsageProvider
        public let updatedAt: Date?
        public let primary: RateWindow?
        public let secondary: RateWindow?
        public let tertiary: RateWindow?
        public let creditsRemaining: Double?
        public let creditsUpdatedAt: Date?
        public let creditsHasError: Bool?
        public let balance: ProviderBalance?
        public let extraUsage: ProviderCostSnapshot?
        public let source: String?
        public let hasError: Bool

        public init(
            id: UsageProvider,
            updatedAt: Date?,
            primary: RateWindow?,
            secondary: RateWindow?,
            tertiary: RateWindow?,
            creditsRemaining: Double?,
            creditsUpdatedAt: Date? = nil,
            creditsHasError: Bool = false,
            balance: ProviderBalance?,
            extraUsage: ProviderCostSnapshot?,
            source: String?,
            hasError: Bool)
        {
            self.id = id
            self.updatedAt = updatedAt
            self.primary = primary
            self.secondary = secondary
            self.tertiary = tertiary
            self.creditsRemaining = creditsRemaining
            self.creditsUpdatedAt = creditsUpdatedAt
            self.creditsHasError = creditsHasError
            self.balance = balance
            self.extraUsage = extraUsage
            self.source = source
            self.hasError = hasError
        }
    }

    public let schemaVersion: Int
    public let generatedAt: Date
    public let refreshFrequency: String
    public let refreshStatus: String
    public let lastRefreshAt: Date?
    public let providers: [Provider]

    public init(
        generatedAt: Date,
        refreshFrequency: String,
        refreshStatus: String,
        lastRefreshAt: Date?,
        providers: [Provider])
    {
        self.schemaVersion = 1
        self.generatedAt = generatedAt
        self.refreshFrequency = refreshFrequency
        self.refreshStatus = refreshStatus
        self.lastRefreshAt = lastRefreshAt
        self.providers = providers
    }
}

public enum RunicMCPStateStore {
    public static var defaultURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("mcp-state.json")
    }

    public static func load(from url: URL = defaultURL) -> RunicMCPState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(RunicMCPState.self, from: data), state.schemaVersion == 1 else {
            return nil
        }
        return state
    }

    public static func save(_ state: RunicMCPState, to url: URL = defaultURL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
