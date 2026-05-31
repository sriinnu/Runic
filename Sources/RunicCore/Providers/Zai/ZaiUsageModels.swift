import Foundation

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
