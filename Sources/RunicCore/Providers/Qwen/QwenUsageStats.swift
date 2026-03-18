import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Model usage entry

/// Per-model usage entry from the DashScope usage API.
public struct QwenModelUsageEntry: Sendable {
    public let modelID: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let requestCount: Int
    public let estimatedCostUSD: Double?

    public init(
        modelID: String,
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        requestCount: Int,
        estimatedCostUSD: Double?)
    {
        self.modelID = modelID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.requestCount = requestCount
        self.estimatedCostUSD = estimatedCostUSD
    }
}

// MARK: - Pricing table

/// Static pricing lookup for Qwen models (USD per 1M tokens).
public enum QwenModelPricing {
    public struct Tier: Sendable {
        public let inputPerMillion: Double
        public let outputPerMillion: Double
        public let contextWindow: Int
    }

    private static let tiers: [String: Tier] = [
        "qwen-turbo": Tier(inputPerMillion: 0.30, outputPerMillion: 0.60, contextWindow: 131_072),
        "qwen-turbo-latest": Tier(inputPerMillion: 0.30, outputPerMillion: 0.60, contextWindow: 131_072),
        "qwen-plus": Tier(inputPerMillion: 0.80, outputPerMillion: 2.00, contextWindow: 131_072),
        "qwen-plus-latest": Tier(inputPerMillion: 0.80, outputPerMillion: 2.00, contextWindow: 131_072),
        "qwen-max": Tier(inputPerMillion: 2.40, outputPerMillion: 9.60, contextWindow: 32_768),
        "qwen-max-latest": Tier(inputPerMillion: 2.40, outputPerMillion: 9.60, contextWindow: 32_768),
        "qwen-vl-max": Tier(inputPerMillion: 3.00, outputPerMillion: 9.60, contextWindow: 32_768),
        "qwen-vl-max-latest": Tier(inputPerMillion: 3.00, outputPerMillion: 9.60, contextWindow: 32_768),
        "qwen-vl-plus": Tier(inputPerMillion: 0.80, outputPerMillion: 2.00, contextWindow: 131_072),
        "qwen-long": Tier(inputPerMillion: 0.50, outputPerMillion: 2.00, contextWindow: 10_000_000),
        "qwen2.5-72b-instruct": Tier(inputPerMillion: 0.56, outputPerMillion: 1.12, contextWindow: 131_072),
        "qwen2.5-32b-instruct": Tier(inputPerMillion: 0.49, outputPerMillion: 0.98, contextWindow: 131_072),
        "qwen2.5-14b-instruct": Tier(inputPerMillion: 0.28, outputPerMillion: 0.56, contextWindow: 131_072),
        "qwen2.5-7b-instruct": Tier(inputPerMillion: 0.14, outputPerMillion: 0.28, contextWindow: 131_072),
        "qwen2.5-coder-32b-instruct": Tier(inputPerMillion: 0.49, outputPerMillion: 0.98, contextWindow: 131_072),
        "qwen2.5-coder-14b-instruct": Tier(inputPerMillion: 0.28, outputPerMillion: 0.56, contextWindow: 131_072),
        "qwen2.5-coder-7b-instruct": Tier(inputPerMillion: 0.14, outputPerMillion: 0.28, contextWindow: 131_072),
    ]

    /// Returns pricing tier for a model code, case-insensitive with fuzzy matching.
    public static func tier(for modelID: String) -> Tier? {
        let key = modelID.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = self.tiers[key] { return exact }
        return self.tiers.first { key.contains($0.key) || $0.key.contains(key) }?.value
    }

    /// Estimates cost from separate input/output token counts.
    public static func estimateCost(inputTokens: Int, outputTokens: Int, modelID: String) -> Double? {
        guard let tier = self.tier(for: modelID), (inputTokens + outputTokens) > 0 else { return nil }
        let inputCost = (Double(inputTokens) / 1_000_000) * tier.inputPerMillion
        let outputCost = (Double(outputTokens) / 1_000_000) * tier.outputPerMillion
        return inputCost + outputCost
    }

    /// Estimates cost assuming a 60/40 input/output token split (typical for coding).
    public static func estimateCost(tokens: Int, modelID: String) -> Double? {
        guard let tier = self.tier(for: modelID), tokens > 0 else { return nil }
        let inputTokens = Double(tokens) * 0.6
        let outputTokens = Double(tokens) * 0.4
        let inputCost = (inputTokens / 1_000_000) * tier.inputPerMillion
        let outputCost = (outputTokens / 1_000_000) * tier.outputPerMillion
        return inputCost + outputCost
    }
}

// MARK: - Complete snapshot

/// Complete Qwen DashScope usage response.
public struct QwenUsageSnapshot: Sendable {
    public let modelEntries: [QwenModelUsageEntry]
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalTokens: Int
    public let totalRequests: Int
    public let totalEstimatedCostUSD: Double
    public let updatedAt: Date

    public init(
        modelEntries: [QwenModelUsageEntry],
        totalInputTokens: Int,
        totalOutputTokens: Int,
        totalTokens: Int,
        totalRequests: Int,
        totalEstimatedCostUSD: Double,
        updatedAt: Date)
    {
        self.modelEntries = modelEntries
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.totalTokens = totalTokens
        self.totalRequests = totalRequests
        self.totalEstimatedCostUSD = totalEstimatedCostUSD
        self.updatedAt = updatedAt
    }
}

