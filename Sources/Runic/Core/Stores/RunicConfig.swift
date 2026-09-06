import Foundation

// MARK: - Schema

/// Hot-reload configuration read from `~/Library/Application Support/Runic/config.json`.
///
/// Every field is optional in the JSON and unknown keys (including `"$comment"`)
/// are ignored, so a hand-edited file degrades gracefully to built-in defaults.
struct RunicConfig: Codable, Equatable {
    /// Endpoint overrides keyed by provider id, e.g. `"qwen"` or `"qwenCN"`.
    var providers: [String: ProviderEndpointConfig]

    /// Extra log paths to scan in addition to the built-in locations.
    var logPaths: [String]

    init(
        providers: [String: ProviderEndpointConfig] = [:],
        logPaths: [String] = [])
    {
        self.providers = providers
        self.logPaths = logPaths
    }

    private enum CodingKeys: String, CodingKey {
        case providers
        case logPaths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.providers = try container.decodeIfPresent([String: ProviderEndpointConfig].self, forKey: .providers) ?? [:]
        self.logPaths = try container.decodeIfPresent([String].self, forKey: .logPaths) ?? []
    }

    // MARK: - Defaults

    /// A config with no overrides at all.
    static let empty = RunicConfig()

    /// The config that gets seeded on disk — example provider entries with empty
    /// endpoints. `RunicConfigStore.ensureSeeded()` writes a self-documenting
    /// version of this that also carries a `"$comment"` key.
    static let seededDefault = RunicConfig(
        providers: [
            "qwen": ProviderEndpointConfig(),
            "qwenCN": ProviderEndpointConfig(),
        ],
        logPaths: [])

    // MARK: - Overrides

    /// Number of overrides currently in effect: non-empty endpoints plus extra log paths.
    var activeOverrideCount: Int {
        let endpointOverrides = self.providers.values.count(where: { provider in
            guard let endpoint = provider.endpoint else { return false }
            return !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
        return endpointOverrides + self.logPaths.count
    }
}

/// Endpoint override for a single provider.
struct ProviderEndpointConfig: Codable, Equatable {
    /// Custom base endpoint. Empty or nil means "use the built-in default".
    var endpoint: String?
    /// Optional rolling-window quota. When present, Runic sums the provider's
    /// log-derived usage inside each window and renders a real usage gauge —
    /// useful for plans whose own API exposes no quota (e.g. DashScope plans).
    var quota: ProviderQuotaConfig?

    init(endpoint: String? = nil, quota: ProviderQuotaConfig? = nil) {
        self.endpoint = endpoint
        self.quota = quota
    }
}

/// Rolling-window quota limits for a provider (e.g. a subscription's request budget).
struct ProviderQuotaConfig: Codable, Equatable {
    var windows: [QuotaWindowConfig]

    init(windows: [QuotaWindowConfig] = []) {
        self.windows = windows
    }
}

/// A single rolling quota window. `minutes` is the window length; set `requests`
/// for a request-count budget (DashScope Token Plan) or `tokens` for a token budget.
struct QuotaWindowConfig: Codable, Equatable {
    var minutes: Int
    var requests: Int?
    var tokens: Int?

    init(minutes: Int, requests: Int? = nil, tokens: Int? = nil) {
        self.minutes = minutes
        self.requests = requests
        self.tokens = tokens
    }
}
