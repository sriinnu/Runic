import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Enums

/// Z.ai usage limit types from the API
public enum ZaiLimitType: String, Sendable {
    case timeLimit = "TIME_LIMIT"
    case tokensLimit = "TOKENS_LIMIT"
}

/// Z.ai usage limit unit types
public enum ZaiLimitUnit: Int, Sendable {
    case unknown = 0
    case days = 1
    case hours = 3
    case minutes = 5
}

// MARK: - Quota limit models

/// A single limit entry from the z.ai API
public struct ZaiLimitEntry: Sendable {
    public let type: ZaiLimitType
    public let unit: ZaiLimitUnit
    public let number: Int
    public let usage: Int
    public let currentValue: Int
    public let remaining: Int
    public let percentage: Double
    public let usageDetails: [ZaiUsageDetail]
    public let nextResetTime: Date?

    public init(
        type: ZaiLimitType,
        unit: ZaiLimitUnit,
        number: Int,
        usage: Int,
        currentValue: Int,
        remaining: Int,
        percentage: Double,
        usageDetails: [ZaiUsageDetail],
        nextResetTime: Date?)
    {
        self.type = type
        self.unit = unit
        self.number = number
        self.usage = usage
        self.currentValue = currentValue
        self.remaining = remaining
        self.percentage = percentage
        self.usageDetails = usageDetails
        self.nextResetTime = nextResetTime
    }
}

extension ZaiLimitEntry {
    public var usedPercent: Double {
        if let computed = self.computedUsedPercent {
            return computed
        }
        return self.percentage
    }

    public var windowMinutes: Int? {
        guard self.number > 0 else { return nil }
        switch self.unit {
        case .minutes:
            return self.number
        case .hours:
            return self.number * 60
        case .days:
            return self.number * 24 * 60
        case .unknown:
            return nil
        }
    }

    public var windowDescription: String? {
        guard self.number > 0 else { return nil }
        let unitLabel: String? = switch self.unit {
        case .minutes: "minute"
        case .hours: "hour"
        case .days: "day"
        case .unknown: nil
        }
        guard let unitLabel else { return nil }
        let suffix = self.number == 1 ? unitLabel : "\(unitLabel)s"
        return "\(self.number) \(suffix)"
    }

    public var windowLabel: String? {
        guard let description = self.windowDescription else { return nil }
        return "\(description) window"
    }

    private var computedUsedPercent: Double? {
        guard self.usage > 0 else { return nil }
        let limit = max(0, self.usage)
        guard limit > 0 else { return nil }

        let usedFromRemaining = limit - self.remaining
        let used = max(0, min(limit, max(usedFromRemaining, self.currentValue)))
        let percent = (Double(used) / Double(limit)) * 100
        return min(100, max(0, percent))
    }
}

/// Usage detail for MCP tools
public struct ZaiUsageDetail: Sendable, Codable {
    public let modelCode: String
    public let usage: Int

    public init(modelCode: String, usage: Int) {
        self.modelCode = modelCode
        self.usage = usage
    }
}

// MARK: - Model usage (24h breakdown)

/// Per-model usage entry from the model-usage endpoint.
public struct ZaiModelUsageEntry: Sendable {
    public let modelCode: String
    public let tokens: Int
    public let prompts: Int
    public let estimatedCostUSD: Double?

    public init(modelCode: String, tokens: Int, prompts: Int, estimatedCostUSD: Double?) {
        self.modelCode = modelCode
        self.tokens = tokens
        self.prompts = prompts
        self.estimatedCostUSD = estimatedCostUSD
    }
}

/// Aggregated model usage from the 24h rolling window.
public struct ZaiModelUsageSummary: Sendable {
    public let entries: [ZaiModelUsageEntry]
    public let totalTokens: Int
    public let totalPrompts: Int
    public let totalEstimatedCostUSD: Double
    public let windowStart: Date
    public let windowEnd: Date

    public init(
        entries: [ZaiModelUsageEntry],
        totalTokens: Int,
        totalPrompts: Int,
        totalEstimatedCostUSD: Double,
        windowStart: Date,
        windowEnd: Date)
    {
        self.entries = entries
        self.totalTokens = totalTokens
        self.totalPrompts = totalPrompts
        self.totalEstimatedCostUSD = totalEstimatedCostUSD
        self.windowStart = windowStart
        self.windowEnd = windowEnd
    }
}

