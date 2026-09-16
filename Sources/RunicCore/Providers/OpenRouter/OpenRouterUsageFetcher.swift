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
        // Documented on GET /api/v1/key: USD spend for the current UTC day,
        // week and month, the key's spending limit, and the free-model quota.
        let usage_daily: Double?
        let usage_weekly: Double?
        let usage_monthly: Double?
        let limit_remaining: Double?
        let limit_reset: String?
        let free_model_daily_requests: FreeModelRequests?

        struct FreeModelRequests: Decodable {
            let used: Double?
            let limit: Double?
            let remaining: Double?
        }

        struct RateLimit: Decodable {
            let requests: Int?
            let interval: String?
        }
    }

    var keyUsage: Double {
        self.data?.usage ?? 0
    }

    var keyLimit: Double? {
        self.data?.limit
    }

    var isFreeTier: Bool {
        self.data?.is_free_tier ?? false
    }

    var rateLimitRequests: Int? {
        self.data?.rate_limit?.requests
    }

    var rateLimitInterval: String? {
        self.data?.rate_limit?.interval
    }
}

// MARK: - Fetcher

enum OpenRouterUsageFetcher {
    static let creditsURL = URL(string: "https://openrouter.ai/api/v1/credits")!
    /// Current documented path first; the legacy alias as a fallback.
    static let keyInfoURLs = [
        URL(string: "https://openrouter.ai/api/v1/key")!,
        URL(string: "https://openrouter.ai/api/v1/auth/key")!,
    ]
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
        for url in self.keyInfoURLs {
            do {
                return try await self.fetchKeyInfo(apiKey: apiKey, url: url)
            } catch {
                self.log.info("OpenRouter key info unavailable at \(url.path): \(error.localizedDescription)")
            }
        }
        return nil
    }

    static func fetchKeyInfo(apiKey: String, url: URL) async throws -> OpenRouterKeyInfoResponse {
        var request = URLRequest(url: url)
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
    func toUsageSnapshot(keyInfo: OpenRouterKeyInfoResponse? = nil, now: Date = Date()) -> UsageSnapshot {
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

        let key = keyInfo?.data
        let reported: ProviderBalance.ReportedSpend? = if let daily = key?.usage_daily,
                                                          let monthly = key?.usage_monthly
        {
            .init(today: daily, thisWeek: key?.usage_weekly, thisMonth: monthly, scope: "this key")
        } else {
            nil
        }

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: total > 0 ? percent : 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: resetDesc),
            secondary: keyInfo.flatMap { Self.keyLimitWindow($0, now: now) },
            tertiary: keyInfo.flatMap { Self.freeRequestsWindow($0, now: now) },
            balance: ProviderBalance(
                available: balance,
                currency: "USD",
                lifetimeSpent: used,
                reportedSpend: reported),
            updatedAt: now,
            identity: identity)
    }

    /// The key's own spending limit, when one is set. OpenRouter resets it on a
    /// UTC calendar boundary named by `limit_reset` (daily/weekly/monthly);
    /// "never" or unknown means a lifetime cap with no reset.
    static func keyLimitWindow(_ keyInfo: OpenRouterKeyInfoResponse, now: Date) -> RateWindow? {
        guard let limit = keyInfo.data?.limit, limit > 0 else { return nil }
        let remaining = keyInfo.data?.limit_remaining ?? max(0, limit - (keyInfo.data?.usage ?? 0))
        let period = OpenRouterResetPeriod(rawValue: keyInfo.data?.limit_reset?.lowercased() ?? "")
        return RateWindow(
            usedPercent: min(100, max(0, (limit - remaining) / limit * 100)),
            windowMinutes: period?.minutes,
            resetsAt: period?.nextReset(after: now),
            resetDescription: String(format: "$%.2f of $%.2f left", remaining, limit),
            label: "Key limit",
            hasKnownLimit: true)
    }

    /// Daily free-model request quota (resets at UTC midnight).
    static func freeRequestsWindow(_ keyInfo: OpenRouterKeyInfoResponse, now: Date) -> RateWindow? {
        guard let quota = keyInfo.data?.free_model_daily_requests, let limit = quota.limit, limit > 0 else {
            return nil
        }
        let used = quota.used ?? quota.remaining.map { limit - $0 } ?? 0
        return RateWindow(
            usedPercent: min(100, max(0, used / limit * 100)),
            windowMinutes: 1440,
            resetsAt: OpenRouterResetPeriod.daily.nextReset(after: now),
            resetDescription: nil,
            label: "Free requests",
            hasKnownLimit: true)
    }

    func toCreditsSnapshot() -> CreditsSnapshot {
        CreditsSnapshot(
            remaining: self.remaining,
            events: [],
            updatedAt: Date())
    }
}

enum OpenRouterResetPeriod: String {
    case daily
    case weekly
    case monthly

    var minutes: Int {
        switch self {
        case .daily: 1440
        case .weekly: 10080
        case .monthly: 43200
        }
    }

    /// Next UTC boundary. Weeks start Monday, as ISO weeks do.
    func nextReset(after date: Date) -> Date? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let component: Calendar.Component = switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        }
        guard let start = calendar.dateInterval(of: component, for: date)?.start else { return nil }
        return calendar.date(byAdding: component, value: 1, to: start)
    }
}

// MARK: - Errors

enum OpenRouterAPIError: LocalizedError {
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
