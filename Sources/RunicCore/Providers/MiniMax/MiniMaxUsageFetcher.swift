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
    public let modelName: String
    public let currentIntervalTotalCount: Int
    public let currentIntervalUsageCount: Int

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case currentIntervalTotalCount = "current_interval_total_count"
        case currentIntervalUsageCount = "current_interval_usage_count"
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

public struct MiniMaxUsageSnapshot: Sendable {
    public let total: Int
    public let used: Int
    public let modelName: String?
    public let updatedAt: Date

    public init(total: Int, used: Int, modelName: String? = nil, updatedAt: Date) {
        self.total = total
        self.used = used
        self.modelName = modelName
        self.updatedAt = updatedAt
    }

    public var isValid: Bool {
        self.total > 0
    }
}

extension MiniMaxUsageSnapshot {
    public func toUsageSnapshot() -> UsageSnapshot {
        // MiniMax's `coding_plan/remains` endpoint reports remaining allowance here.
        // Example: 4500/4500 means the quota is untouched, so used is 0%.
        let remaining = max(0, min(self.used, self.total))
        let usedCount = max(0, self.total - remaining)
        let percent = self.total > 0 ? (Double(usedCount) / Double(self.total)) * 100.0 : 0.0

        let primary = RateWindow(
            usedPercent: percent,
            windowMinutes: 24 * 60,
            resetsAt: nil,
            resetDescription: "\(remaining) / \(self.total) remaining",
            label: self.modelName?.trimmingCharacters(in: .whitespacesAndNewlines))

        let identity = ProviderIdentitySnapshot(
            providerID: .minimax,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "api-key")

        return UsageSnapshot(
            primary: primary,
            secondary: nil,
            tertiary: nil,
            providerCost: nil,
            updatedAt: self.updatedAt,
            identity: identity)
    }
}

/// Fetches usage stats from the MiniMax API
public struct MiniMaxUsageFetcher: Sendable {
    private static let log = RunicLog.logger("minimax-usage")

    /// Corrected endpoint based on documentation
    private static let quotaAPIURL = "https://platform.minimax.io/v1/api/openplatform/coding_plan/remains"

    /// Fetches usage stats from MiniMax using the provided API key
    /// GroupID is no longer required for this endpoint based on user input
    public static func fetchUsage(apiKey: String) async throws -> MiniMaxUsageSnapshot {
        guard !apiKey.isEmpty else {
            throw MiniMaxUsageError.invalidCredentials
        }

        var request = URLRequest(url: URL(string: quotaAPIURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

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

            guard let firstModel = apiResponse.modelRemains?.first else {
                throw MiniMaxUsageError.parseFailed("No model quota found")
            }

            return MiniMaxUsageSnapshot(
                total: firstModel.currentIntervalTotalCount,
                used: firstModel.currentIntervalUsageCount,
                modelName: firstModel.modelName,
                updatedAt: Date())

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
