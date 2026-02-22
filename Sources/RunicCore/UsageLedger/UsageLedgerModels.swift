import Foundation

public struct UsageLedgerEntry: Sendable, Codable, Hashable {
    public enum Source: String, Sendable, Codable {
        case claudeLog
        case codexLog
        case api
        case cli
        case unknown
    }

    public let provider: UsageProvider
    public let timestamp: Date
    public let sessionID: String?
    public let projectID: String?
    public let projectName: String?
    public let model: String?
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let costUSD: Double?
    public let requestID: String?
    public let messageID: String?
    public let version: String?
    public let source: Source

    public init(
        provider: UsageProvider,
        timestamp: Date,
        sessionID: String?,
        projectID: String?,
        projectName: String? = nil,
        model: String?,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double?,
        requestID: String?,
        messageID: String?,
        version: String?,
        source: Source)
    {
        self.provider = provider
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.projectID = projectID
        self.projectName = projectName
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
        self.requestID = requestID
        self.messageID = messageID
        self.version = version
        self.source = source
    }

    public var totalTokens: Int {
        self.inputTokens + self.outputTokens + self.cacheCreationTokens + self.cacheReadTokens
    }

    public var nonCacheTokens: Int {
        self.inputTokens + self.outputTokens
    }
}

public struct UsageLedgerTotals: Sendable, Codable, Hashable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let costUSD: Double?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double?)
    {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
    }

    public var totalTokens: Int {
        self.inputTokens + self.outputTokens + self.cacheCreationTokens + self.cacheReadTokens
    }

    public var nonCacheTokens: Int {
        self.inputTokens + self.outputTokens
    }
}

public struct UsageLedgerHourlySummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let projectID: String?
    public let hourStart: Date
    public let hourKey: String // "2026-01-31T14:00:00"
    public let totals: UsageLedgerTotals
    public let requestCount: Int

    public init(
        provider: UsageProvider,
        projectID: String?,
        hourStart: Date,
        hourKey: String,
        totals: UsageLedgerTotals,
        requestCount: Int)
    {
        self.provider = provider
        self.projectID = projectID
        self.hourStart = hourStart
        self.hourKey = hourKey
        self.totals = totals
        self.requestCount = requestCount
    }
}

public struct UsageLedgerDailySummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let projectID: String?
    public let dayStart: Date
    public let dayKey: String
    public let totals: UsageLedgerTotals
    public let modelsUsed: [String]

    public init(
        provider: UsageProvider,
        projectID: String?,
        dayStart: Date,
        dayKey: String,
        totals: UsageLedgerTotals,
        modelsUsed: [String])
    {
        self.provider = provider
        self.projectID = projectID
        self.dayStart = dayStart
        self.dayKey = dayKey
        self.totals = totals
        self.modelsUsed = modelsUsed
    }
}

public struct UsageLedgerSessionSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let sessionID: String
    public let projectID: String?
    public let firstActivity: Date
    public let lastActivity: Date
    public let totals: UsageLedgerTotals
    public let modelsUsed: [String]
    public let versions: [String]

    public init(
        provider: UsageProvider,
        sessionID: String,
        projectID: String?,
        firstActivity: Date,
        lastActivity: Date,
        totals: UsageLedgerTotals,
        modelsUsed: [String],
        versions: [String])
    {
        self.provider = provider
        self.sessionID = sessionID
        self.projectID = projectID
        self.firstActivity = firstActivity
        self.lastActivity = lastActivity
        self.totals = totals
        self.modelsUsed = modelsUsed
        self.versions = versions
    }
}

public struct UsageLedgerBlockSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let sessionID: String?
    public let projectID: String?
    public let start: Date
    public let end: Date
    public let isActive: Bool
    public let entryCount: Int
    public let totals: UsageLedgerTotals
    public let tokensPerMinute: Double?
    public let projectedTotalTokens: Int?

    public init(
        provider: UsageProvider,
        sessionID: String?,
        projectID: String?,
        start: Date,
        end: Date,
        isActive: Bool,
        entryCount: Int,
        totals: UsageLedgerTotals,
        tokensPerMinute: Double?,
        projectedTotalTokens: Int?)
    {
        self.provider = provider
        self.sessionID = sessionID
        self.projectID = projectID
        self.start = start
        self.end = end
        self.isActive = isActive
        self.entryCount = entryCount
        self.totals = totals
        self.tokensPerMinute = tokensPerMinute
        self.projectedTotalTokens = projectedTotalTokens
    }
}

public struct UsageLedgerModelSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let projectKey: String?
    public let projectID: String?
    public let projectName: String?
    public let projectNameConfidence: UsageLedgerProjectNameConfidence?
    public let projectNameSource: UsageLedgerProjectNameSource?
    public let projectNameProvenance: String?
    public let model: String
    public let entryCount: Int
    public let totals: UsageLedgerTotals

    public init(
        provider: UsageProvider,
        projectKey: String? = nil,
        projectID: String?,
        projectName: String? = nil,
        projectNameConfidence: UsageLedgerProjectNameConfidence? = nil,
        projectNameSource: UsageLedgerProjectNameSource? = nil,
        projectNameProvenance: String? = nil,
        model: String,
        entryCount: Int,
        totals: UsageLedgerTotals)
    {
        self.provider = provider
        self.projectKey = projectKey
        self.projectID = projectID
        self.projectName = projectName
        self.projectNameConfidence = projectNameConfidence
        self.projectNameSource = projectNameSource
        self.projectNameProvenance = projectNameProvenance
        self.model = model
        self.entryCount = entryCount
        self.totals = totals
    }

    public var displayProjectName: String {
        let trimmedName = self.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, !trimmedName.isEmpty {
            return trimmedName
        }
        if let fallback = UsageLedgerProjectIdentityResolver.fallbackDisplayName(projectID: self.projectID) {
            return fallback
        }
        return "Unknown project"
    }
}

