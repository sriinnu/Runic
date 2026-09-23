import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ClaudeOAuthFetchError: LocalizedError, Sendable {
    case unauthorized
    case invalidResponse
    case serverError(Int, String?)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Claude OAuth request unauthorized. Run `claude` to re-authenticate."
        case .invalidResponse:
            return "Claude OAuth response was invalid."
        case let .serverError(code, body):
            if let body, !body.isEmpty {
                return "Claude OAuth error: HTTP \(code) – \(body)"
            }
            return "Claude OAuth error: HTTP \(code)"
        case let .networkError(error):
            return "Claude OAuth network error: \(error.localizedDescription)"
        }
    }
}

enum ClaudeOAuthUsageFetcher {
    private static let baseURL = "https://api.anthropic.com"
    private static let usagePath = "/api/oauth/usage"
    private static let betaHeader = "oauth-2025-04-20"
    private static let log = RunicLog.logger("claude-oauth-usage")

    static func fetchUsage(accessToken: String) async throws -> OAuthUsageResponse {
        do {
            return try await self.fetchUsage(accessToken: accessToken, requestResets: true)
        } catch let ClaudeOAuthFetchError.serverError(code, _) where Self.rejectsQuery(code) {
            Self.log.info("Usage endpoint rejected the resets flag (HTTP \(code)); retrying without it")
            Self.recordRejectedResetsQuery(status: code)
            // The resets flag is only confirmed on claude.ai; never let it
            // cost the usage card if this endpoint refuses unknown params.
            return try await self.fetchUsage(accessToken: accessToken, requestResets: false)
        }
    }

    static func rejectsQuery(_ statusCode: Int) -> Bool {
        statusCode == 400 || statusCode == 422
    }

    static func usageURL(requestResets: Bool) -> URL? {
        var components = URLComponents(string: baseURL + self.usagePath)
        if requestResets {
            components?.queryItems = ClaudeLimitResetStatus.queryItems
        }
        return components?.url
    }

    private static func fetchUsage(accessToken: String, requestResets: Bool) async throws -> OAuthUsageResponse {
        guard let url = usageURL(requestResets: requestResets) else {
            throw ClaudeOAuthFetchError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // OAuth usage endpoint currently requires the beta header.
        request.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("Runic", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ClaudeOAuthFetchError.invalidResponse
            }
            switch http.statusCode {
            case 200:
                let usage = try Self.decodeUsageResponse(data)
                if requestResets { Self.recordResetsShape(data, usage: usage, url: url) }
                return usage
            case 401, 403:
                throw ClaudeOAuthFetchError.unauthorized
            default:
                let body = String(data: data, encoding: .utf8)
                throw ClaudeOAuthFetchError.serverError(http.statusCode, body)
            }
        } catch let error as ClaudeOAuthFetchError {
            throw error
        } catch {
            throw ClaudeOAuthFetchError.networkError(error)
        }
    }

    /// Writes the reply's shape (field names, whether the resets block came
    /// back and how many grants it holds) to
    /// `~/Library/Application Support/Runic/diagnostics/claude-usage-shape.json`.
    /// No values, so no tokens or usage figures; the unified log redacts
    /// messages as <private>, which made the log line useless for this.
    static func recordResetsShape(_ data: Data, usage: OAuthUsageResponse, url: URL) {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let block = root["cedar_ember"]
        let blockState = if block == nil { "absent" } else if block is NSNull { "null" } else { "object" }
        let grants = usage.cedarEmber?.grants ?? []
        let shape: [String: Any] = [
            "at": ISO8601DateFormatter().string(from: Date()),
            "query": url.query ?? "",
            "topLevelKeys": root.keys.sorted(),
            "cedarEmber": blockState,
            "cedarEmberKeys": ((block as? [String: Any])?.keys.sorted()) ?? [],
            "spendKeys": ((root["spend"] as? [String: Any])?.keys.sorted()) ?? [],
            "spendFieldsPresent": ["used", "limit", "balance", "enabled"].filter {
                !((root["spend"] as? [String: Any])?[$0] is NSNull) && (root["spend"] as? [String: Any])?[$0] != nil
            },
            "grantCount": grants.count,
            "resetsLeft": grants.map { $0.resetsLeft ?? -1 },
            "paused": grants.map { $0.paused ?? false },
            "bankedResets": usage.cedarEmber?.resetCredits()?.availableCount ?? 0,
        ]
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Runic/diagnostics", isDirectory: true),
            let json = try? JSONSerialization.data(withJSONObject: shape, options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? json.write(to: directory.appendingPathComponent("claude-usage-shape.json"), options: .atomic)
    }

    static func recordRejectedResetsQuery(status: Int) {
        let shape: [String: Any] = [
            "at": ISO8601DateFormatter().string(from: Date()),
            "rejectedWithStatus": status,
        ]
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Runic/diagnostics", isDirectory: true),
            let json = try? JSONSerialization.data(withJSONObject: shape, options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? json.write(to: directory.appendingPathComponent("claude-usage-shape.json"), options: .atomic)
    }

    static func decodeUsageResponse(_ data: Data) throws -> OAuthUsageResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(OAuthUsageResponse.self, from: data)
    }

    static func parseISO8601Date(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

struct OAuthUsageResponse: Decodable {
    let fiveHour: OAuthUsageWindow?
    let sevenDay: OAuthUsageWindow?
    let sevenDayOAuthApps: OAuthUsageWindow?
    let sevenDayOpus: OAuthUsageWindow?
    let sevenDaySonnet: OAuthUsageWindow?
    let iguanaNecktie: OAuthUsageWindow?
    let extraUsage: OAuthExtraUsage?
    /// Usage credits (used / monthly limit / balance / on-off).
    let spend: OAuthSpend?
    /// Newer payloads carry every limit as a list, including model-scoped
    /// weekly windows (`kind: "weekly_scoped"`, `scope.model.display_name`).
    let limits: [OAuthLimitEntry]?
    /// Banked limit resets; present only when requested with `cedar_ember=1`.
    let cedarEmber: ClaudeLimitResetStatus?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOAuthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case iguanaNecktie = "iguana_necktie"
        case extraUsage = "extra_usage"
        case spend
        case limits
        case cedarEmber = "cedar_ember"
    }
}

struct OAuthLimitEntry: Decodable {
    let kind: String?
    let group: String?
    let percent: Double?
    let resetsAt: String?
    let scope: OAuthLimitScope?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case kind
        case group
        case percent
        case resetsAt = "resets_at"
        case scope
        case isActive = "is_active"
    }

    /// Model name for a scoped limit, when the payload names one.
    var scopedModelName: String? {
        let name = self.scope?.model?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }
}

struct OAuthLimitScope: Decodable {
    let model: OAuthLimitScopeModel?
}

struct OAuthLimitScopeModel: Decodable {
    let id: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct OAuthUsageWindow: Decodable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct OAuthExtraUsage: Decodable {
    let isEnabled: Bool?
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?
    let currency: String?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
        case currency
    }
}

#if DEBUG
extension ClaudeOAuthUsageFetcher {
    static func _decodeUsageResponseForTesting(_ data: Data) throws -> OAuthUsageResponse {
        try self.decodeUsageResponse(data)
    }
}
#endif