// MARK: - Tool usage (24h breakdown)

/// Per-tool MCP usage entry from the tool-usage endpoint.
public struct ZaiToolUsageEntry: Sendable {
    public let toolName: String
    public let count: Int

    public init(toolName: String, count: Int) {
        self.toolName = toolName
        self.count = count
    }
}

/// Aggregated tool usage from the 24h rolling window.
public struct ZaiToolUsageSummary: Sendable {
    public let entries: [ZaiToolUsageEntry]
    public let totalCalls: Int

    public init(entries: [ZaiToolUsageEntry], totalCalls: Int) {
        self.entries = entries
        self.totalCalls = totalCalls
    }
}

// MARK: - Pricing table

/// Static pricing lookup for z.ai models (USD per 1M tokens).
public enum ZaiModelPricing {
    public struct Tier: Sendable {
        public let inputPerMillion: Double
        public let outputPerMillion: Double
        public let contextWindow: Int
    }

    private static let tiers: [String: Tier] = [
        "glm-4.7-flash": Tier(inputPerMillion: 0.06, outputPerMillion: 0.40, contextWindow: 203_000),
        "glm-4.7-flash-thinking": Tier(inputPerMillion: 0.06, outputPerMillion: 0.40, contextWindow: 203_000),
        "glm-4-32b": Tier(inputPerMillion: 0.10, outputPerMillion: 0.10, contextWindow: 128_000),
        "glm-4.5-air": Tier(inputPerMillion: 0.13, outputPerMillion: 0.85, contextWindow: 131_000),
        "glm-4.6v": Tier(inputPerMillion: 0.30, outputPerMillion: 0.90, contextWindow: 131_000),
        "glm-4.6v-thinking": Tier(inputPerMillion: 0.30, outputPerMillion: 0.90, contextWindow: 131_000),
        "glm-4.7": Tier(inputPerMillion: 0.38, outputPerMillion: 1.75, contextWindow: 203_000),
        "glm-4.7-thinking": Tier(inputPerMillion: 0.38, outputPerMillion: 1.75, contextWindow: 203_000),
        "glm-4.6": Tier(inputPerMillion: 0.39, outputPerMillion: 1.74, contextWindow: 205_000),
        "glm-4.6-thinking": Tier(inputPerMillion: 0.39, outputPerMillion: 1.74, contextWindow: 205_000),
        "glm-4.5v": Tier(inputPerMillion: 0.60, outputPerMillion: 1.80, contextWindow: 66_000),
        "glm-4.5v-thinking": Tier(inputPerMillion: 0.60, outputPerMillion: 1.80, contextWindow: 66_000),
        "glm-4.5": Tier(inputPerMillion: 0.60, outputPerMillion: 2.20, contextWindow: 131_000),
        "glm-4.5-thinking": Tier(inputPerMillion: 0.60, outputPerMillion: 2.20, contextWindow: 131_000),
        "glm-5": Tier(inputPerMillion: 0.72, outputPerMillion: 2.30, contextWindow: 203_000),
        "glm-5-thinking": Tier(inputPerMillion: 0.72, outputPerMillion: 2.30, contextWindow: 203_000),
    ]

    /// Returns pricing tier for a model code, case-insensitive with fuzzy matching.
    public static func tier(for modelCode: String) -> Tier? {
        let key = modelCode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = self.tiers[key] { return exact }
        return self.tiers.first { key.contains($0.key) || $0.key.contains(key) }?.value
    }

    /// Estimates cost assuming a 60/40 input/output token split (typical for coding).
    public static func estimateCost(tokens: Int, modelCode: String) -> Double? {
        guard let tier = self.tier(for: modelCode), tokens > 0 else { return nil }
        let inputTokens = Double(tokens) * 0.6
        let outputTokens = Double(tokens) * 0.4
        let inputCost = (inputTokens / 1_000_000) * tier.inputPerMillion
        let outputCost = (outputTokens / 1_000_000) * tier.outputPerMillion
        return inputCost + outputCost
    }
}

// MARK: - Complete snapshot

/// Complete z.ai usage response including all 3 endpoints.
public struct ZaiUsageSnapshot: Sendable {
    public let tokenLimit: ZaiLimitEntry?
    public let timeLimit: ZaiLimitEntry?
    public let planName: String?
    public let modelUsage: ZaiModelUsageSummary?
    public let toolUsage: ZaiToolUsageSummary?
    public let updatedAt: Date

