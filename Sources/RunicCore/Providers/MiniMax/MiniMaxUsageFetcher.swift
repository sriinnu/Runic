import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MiniMax quota/usage response structure (New API)
public struct MiniMaxQuotaResponse: Decodable {
    public let baseResponse: MiniMaxBaseResponse
    public let modelRemains: [MiniMaxModelRemain]?

    enum CodingKeys: String, CodingKey {
        case baseResponse = "base_resp"
        case modelRemains = "model_remains"
    }
}

public struct MiniMaxModelRemain: Decodable {
    public let modelName: String?
    public let currentIntervalTotalCount: Int
    public let currentIntervalUsageCount: Int
    public let currentIntervalRemainingPercent: Double?
    public let startTime: Int64?
    public let endTime: Int64?
    public let remainsTime: Int64?
    public let currentWeeklyTotalCount: Int?
    public let currentWeeklyUsageCount: Int?
    public let currentWeeklyRemainingPercent: Double?
    public let weeklyStartTime: Int64?
    public let weeklyEndTime: Int64?
    public let weeklyRemainsTime: Int64?

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case currentIntervalTotalCount = "current_interval_total_count"
        case currentIntervalUsageCount = "current_interval_usage_count"
        case currentIntervalRemainingPercent = "current_interval_remaining_percent"
        case startTime = "start_time"
        case endTime = "end_time"
        case remainsTime = "remains_time"
        case currentWeeklyTotalCount = "current_weekly_total_count"
        case currentWeeklyUsageCount = "current_weekly_usage_count"
        case currentWeeklyRemainingPercent = "current_weekly_remaining_percent"
        case weeklyStartTime = "weekly_start_time"
        case weeklyEndTime = "weekly_end_time"
        case weeklyRemainsTime = "weekly_remains_time"
    }
}

public struct MiniMaxBaseResponse: Decodable {
    public let statusCode: Int
    public let statusMsg: String

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMsg = "status_msg"
    }
}

/// A single model's quota entry from `model_remains`. MiniMax plans track
/// separate quotas per model, so callers keep every entry instead of just the
/// first one.
public struct MiniMaxModelQuota: Sendable {
    public let total: Int
    /// Raw count from the API. For coding_plan this is the remaining count;
    /// for token_plan it is the used count. Prefer `remainingPercent` when
    /// the endpoint provides it.
    public let used: Int
    public let modelName: String?
    /// Pre-computed remaining percentage from the API (token_plan provides
    /// `current_interval_remaining_percent`). When set, `usedPercent` is
    /// derived directly from this value instead of computed from counts.
    public let remainingPercent: Double?

    public init(
        total: Int,
        used: Int,
        modelName: String? = nil,
        remainingPercent: Double? = nil)
    {
        self.total = total
        self.used = used
        self.modelName = modelName
        self.remainingPercent = remainingPercent
    }

    var remaining: Int {
        if let rp = self.remainingPercent {
            return Int(round(Double(self.total) * rp / 100.0))
        }
        // Legacy coding_plan path: the `used` field holds the *remaining* count.
        return max(0, min(self.used, self.total))
    }

    var usedPercent: Double {
        if let rp = self.remainingPercent {
            return max(0, min(100, 100 - rp))
        }
        // Legacy coding_plan path: `used` is actual remaining count.
        let usedCount = max(0, self.total - self.remaining)
        return self.total > 0 ? (Double(usedCount) / Double(self.total)) * 100.0 : 0.0
    }

