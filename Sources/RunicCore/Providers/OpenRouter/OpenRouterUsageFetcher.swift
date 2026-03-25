import Foundation

// MARK: - API response models

struct OpenRouterCreditsResponse: Decodable {
    let data: CreditData?
    let credits: Double?

    struct CreditData: Decodable {
        let credits: Double?
        let total_credits: Double?
        let total_usage: Double?
    }

    /// Resolved total credits purchased.
    var totalCredits: Double {
        self.data?.total_credits ?? self.data?.credits ?? self.credits ?? 0
    }

    /// Resolved total credits consumed.
    var totalUsage: Double {
        self.data?.total_usage ?? 0
    }

    /// Remaining balance.
    var remaining: Double {
        max(0, self.totalCredits - self.totalUsage)
    }

    /// Usage percentage (0–100).
    var usedPercent: Double {
        guard self.totalCredits > 0 else { return 0 }
        return min(100, max(0, (self.totalUsage / self.totalCredits) * 100))
    }
}

/// Response from /api/v1/auth/key — lightweight key info.
struct OpenRouterKeyInfoResponse: Decodable {
    let data: KeyData?

    struct KeyData: Decodable {
        let label: String?
        let usage: Double?
        let limit: Double?
        let is_free_tier: Bool?
        let rate_limit: RateLimit?

        struct RateLimit: Decodable {
            let requests: Int?
            let interval: String?
        }
    }

    var keyUsage: Double { self.data?.usage ?? 0 }
    var keyLimit: Double? { self.data?.limit }
    var isFreeTier: Bool { self.data?.is_free_tier ?? false }
    var rateLimitRequests: Int? { self.data?.rate_limit?.requests }
    var rateLimitInterval: String? { self.data?.rate_limit?.interval }
}

// MARK: - Fetcher

struct OpenRouterUsageFetcher {
    static let creditsURL = URL(string: "https://openrouter.ai/api/v1/credits")!
    static let keyInfoURL = URL(string: "https://openrouter.ai/api/v1/auth/key")!
    private static let requestTimeout: TimeInterval = 15
    private static let log = RunicLog.logger("openrouter-usage")

    /// Fetches credits + key info in parallel for maximum data.
    static func fetchAll(apiKey: String) async throws -> (OpenRouterCreditsResponse, OpenRouterKeyInfoResponse?) {
        async let creditsTask = Self.fetchCredits(apiKey: apiKey)
        async let keyInfoTask = Self.fetchKeyInfoBestEffort(apiKey: apiKey)

        let credits = try await creditsTask
        let keyInfo = await keyInfoTask
        return (credits, keyInfo)
    }

    static func fetchCredits(apiKey: String) async throws -> OpenRouterCreditsResponse {
        var request = URLRequest(url: creditsURL)
        request.timeoutInterval = Self.requestTimeout
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw OpenRouterAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        Self.log.debug("OpenRouter credits response: HTTP \(httpResponse.statusCode), \(data.count) bytes")

        return try JSONDecoder().decode(OpenRouterCreditsResponse.self, from: data)
    }

    private static func fetchKeyInfoBestEffort(apiKey: String) async -> OpenRouterKeyInfoResponse? {
        do {
            return try await Self.fetchKeyInfo(apiKey: apiKey)
        } catch {
            Self.log.info("OpenRouter key info unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    static func fetchKeyInfo(apiKey: String) async throws -> OpenRouterKeyInfoResponse {
        var request = URLRequest(url: keyInfoURL)
        request.timeoutInterval = Self.requestTimeout
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw OpenRouterAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        Self.log.debug("OpenRouter key info response: HTTP \(httpResponse.statusCode), \(data.count) bytes")

        return try JSONDecoder().decode(OpenRouterKeyInfoResponse.self, from: data)
    }

}

// MARK: - Snapshot conversion

extension OpenRouterCreditsResponse {
    func toUsageSnapshot(keyInfo: OpenRouterKeyInfoResponse? = nil) -> UsageSnapshot {
        let balance = self.remaining
        let used = self.totalUsage
        let total = self.totalCredits
        let percent = self.usedPercent

        let balanceStr = String(format: "$%.2f", balance)
        let usedStr = String(format: "$%.2f", used)

        var resetDesc = "Balance: \(balanceStr)"
        if used > 0 {
            resetDesc += " · Spent: \(usedStr)"
        }

        var identityMethod: String?
        if let keyInfo {
            var parts: [String] = []
            if keyInfo.isFreeTier { parts.append("Free tier") }
            if let label = keyInfo.data?.label, !label.isEmpty { parts.append(label) }
            if let rpm = keyInfo.rateLimitRequests, let interval = keyInfo.rateLimitInterval {
                parts.append("\(rpm) req/\(interval)")
            }
            if !parts.isEmpty { identityMethod = parts.joined(separator: " · ") }
        }

        let identity = identityMethod.map {
            ProviderIdentitySnapshot(
                providerID: .openrouter,
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: $0)
        }

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: total > 0 ? percent : 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: resetDesc),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: identity)
    }

    func toCreditsSnapshot() -> CreditsSnapshot {
        CreditsSnapshot(
            remaining: self.remaining,
            events: [],
            updatedAt: Date())
    }
}

// MARK: - Errors

enum OpenRouterAPIError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from OpenRouter API"
        case let .httpError(statusCode):
            "OpenRouter API returned status code \(statusCode)"
        case .decodingError:
            "Failed to decode OpenRouter API response"
        }
    }
}
