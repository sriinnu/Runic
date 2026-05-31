import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Fetcher

/// Fetches usage stats from the z.ai API (all 3 endpoints).
public struct ZaiUsageFetcher: Sendable {
    private static let log = RunicLog.logger("zai-usage")

    private static let baseURL = "https://api.z.ai/api/monitor/usage"
    private static let quotaAPIURL = "\(baseURL)/quota/limit"
    private static let modelUsageAPIURL = "\(baseURL)/model-usage"
    private static let toolUsageAPIURL = "\(baseURL)/tool-usage"

    /// Fetches all available usage data from z.ai in parallel.
    public static func fetchUsage(apiKey: String) async throws -> ZaiUsageSnapshot {
        guard !apiKey.isEmpty else {
            throw ZaiUsageError.invalidCredentials
        }

        // Fetch quota (required) and model/tool usage (best-effort) concurrently.
        async let quotaTask = self.fetchQuota(apiKey: apiKey)
        async let modelTask = self.fetchModelUsageBestEffort(apiKey: apiKey)
        async let toolTask = self.fetchToolUsageBestEffort(apiKey: apiKey)

        let (tokenLimit, timeLimit, planName) = try await quotaTask
        let modelUsage = await modelTask
        let toolUsage = await toolTask

        return ZaiUsageSnapshot(
            tokenLimit: tokenLimit,
            timeLimit: timeLimit,
            planName: planName,
            modelUsage: modelUsage,
            toolUsage: toolUsage,
            updatedAt: Date())
    }

    // MARK: - Quota endpoint (required)