    fileprivate func toRateWindow(
        windowMinutes: Int? = nil,
        resetsAt: Date? = nil) -> RateWindow
    {
        RateWindow(
            usedPercent: self.usedPercent,
            windowMinutes: windowMinutes ?? 24 * 60,
            resetsAt: resetsAt,
            resetDescription: "\(self.remaining) / \(self.total) remaining",
            label: self.modelName?.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public struct MiniMaxUsageSnapshot: Sendable {
    public let total: Int
    public let used: Int
    public let modelName: String?
    /// Pre-computed remaining percent from the API, when available
    /// (token_plan provides `current_interval_remaining_percent`).
    public let remainingPercent: Double?
    /// Additional per-model quotas beyond the primary one (for example a
    /// "spark"/preview tier reported alongside the standard model).
    public let additionalModels: [MiniMaxModelQuota]
    /// Weekly quota for the primary model, when the endpoint reports one.
    public let weeklyQuota: MiniMaxModelQuota?
    /// Session window duration in minutes, derived from start/end timestamps.
    public let sessionWindowMinutes: Int?
    /// When the session quota resets.
    public let sessionResetsAt: Date?
    /// When the weekly quota resets.
    public let weeklyResetsAt: Date?
    public let updatedAt: Date

    public init(
        total: Int,
        used: Int,
        modelName: String? = nil,
        remainingPercent: Double? = nil,
        additionalModels: [MiniMaxModelQuota] = [],
        weeklyQuota: MiniMaxModelQuota? = nil,
        sessionWindowMinutes: Int? = nil,
        sessionResetsAt: Date? = nil,
        weeklyResetsAt: Date? = nil,
        updatedAt: Date)
    {
        self.total = total
        self.used = used
        self.modelName = modelName
        self.remainingPercent = remainingPercent
        self.additionalModels = additionalModels
        self.weeklyQuota = weeklyQuota
        self.sessionWindowMinutes = sessionWindowMinutes
        self.sessionResetsAt = sessionResetsAt
        self.weeklyResetsAt = weeklyResetsAt
        self.updatedAt = updatedAt
    }

    public var isValid: Bool {
        self.total > 0
    }
}

extension MiniMaxUsageSnapshot {
    public func toUsageSnapshot() -> UsageSnapshot {
        let primaryQuota = MiniMaxModelQuota(
            total: self.total,
            used: self.used,
            modelName: self.modelName,
            remainingPercent: self.remainingPercent)
        let primary = primaryQuota.toRateWindow(
            windowMinutes: self.sessionWindowMinutes,
            resetsAt: self.sessionResetsAt)
        // Surfacing weekly quota as secondary — the only slot available
        // alongside primary, so users see both session *and* cycle usage.
        let secondary = self.weeklyQuota?.toRateWindow(
            windowMinutes: 7 * 24 * 60,
            resetsAt: self.weeklyResetsAt)
        // Additional model quotas beyond the primary and beyond the weekly
        // slot fill tertiary.
        let tertiary = self.additionalModels.first?.toRateWindow()

        let identity = ProviderIdentitySnapshot(
            providerID: .minimax,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "api-key")

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            providerCost: nil,
            updatedAt: self.updatedAt,
            identity: identity)
    }
}

/// Fetches usage stats from the MiniMax API
public struct MiniMaxUsageFetcher: Sendable {
    private static let log = RunicLog.logger("minimax-usage")

    /// token_plan/remains accepts Bearer-token auth and includes
    /// pre-computed `remaining_percent` alongside weekly quota fields.
    private static let quotaAPIURL = "https://www.minimax.io/v1/token_plan/remains"

    /// Fetches usage stats from MiniMax using the provided API key.
    public static func fetchUsage(apiKey: String) async throws -> MiniMaxUsageSnapshot {
        guard !apiKey.isEmpty else {
            throw MiniMaxUsageError.invalidCredentials
        }

        var request = URLRequest(url: URL(string: quotaAPIURL)!)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await Self.performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxUsageError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.log.error("MiniMax API returned \(httpResponse.statusCode): \(errorMessage)")
            throw MiniMaxUsageError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        Self.log.debug("MiniMax API response: HTTP \(httpResponse.statusCode), \(data.count) bytes")

        let decoder = JSONDecoder()
        do {
            let apiResponse = try decoder.decode(MiniMaxQuotaResponse.self, from: data)

            if apiResponse.baseResponse.statusCode != 0 {
                throw MiniMaxUsageError.apiError(apiResponse.baseResponse.statusMsg)
            }

            guard let models = apiResponse.modelRemains, !models.isEmpty else {
                throw MiniMaxUsageError.parseFailed("No model quota found")
            }

            // Pick the first model with a non-zero session quota as primary.
            guard let primaryModel = models.first(where: { $0.currentIntervalTotalCount > 0 })
                ?? models.first
            else {
                throw MiniMaxUsageError.parseFailed("No model quota found")
            }

            let primaryName = primaryModel.modelName?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // Only surface additional entries that have a real, distinct model
            // name and a non-zero quota.
            let additionalModels: [MiniMaxModelQuota] = models
                .filter { $0.modelName != primaryModel.modelName }
                .filter {
                    let name = ($0.modelName ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return !name.isEmpty && name != primaryName
                        && $0.currentIntervalTotalCount > 0
                }
                .map {
                    MiniMaxModelQuota(
                        total: $0.currentIntervalTotalCount,
                        used: $0.currentIntervalUsageCount,
                        modelName: $0.modelName,
                        remainingPercent: $0.currentIntervalRemainingPercent)
                }

            // Build weekly quota when the endpoint supplies a non-zero total.
            let weeklyQuota: MiniMaxModelQuota? = if let weeklyTotal = primaryModel.currentWeeklyTotalCount,
                                                     weeklyTotal > 0
            {
                MiniMaxModelQuota(
                    total: weeklyTotal,
                    used: primaryModel.currentWeeklyUsageCount ?? 0,
                    modelName: primaryName,
                    remainingPercent: primaryModel.currentWeeklyRemainingPercent)
            } else {
                nil
            }

            let sessionWindowMinutes = Self.windowMinutes(
                start: primaryModel.startTime,
                end: primaryModel.endTime)
            let sessionResetsAt = Self.resolveReset(
                remainsTime: primaryModel.remainsTime,
                endTime: primaryModel.endTime)
            let weeklyResetsAt = Self.resolveReset(
                remainsTime: primaryModel.weeklyRemainsTime,
                endTime: primaryModel.weeklyEndTime)

            return MiniMaxUsageSnapshot(
                total: primaryModel.currentIntervalTotalCount,
                used: primaryModel.currentIntervalUsageCount,
                modelName: primaryName,
                remainingPercent: primaryModel.currentIntervalRemainingPercent,
                additionalModels: additionalModels,
                weeklyQuota: weeklyQuota,
                sessionWindowMinutes: sessionWindowMinutes,
                sessionResetsAt: sessionResetsAt,
                weeklyResetsAt: weeklyResetsAt,
                updatedAt: Date())

        } catch let error as MiniMaxUsageError {
            throw error
        } catch {
            Self.log.error("MiniMax parsing error: \(error.localizedDescription)")
            throw MiniMaxUsageError.parseFailed(error.localizedDescription)
        }
    }

    // MARK: - HTTP helpers

    /// Single retry for transient failures (5xx + common network errors)
    /// with a 2-second backoff.
    private static func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        func shouldRetry(_ error: Error?, statusCode: Int?) -> Bool {
            if let code = statusCode, (500...599).contains(code) { return true }
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut, .cannotConnectToHost, .networkConnectionLost,
                     .dnsLookupFailed, .notConnectedToInternet:
                    return true
                default: break
                }
            }
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (data, response)
            }
            if shouldRetry(nil, statusCode: http.statusCode) {
                Self.log.debug("MiniMax retrying after 2s", metadata: [
                    "status": "\(http.statusCode)",
                ])
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return try await URLSession.shared.data(for: request)
            }
            return (data, response)
        } catch {
            if shouldRetry(error, statusCode: nil) {
                Self.log.debug("MiniMax retrying after network error", metadata: [
                    "error": "\(error)",
                ])
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return try await URLSession.shared.data(for: request)
            }
            throw error
        }
    }

    // MARK: - Timestamp helpers

    private static func windowMinutes(start: Int64?, end: Int64?) -> Int? {
        guard let start, let end, start > 0, end > start else { return nil }
        let minutes = Int((end - start) / 1000 / 60)
        return minutes > 0 ? minutes : nil
    }

    private static func resolveReset(remainsTime: Int64?, endTime: Int64?) -> Date? {
        if let ms = remainsTime, ms > 0 {
            return Date(timeIntervalSinceNow: TimeInterval(ms) / 1000.0)
        }
        if let ms = endTime, ms > 0 {
            return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        }
        return nil
    }
}

/// Errors that can occur during MiniMax usage fetching
public enum MiniMaxUsageError: LocalizedError, Sendable {
    case invalidCredentials
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid MiniMax API credentials"
        case let .networkError(message):
            "MiniMax network error: \(message)"
        case let .apiError(message):
            "MiniMax API error: \(message)"
        case let .parseFailed(message):
            "Failed to parse MiniMax response: \(message)"
        }
    }
}
