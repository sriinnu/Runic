import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MiniMax quota/usage response structure
public struct MiniMaxQuotaResponse: Decodable {
    public let baseResponse: MiniMaxBaseResponse
    public let quota: MiniMaxQuota?

    enum CodingKeys: String, CodingKey {
        case baseResponse = "base_resp"
        case quota
    }
}

public struct MiniMaxBaseResponse: Decodable {
    public let retcode: Int
    public let msg: String
    public let success: Bool
}

public struct MiniMaxQuota: Decodable {
    public let totalQuota: Int
    public let usedQuota: Int
    public let remainingQuota: Int
    public let quotaType: String?

    enum CodingKeys: String, CodingKey {
        case totalQuota = "total_quota"
        case usedQuota = "used_quota"
        case remainingQuota = "remaining_quota"
        case quotaType = "quota_type"
    }
}

public struct MiniMaxUsageSnapshot: Sendable {
    public let totalQuota: Int
    public let usedQuota: Int
    public let remainingQuota: Int
    public let percentUsed: Double
    public let updatedAt: Date

    public init(totalQuota: Int, usedQuota: Int, remainingQuota: Int, percentUsed: Double, updatedAt: Date) {
        self.totalQuota = totalQuota
        self.usedQuota = usedQuota
        self.remainingQuota = remainingQuota
        self.percentUsed = percentUsed
        self.updatedAt = updatedAt
    }

    public var isValid: Bool {
        self.totalQuota > 0
    }
}

extension MiniMaxUsageSnapshot {
    public func toUsageSnapshot() -> UsageSnapshot {
        let primary = RateWindow(
            usedPercent: self.percentUsed,
            windowMinutes: 24 * 60,  // Daily reset
            resetsAt: self.nextResetDate(),
            resetDescription: "Resets at midnight")

        let identity = ProviderIdentitySnapshot(
            providerID: .minimax,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: nil)
        return UsageSnapshot(
            primary: primary,
            secondary: nil,
            tertiary: nil,
            providerCost: nil,
            updatedAt: self.updatedAt,
            identity: identity)
    }

    private func nextResetDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 0
        components.minute = 0
        components.second = 0

        guard let today = calendar.date(from: components) else { return nil }
        return calendar.date(byAdding: .day, value: 1, to: today)
    }
}

/// Fetches usage stats from the MiniMax API
public struct MiniMaxUsageFetcher: Sendable {
    private static let log = RunicLog.logger("minimax-usage")

    /// Base URL for MiniMax quota API
    private static let quotaAPIURL = "https://api.minimax.chat/v1/text/quota"

    /// Fetches usage stats from MiniMax using the provided API key
    public static func fetchUsage(apiKey: String, groupID: String) async throws -> MiniMaxUsageSnapshot {
        guard !apiKey.isEmpty else {
            throw MiniMaxUsageError.invalidCredentials
        }
        guard !groupID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MiniMaxUsageError.invalidCredentials
        }

        var request = URLRequest(url: URL(string: quotaAPIURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(groupID, forHTTPHeaderField: "X-Group-Id")
        request.setValue(groupID, forHTTPHeaderField: "Group-Id")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxUsageError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.log.error("MiniMax API returned \(httpResponse.statusCode): \(errorMessage)")
            throw MiniMaxUsageError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            Self.log.debug("MiniMax API response: \(jsonString)")
        }

        let decoder = JSONDecoder()
        do {
            let apiResponse = try decoder.decode(MiniMaxQuotaResponse.self, from: data)

            guard apiResponse.baseResponse.success || apiResponse.baseResponse.retcode == 0 else {
                throw MiniMaxUsageError.apiError(apiResponse.baseResponse.msg)
            }

            guard let quota = apiResponse.quota else {
                throw MiniMaxUsageError.parseFailed("No quota data in response")
            }

            let totalQuota = quota.totalQuota
            let usedQuota = quota.usedQuota
            let remainingQuota = quota.remainingQuota
            let percentUsed = totalQuota > 0 ? (Double(usedQuota) / Double(totalQuota)) * 100 : 0

            return MiniMaxUsageSnapshot(
                totalQuota: totalQuota,
                usedQuota: usedQuota,
                remainingQuota: remainingQuota,
                percentUsed: min(100, percentUsed),
                updatedAt: Date())
        } catch let error as DecodingError {
            Self.log.error("MiniMax JSON decoding error: \(error.localizedDescription)")
            throw MiniMaxUsageError.parseFailed(error.localizedDescription)
        } catch let error as MiniMaxUsageError {
            throw error
        } catch {
            Self.log.error("MiniMax parsing error: \(error.localizedDescription)")
            throw MiniMaxUsageError.parseFailed(error.localizedDescription)
        }
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