public struct UsageLedgerProjectSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let projectKey: String?
    public let projectID: String?
    public let projectName: String?
    public let projectNameConfidence: UsageLedgerProjectNameConfidence?
    public let projectNameSource: UsageLedgerProjectNameSource?
    public let projectNameProvenance: String?
    public let entryCount: Int
    public let totals: UsageLedgerTotals
    public let modelsUsed: [String]

    public init(
        provider: UsageProvider,
        projectKey: String? = nil,
        projectID: String?,
        projectName: String? = nil,
        projectNameConfidence: UsageLedgerProjectNameConfidence? = nil,
        projectNameSource: UsageLedgerProjectNameSource? = nil,
        projectNameProvenance: String? = nil,
        entryCount: Int,
        totals: UsageLedgerTotals,
        modelsUsed: [String])
    {
        self.provider = provider
        self.projectKey = projectKey
        self.projectID = projectID
        self.projectName = projectName
        self.projectNameConfidence = projectNameConfidence
        self.projectNameSource = projectNameSource
        self.projectNameProvenance = projectNameProvenance
        self.entryCount = entryCount
        self.totals = totals
        self.modelsUsed = modelsUsed
    }

    public var displayProjectName: String {
        let trimmedName = self.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, !trimmedName.isEmpty {
            return trimmedName
        }
        if let fallback = UsageLedgerProjectIdentityResolver.fallbackDisplayName(projectID: self.projectID) {
            return fallback
        }
        return "Unknown project"
    }
}

public struct UsageLedgerSpendForecast: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let projectKey: String?
    public let projectID: String?
    public let projectName: String?
    public let observedDays: Int
    public let observedCostUSD: Double
    public let averageDailyCostUSD: Double
    public let projected30DayCostUSD: Double
    public let projectionDays: Int
    public let budgetLimitUSD: Double?
    public let budgetETAInDays: Double?
    public let budgetWillBreach: Bool

    public init(
        provider: UsageProvider,
        projectKey: String? = nil,
        projectID: String? = nil,
        projectName: String? = nil,
        observedDays: Int,
        observedCostUSD: Double,
        averageDailyCostUSD: Double,
        projected30DayCostUSD: Double,
        projectionDays: Int = 30,
        budgetLimitUSD: Double? = nil,
        budgetETAInDays: Double? = nil,
        budgetWillBreach: Bool = false)
    {
        self.provider = provider
        self.projectKey = projectKey
        self.projectID = projectID
        self.projectName = projectName
        self.observedDays = observedDays
        self.observedCostUSD = observedCostUSD
        self.averageDailyCostUSD = averageDailyCostUSD
        self.projected30DayCostUSD = projected30DayCostUSD
        self.projectionDays = projectionDays
        self.budgetLimitUSD = budgetLimitUSD
        self.budgetETAInDays = budgetETAInDays
        self.budgetWillBreach = budgetWillBreach
    }

    public var projectedAdditionalCostUSD: Double {
        max(0, self.projected30DayCostUSD - self.observedCostUSD)
    }

    public func applyingBudget(monthlyLimitUSD: Double?) -> UsageLedgerSpendForecast {
        guard let monthlyLimitUSD, monthlyLimitUSD > 0 else {
            return UsageLedgerSpendForecast(
                provider: self.provider,
                projectKey: self.projectKey,
                projectID: self.projectID,
                projectName: self.projectName,
                observedDays: self.observedDays,
                observedCostUSD: self.observedCostUSD,
                averageDailyCostUSD: self.averageDailyCostUSD,
                projected30DayCostUSD: self.projected30DayCostUSD,
                projectionDays: self.projectionDays,
                budgetLimitUSD: nil,
                budgetETAInDays: nil,
                budgetWillBreach: false)
        }

        let willBreach = self.projected30DayCostUSD > monthlyLimitUSD
        let etaDays: Double? = {
            guard willBreach, self.averageDailyCostUSD > 0 else { return nil }
            if self.observedCostUSD >= monthlyLimitUSD { return 0 }
            let remainingBudget = monthlyLimitUSD - self.observedCostUSD
            let value = remainingBudget / self.averageDailyCostUSD
            guard value.isFinite else { return nil }
            return max(0, value)
        }()

        return UsageLedgerSpendForecast(
            provider: self.provider,
            projectKey: self.projectKey,
            projectID: self.projectID,
            projectName: self.projectName,
            observedDays: self.observedDays,
            observedCostUSD: self.observedCostUSD,
            averageDailyCostUSD: self.averageDailyCostUSD,
            projected30DayCostUSD: self.projected30DayCostUSD,
            projectionDays: self.projectionDays,
            budgetLimitUSD: monthlyLimitUSD,
            budgetETAInDays: etaDays,
            budgetWillBreach: willBreach)
    }
}