    public init(
        tokenLimit: ZaiLimitEntry?,
        timeLimit: ZaiLimitEntry?,
        planName: String?,
        modelUsage: ZaiModelUsageSummary? = nil,
        toolUsage: ZaiToolUsageSummary? = nil,
        updatedAt: Date)
    {
        self.tokenLimit = tokenLimit
        self.timeLimit = timeLimit
        self.planName = planName
        self.modelUsage = modelUsage
        self.toolUsage = toolUsage
        self.updatedAt = updatedAt
    }

    public var isValid: Bool {
        self.tokenLimit != nil || self.timeLimit != nil
    }
}

extension ZaiUsageSnapshot {
    public func toUsageSnapshot() -> UsageSnapshot {
        let primaryLimit = self.tokenLimit ?? self.timeLimit
        let secondaryLimit = (self.tokenLimit != nil && self.timeLimit != nil) ? self.timeLimit : nil

        let primary = primaryLimit.map { Self.rateWindow(for: $0) } ?? RateWindow(
            usedPercent: 0,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: nil)
        let secondary = secondaryLimit.map { Self.rateWindow(for: $0) }

        let planName = self.planName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let loginMethod = (planName?.isEmpty ?? true) ? nil : planName
        let identity = ProviderIdentitySnapshot(
            providerID: .zai,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: loginMethod)
        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            providerCost: nil,
            zaiUsage: self,
            updatedAt: self.updatedAt,
            identity: identity)
    }

    private static func rateWindow(for limit: ZaiLimitEntry) -> RateWindow {
        RateWindow(
            usedPercent: limit.usedPercent,
            windowMinutes: limit.type == .tokensLimit ? limit.windowMinutes : nil,
            resetsAt: limit.nextResetTime,
            resetDescription: self.resetDescription(for: limit))
    }

    private static func resetDescription(for limit: ZaiLimitEntry) -> String? {
        if let label = limit.windowLabel {
            return label
        }
        if limit.type == .timeLimit {
            return "Monthly"
        }
        return nil
    }
}

// MARK: - Private API response models

private struct ZaiQuotaLimitResponse: Decodable {
    let code: Int
    let msg: String
    let data: ZaiQuotaLimitData
    let success: Bool

    var isSuccess: Bool { self.success && self.code == 200 }
}

private struct ZaiQuotaLimitData: Decodable {
    let limits: [ZaiLimitRaw]
    let planName: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.limits = try container.decode([ZaiLimitRaw].self, forKey: .limits)
        let rawPlan = try [
            container.decodeIfPresent(String.self, forKey: .planName),
            container.decodeIfPresent(String.self, forKey: .plan),
            container.decodeIfPresent(String.self, forKey: .planType),
            container.decodeIfPresent(String.self, forKey: .packageName),
        ].compactMap(\.self).first
        let trimmed = rawPlan?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.planName = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    private enum CodingKeys: String, CodingKey {
        case limits
        case planName
        case plan
        case planType = "plan_type"
        case packageName
    }
}

private struct ZaiLimitRaw: Codable {
    let type: String
    let unit: Int
    let number: Int
    let usage: Int
    let currentValue: Int
    let remaining: Int
    let percentage: Int
    let usageDetails: [ZaiUsageDetail]?
    let nextResetTime: Int?

    func toLimitEntry() -> ZaiLimitEntry? {
        guard let limitType = ZaiLimitType(rawValue: type) else { return nil }
        let limitUnit = ZaiLimitUnit(rawValue: unit) ?? .unknown
        let nextReset = self.nextResetTime.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        return ZaiLimitEntry(
            type: limitType,
            unit: limitUnit,
            number: self.number,
            usage: self.usage,
            currentValue: self.currentValue,
            remaining: self.remaining,
            percentage: Double(self.percentage),
            usageDetails: self.usageDetails ?? [],
            nextResetTime: nextReset)
    }
}

/// Flexible model-usage API response (best-effort decoding).
private struct ZaiModelUsageResponse: Decodable {
    let code: Int?
    let success: Bool?
    let data: ZaiModelUsageData?

    struct ZaiModelUsageData: Decodable {
        let models: [ZaiModelUsageRaw]?
        let totalTokens: Int?
        let totalPrompts: Int?
        let total_tokens: Int?
        let total_prompts: Int?