    private static func fetchQuota(apiKey: String) async throws -> (ZaiLimitEntry?, ZaiLimitEntry?, String?) {
        let request = try self.makeRequest(url: self.quotaAPIURL, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZaiUsageError.networkError("Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.log.error("z.ai quota API returned \(httpResponse.statusCode): \(errorMessage)")
            throw ZaiUsageError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        Self.log.debug("z.ai quota response: HTTP \(httpResponse.statusCode), \(data.count) bytes")

        let apiResponse: ZaiQuotaLimitResponse
        do {
            apiResponse = try JSONDecoder().decode(ZaiQuotaLimitResponse.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            Self.log.error("z.ai quota parse failed: \(error) — body: \(body)")
            throw ZaiUsageError.parseFailed(error.localizedDescription)
        }
        guard apiResponse.isSuccess else {
            throw ZaiUsageError.apiError(apiResponse.errorMessage)
        }
        guard let quotaData = apiResponse.data else {
            throw ZaiUsageError.apiError("API returned success but no data")
        }

        var tokenLimit: ZaiLimitEntry?
        var timeLimit: ZaiLimitEntry?
        for limit in quotaData.limits {
            if let entry = limit.toLimitEntry() {
                switch entry.type {
                case .tokensLimit: tokenLimit = entry
                case .timeLimit: timeLimit = entry
                }
            }
        }
        return (tokenLimit, timeLimit, quotaData.planName)
    }

    // MARK: - Model usage endpoint (best-effort)

    private static func fetchModelUsageBestEffort(apiKey: String) async -> ZaiModelUsageSummary? {
        do {
            return try await self.fetchModelUsage(apiKey: apiKey)
        } catch {
            self.log.info("z.ai model-usage endpoint unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    private static func fetchModelUsage(apiKey: String) async throws -> ZaiModelUsageSummary {
        let (startTime, endTime) = self.rolling24hWindow()
        let urlString = "\(modelUsageAPIURL)?startTime=\(startTime)&endTime=\(endTime)"
        let request = try self.makeRequest(url: urlString, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ZaiUsageError.apiError("model-usage endpoint returned non-200")
        }

        Self.log.debug("z.ai model-usage response: HTTP \(httpResponse.statusCode), \(data.count) bytes")

        let raw = try JSONDecoder().decode(ZaiModelUsageResponse.self, from: data)
        let models = raw.data?.models ?? []

        var entries: [ZaiModelUsageEntry] = []
        var totalTokens = 0
        var totalPrompts = 0
        var totalCost = 0.0

        for model in models {
            guard let code = model.resolvedModelCode else { continue }
            let tokens = model.resolvedTokens
            let prompts = model.resolvedPrompts
            let cost = ZaiModelPricing.estimateCost(tokens: tokens, modelCode: code)
            entries.append(ZaiModelUsageEntry(
                modelCode: code,
                tokens: tokens,
                prompts: prompts,
                estimatedCostUSD: cost))
            totalTokens += tokens
            totalPrompts += prompts
            totalCost += cost ?? 0
        }

        // If the API returned totals, prefer those.
        let resolvedTotalTokens = raw.data?.resolvedTotalTokens ?? totalTokens
        let resolvedTotalPrompts = raw.data?.resolvedTotalPrompts ?? totalPrompts

        let (startDate, endDate) = self.rolling24hDates()
        return ZaiModelUsageSummary(
            entries: entries.sorted { $0.tokens > $1.tokens },
            totalTokens: resolvedTotalTokens,
            totalPrompts: resolvedTotalPrompts,
            totalEstimatedCostUSD: totalCost,
            windowStart: startDate,
            windowEnd: endDate)
    }

    // MARK: - Tool usage endpoint (best-effort)

    private static func fetchToolUsageBestEffort(apiKey: String) async -> ZaiToolUsageSummary? {
        do {
            return try await self.fetchToolUsage(apiKey: apiKey)
        } catch {
            self.log.info("z.ai tool-usage endpoint unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    private static func fetchToolUsage(apiKey: String) async throws -> ZaiToolUsageSummary {
        let (startTime, endTime) = self.rolling24hWindow()
        let urlString = "\(toolUsageAPIURL)?startTime=\(startTime)&endTime=\(endTime)"
        let request = try self.makeRequest(url: urlString, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ZaiUsageError.apiError("tool-usage endpoint returned non-200")
        }

        Self.log.debug("z.ai tool-usage response: HTTP \(httpResponse.statusCode), \(data.count) bytes")

        let raw = try JSONDecoder().decode(ZaiToolUsageResponse.self, from: data)
        let tools = raw.data?.tools ?? []

        var entries: [ZaiToolUsageEntry] = []
        var total = 0
        for tool in tools {
            guard let name = tool.resolvedName else { continue }
            let count = tool.resolvedCount
            entries.append(ZaiToolUsageEntry(toolName: name, count: count))
            total += count
        }

        return ZaiToolUsageSummary(
            entries: entries.sorted { $0.count > $1.count },
            totalCalls: total)
    }

    // MARK: - Helpers

    private static func makeRequest(url: String, apiKey: String) throws -> URLRequest {
        guard let requestURL = URL(string: url) else {
            throw ZaiUsageError.networkError("Invalid URL: \(url)")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        // z.ai expects "Bearer <token>" — add prefix if the user didn't include it.
        let authValue = if apiKey.lowercased().hasPrefix("bearer ") {
            "Bearer \(apiKey.dropFirst(7).trimmingCharacters(in: .whitespaces))"
        } else {
            "Bearer \(apiKey)"
        }
        request.setValue(authValue, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15
        return request
    }

    /// Returns (startTime, endTime) as millisecond timestamps for a 24h rolling window.
    private static func rolling24hWindow() -> (Int64, Int64) {
        let now = Date()
        let calendar = Calendar.current
        let startOfCurrentHour = calendar.dateInterval(of: .hour, for: now)!.start
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfCurrentHour)!
        let endOfCurrentHour = calendar.date(byAdding: .second, value: 3599, to: startOfCurrentHour)!

        let startMs = Int64(yesterday.timeIntervalSince1970 * 1000)
        let endMs = Int64(endOfCurrentHour.timeIntervalSince1970 * 1000)
        return (startMs, endMs)
    }

    private static func rolling24hDates() -> (Date, Date) {
        let now = Date()
        let calendar = Calendar.current
        let startOfCurrentHour = calendar.dateInterval(of: .hour, for: now)!.start
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfCurrentHour)!
        return (yesterday, now)
    }
}

// MARK: - Errors

public enum ZaiUsageError: LocalizedError, Sendable {
    case invalidCredentials
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid z.ai API credentials"
        case let .networkError(message):
            "z.ai network error: \(message)"
        case let .apiError(message):
            "z.ai API error: \(message)"
        case let .parseFailed(message):
            "Failed to parse z.ai response: \(message)"
        }
    }
}