extension QwenUsageSnapshot {
    public func toUsageSnapshot() -> UsageSnapshot {
        // Build a usage percent based on token consumption (no hard cap from API,
        // so we report a simple token metric).
        let primary = RateWindow(
            usedPercent: 0,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: nil)

        let identity = ProviderIdentitySnapshot(
            providerID: .qwen,
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
}

// MARK: - Private API response models

/// Flexible usage response from DashScope API (best-effort decoding).
private struct QwenUsageResponse: Decodable {
    let request_id: String?
    let code: String?
    let message: String?
    let output: QwenUsageOutput?
    let usage: QwenUsageData?

    /// Check for success: no error code, or explicit success.
    var isSuccess: Bool {
        self.code == nil || self.code == "200" || self.code == "Success"
    }
}

private struct QwenUsageOutput: Decodable {
    let models: [QwenModelUsageRaw]?
    let total_tokens: Int?
    let total_input_tokens: Int?
    let total_output_tokens: Int?
}

private struct QwenUsageData: Decodable {
    let models: [QwenModelUsageRaw]?
    let total_tokens: Int?
    let input_tokens: Int?
    let output_tokens: Int?
}

private struct QwenModelUsageRaw: Decodable {
    let model_id: String?
    let model: String?
    let input_tokens: Int?
    let output_tokens: Int?
    let total_tokens: Int?
    let tokens: Int?
    let request_count: Int?
    let requests: Int?
    let calls: Int?

    var resolvedModelID: String? { self.model_id ?? self.model }
    var resolvedInputTokens: Int { self.input_tokens ?? 0 }
    var resolvedOutputTokens: Int { self.output_tokens ?? 0 }
    var resolvedTotalTokens: Int { self.total_tokens ?? self.tokens ?? (self.resolvedInputTokens + self.resolvedOutputTokens) }
    var resolvedRequestCount: Int { self.request_count ?? self.requests ?? self.calls ?? 0 }
}

// MARK: - Fetcher

/// Fetches usage stats from the DashScope API.
public struct QwenUsageFetcher: Sendable {
    private static let log = RunicLog.logger("qwen-usage")

    private static let usageAPIURL = "https://dashscope.aliyuncs.com/api/v1/usage"

    /// Fetches usage data from DashScope.
    public static func fetchUsage(apiKey: String) async throws -> QwenUsageSnapshot {
        guard !apiKey.isEmpty else {
            throw QwenUsageError.invalidCredentials
        }

        let request = self.makeRequest(url: self.usageAPIURL, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QwenUsageError.networkError("Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.log.error("DashScope usage API returned \(httpResponse.statusCode): \(errorMessage)")
            throw QwenUsageError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            Self.log.debug("DashScope usage response: \(jsonString)")
        }

        let apiResponse = try JSONDecoder().decode(QwenUsageResponse.self, from: data)
        guard apiResponse.isSuccess else {
            throw QwenUsageError.apiError(apiResponse.message ?? "Unknown API error")
        }

        // Parse model entries from either output or usage section.
        let rawModels = apiResponse.output?.models ?? apiResponse.usage?.models ?? []

        var entries: [QwenModelUsageEntry] = []
        var totalInput = 0
        var totalOutput = 0
        var totalTokens = 0
        var totalRequests = 0
        var totalCost = 0.0

        for model in rawModels {
            guard let modelID = model.resolvedModelID else { continue }
            let input = model.resolvedInputTokens
            let output = model.resolvedOutputTokens
            let tokens = model.resolvedTotalTokens
            let requests = model.resolvedRequestCount
            let cost: Double?
            if input > 0 || output > 0 {
                cost = QwenModelPricing.estimateCost(inputTokens: input, outputTokens: output, modelID: modelID)
            } else {
                cost = QwenModelPricing.estimateCost(tokens: tokens, modelID: modelID)
            }
            entries.append(QwenModelUsageEntry(
                modelID: modelID,
                inputTokens: input,
                outputTokens: output,
                totalTokens: tokens,
                requestCount: requests,
                estimatedCostUSD: cost))
            totalInput += input
            totalOutput += output
            totalTokens += tokens
            totalRequests += requests
            totalCost += cost ?? 0
        }

        // Prefer API-reported totals if available.
        let resolvedTotalInput = apiResponse.output?.total_input_tokens
            ?? apiResponse.usage?.input_tokens ?? totalInput
        let resolvedTotalOutput = apiResponse.output?.total_output_tokens
            ?? apiResponse.usage?.output_tokens ?? totalOutput
        let resolvedTotalTokens = apiResponse.output?.total_tokens
            ?? apiResponse.usage?.total_tokens ?? totalTokens

        return QwenUsageSnapshot(
            modelEntries: entries.sorted { $0.totalTokens > $1.totalTokens },
            totalInputTokens: resolvedTotalInput,
            totalOutputTokens: resolvedTotalOutput,
            totalTokens: resolvedTotalTokens,
            totalRequests: totalRequests,
            totalEstimatedCostUSD: totalCost,
            updatedAt: Date())
    }

    // MARK: - Helpers

    private static func makeRequest(url: String, apiKey: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        return request
    }
}

// MARK: - Errors

public enum QwenUsageError: LocalizedError, Sendable {
    case invalidCredentials
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid DashScope API credentials"
        case let .networkError(message):
            "DashScope network error: \(message)"
        case let .apiError(message):
            "DashScope API error: \(message)"
        case let .parseFailed(message):
            "Failed to parse DashScope response: \(message)"
        }
    }
}
