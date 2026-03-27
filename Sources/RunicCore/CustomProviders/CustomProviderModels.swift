import Foundation

// MARK: - Main Provider Configuration

/// Main provider configuration for custom API providers
public struct CustomProviderConfig: Codable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var icon: String // SF Symbol name
    public var enabled: Bool
    public var auth: AuthConfig
    public var endpoints: EndpointConfig
    public var colorHex: String? // Optional custom color
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        enabled: Bool = true,
        auth: AuthConfig,
        endpoints: EndpointConfig,
        colorHex: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date())
    {
        self.id = id
        self.name = name
        self.icon = icon
        self.enabled = enabled
        self.auth = auth
        self.endpoints = endpoints
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Authentication Configuration

/// Authentication configuration for API requests
public struct AuthConfig: Codable, Sendable {
    public enum AuthType: String, Codable, Sendable {
        case apiKey = "api_key"
        case bearer
        case basic
        case oauth
        case custom
    }

    public let type: AuthType
    public var headerName: String // e.g., "Authorization", "X-API-Key"
    public var headerPrefix: String? // e.g., "Bearer ", "ApiKey "
    public var tokenKeychain: String // Keychain account name
    public var additionalHeaders: [String: String]? // Optional extra headers

    public init(
        type: AuthType,
        headerName: String,
        headerPrefix: String? = nil,
        tokenKeychain: String,
        additionalHeaders: [String: String]? = nil)
    {
        self.type = type
        self.headerName = headerName
        self.headerPrefix = headerPrefix
        self.tokenKeychain = tokenKeychain
        self.additionalHeaders = additionalHeaders
    }
}

// MARK: - Endpoint Configuration

/// Endpoint configuration for usage and balance APIs
public struct EndpointConfig: Codable, Sendable {
    public var usage: UsageEndpoint?
    public var balance: BalanceEndpoint?

    public init(
        usage: UsageEndpoint? = nil,
        balance: BalanceEndpoint? = nil)
    {
        self.usage = usage
        self.balance = balance
    }
}

// MARK: - Usage Endpoint

/// Usage endpoint configuration
public struct UsageEndpoint: Codable, Sendable {
    public var url: String // Supports {{date}}, {{start}}, {{end}} variables
    public var method: HTTPMethod
    public var mapping: ResponseMapping
    public var queryParams: [String: String]? // Optional query parameters

    public init(
        url: String,
        method: HTTPMethod = .GET,
        mapping: ResponseMapping,
        queryParams: [String: String]? = nil)
    {
        self.url = url
        self.method = method
        self.mapping = mapping
        self.queryParams = queryParams
    }
}

// MARK: - Balance Endpoint

/// Balance endpoint configuration
public struct BalanceEndpoint: Codable, Sendable {
    public var url: String
    public var method: HTTPMethod
    public var mapping: ResponseMapping

    public init(
        url: String,
        method: HTTPMethod = .GET,
        mapping: ResponseMapping)
    {
        self.url = url
        self.method = method
        self.mapping = mapping
    }
}

// MARK: - HTTP Method

/// HTTP method for API requests
public enum HTTPMethod: String, Codable, Sendable {
    case GET, POST, PUT, DELETE, PATCH
}

// MARK: - Response Mapping

/// Response field mapping from JSON to Runic data model
public struct ResponseMapping: Codable, Sendable {
    // Map JSON response fields to Runic data model
    public var quota: String? // JSONPath to quota field
    public var used: String? // JSONPath to used amount
    public var remaining: String? // JSONPath to remaining
    public var cost: String? // JSONPath to cost
    public var resetDate: String? // JSONPath to reset date
    public var tokens: String? // JSONPath to token count

    /// Nested object support (e.g., "data.usage.tokens")
    public var nestedPaths: Bool // Support dot notation

    public init(
        quota: String? = nil,
        used: String? = nil,
        remaining: String? = nil,
        cost: String? = nil,
        resetDate: String? = nil,
        tokens: String? = nil,
        nestedPaths: Bool = true)
    {
        self.quota = quota
        self.used = used
        self.remaining = remaining
        self.cost = cost
        self.resetDate = resetDate
        self.tokens = tokens
        self.nestedPaths = nestedPaths
    }
}

// MARK: - Usage Data

/// Generic usage data returned from custom provider APIs
public struct CustomUsageData: Codable, Sendable {
    public var quota: Double?
    public var used: Double?
    public var remaining: Double?
    public var cost: Double?
    public var resetDate: Date?
    public var tokens: Int?

    public init(
        quota: Double? = nil,
        used: Double? = nil,
        remaining: Double? = nil,
        cost: Double? = nil,
        resetDate: Date? = nil,
        tokens: Int? = nil)
    {
        self.quota = quota
        self.used = used
        self.remaining = remaining
        self.cost = cost
        self.resetDate = resetDate
        self.tokens = tokens
    }
}

// MARK: - Custom Provider Snapshot

/// Snapshot of custom provider usage compatible with existing UI
public struct CustomProviderSnapshot: Codable, Sendable {
    public let providerID: String
    public let providerName: String
    public let usageData: CustomUsageData
    public let updatedAt: Date
    public let error: String?

    public init(
        providerID: String,
        providerName: String,
        usageData: CustomUsageData,
        updatedAt: Date = Date(),
        error: String? = nil)
    {
        self.providerID = providerID
        self.providerName = providerName
        self.usageData = usageData
        self.updatedAt = updatedAt
        self.error = error
    }

    /// Convert to RateWindow for UI compatibility
    public func toRateWindow() -> RateWindow? {
        guard let quota = usageData.quota,
              let used = usageData.used
        else {
            return nil
        }

        let usedPercent = quota > 0 ? (used / quota) * 100.0 : 0.0
        let windowMinutes: Int? = nil // Custom providers might not have window concept
        let resetsAt = self.usageData.resetDate
        let resetDescription = resetsAt.map { UsageFormatter.resetDescription(from: $0) }

        return RateWindow(
            usedPercent: usedPercent,
            windowMinutes: windowMinutes,
            resetsAt: resetsAt,
            resetDescription: resetDescription)
    }

    /// Create snapshot from usage data and config
    public static func from(
        usageData: CustomUsageData,
        config: CustomProviderConfig) -> CustomProviderSnapshot
    {
        CustomProviderSnapshot(
            providerID: config.id,
            providerName: config.name,
            usageData: usageData,
            updatedAt: Date(),
            error: nil)
    }
}

// MARK: - Container

/// Container for all custom providers
public struct CustomProvidersData: Codable {
    public let version: Int
    public var providers: [CustomProviderConfig]

    public init(version: Int = 1, providers: [CustomProviderConfig] = []) {
        self.version = version
        self.providers = providers
    }
}