        var resolvedTotalTokens: Int? { self.totalTokens ?? self.total_tokens }
        var resolvedTotalPrompts: Int? { self.totalPrompts ?? self.total_prompts }
    }

    struct ZaiModelUsageRaw: Decodable {
        let modelCode: String?
        let model_code: String?
        let model: String?
        let tokens: Int?
        let usage: Int?
        let prompts: Int?
        let calls: Int?

        var resolvedModelCode: String? { self.modelCode ?? self.model_code ?? self.model }
        var resolvedTokens: Int { self.tokens ?? self.usage ?? 0 }
        var resolvedPrompts: Int { self.prompts ?? self.calls ?? 0 }
    }
}

/// Flexible tool-usage API response (best-effort decoding).
private struct ZaiToolUsageResponse: Decodable {
    let code: Int?
    let success: Bool?
    let data: ZaiToolUsageData?

    struct ZaiToolUsageData: Decodable {
        let tools: [ZaiToolUsageRaw]?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            var toolEntries: [ZaiToolUsageRaw] = []
            if let tools = try? container.decodeIfPresent([ZaiToolUsageRaw].self, forKey: DynamicKey(stringValue: "tools")!) {
                toolEntries = tools
            } else {
                // Fallback: try top-level keys as tool names with int values
                for key in container.allKeys {
                    if let count = try? container.decode(Int.self, forKey: key) {
                        toolEntries.append(ZaiToolUsageRaw(tool: key.stringValue, name: nil, count: count, usage: nil))
                    }
                }
            }
            self.tools = toolEntries.isEmpty ? nil : toolEntries
        }
    }

    struct ZaiToolUsageRaw: Decodable {
        let tool: String?
        let name: String?
        let count: Int?
        let usage: Int?

        var resolvedName: String? { self.tool ?? self.name }
        var resolvedCount: Int { self.count ?? self.usage ?? 0 }
    }

    struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }
}

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
        let request = self.makeRequest(url: quotaAPIURL, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZaiUsageError.networkError("Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.log.error("z.ai quota API returned \(httpResponse.statusCode): \(errorMessage)")
            throw ZaiUsageError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            Self.log.debug("z.ai quota response: \(jsonString)")
        }

        let apiResponse = try JSONDecoder().decode(ZaiQuotaLimitResponse.self, from: data)
        guard apiResponse.isSuccess else {
            throw ZaiUsageError.apiError(apiResponse.msg)
        }

        var tokenLimit: ZaiLimitEntry?
        var timeLimit: ZaiLimitEntry?
        for limit in apiResponse.data.limits {
            if let entry = limit.toLimitEntry() {
                switch entry.type {
                case .tokensLimit: tokenLimit = entry
                case .timeLimit: timeLimit = entry
                }
            }
        }
        return (tokenLimit, timeLimit, apiResponse.data.planName)
    }

    // MARK: - Model usage endpoint (best-effort)

    private static func fetchModelUsageBestEffort(apiKey: String) async -> ZaiModelUsageSummary? {
        do {
            return try await self.fetchModelUsage(apiKey: apiKey)
        } catch {
            Self.log.info("z.ai model-usage endpoint unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    private static func fetchModelUsage(apiKey: String) async throws -> ZaiModelUsageSummary {
        let (startTime, endTime) = self.rolling24hWindow()
        let urlString = "\(modelUsageAPIURL)?startTime=\(startTime)&endTime=\(endTime)"
        let request = self.makeRequest(url: urlString, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ZaiUsageError.apiError("model-usage endpoint returned non-200")
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            Self.log.debug("z.ai model-usage response: \(jsonString)")
        }

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
            Self.log.info("z.ai tool-usage endpoint unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    private static func fetchToolUsage(apiKey: String) async throws -> ZaiToolUsageSummary {
        let (startTime, endTime) = self.rolling24hWindow()
        let urlString = "\(toolUsageAPIURL)?startTime=\(startTime)&endTime=\(endTime)"
        let request = self.makeRequest(url: urlString, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ZaiUsageError.apiError("tool-usage endpoint returned non-200")
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            Self.log.debug("z.ai tool-usage response: \(jsonString)")
        }

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

    private static func makeRequest(url: String, apiKey: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
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
