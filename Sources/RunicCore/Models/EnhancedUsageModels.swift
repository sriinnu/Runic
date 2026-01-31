// Enhanced Usage Models for Multi-Platform Runic
// Tracks subscription types, model usage, projects, and reset timing

import Foundation

// MARK: - User Account Type

/// Distinguishes between usage-based and subscription-based users
public enum AccountType: String, Codable, Sendable {
    case usageBased = "usage_based"
    case subscription = "subscription"
    case freeTier = "free_tier"
    case enterprise = "enterprise"
    case unknown = "unknown"
}

// MARK: - Usage Reset Information

/// Tracks when usage limits reset
public struct UsageResetInfo: Codable, Sendable, Hashable {
    public let resetType: ResetType
    public let resetAt: Date?
    public let windowDuration: TimeInterval? // in seconds
    public let resetsAutomatically: Bool

    public enum ResetType: String, Codable, Sendable {
        case hourly = "hourly"
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case sessionBased = "session" // 5-hour windows, etc.
        case manual = "manual"
        case never = "never"
    }

    public init(
        resetType: ResetType,
        resetAt: Date? = nil,
        windowDuration: TimeInterval? = nil,
        resetsAutomatically: Bool = true
    ) {
        self.resetType = resetType
        self.resetAt = resetAt
        self.windowDuration = windowDuration
        self.resetsAutomatically = resetsAutomatically
    }

    /// Time remaining until reset
    public var timeUntilReset: TimeInterval? {
        guard let resetAt else { return nil }
        return resetAt.timeIntervalSinceNow
    }

    /// Human-readable reset description
    public var resetDescription: String {
        if let resetAt, let remaining = timeUntilReset, remaining > 0 {
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)

            if hours > 24 {
                let days = hours / 24
                return "Resets in \(days)d"
            } else if hours > 0 {
                return "Resets in \(hours)h \(minutes)m"
            } else {
                return "Resets in \(minutes)m"
            }
        }

        switch resetType {
        case .hourly: return "Resets every hour"
        case .daily: return "Resets daily"
        case .weekly: return "Resets weekly"
        case .monthly: return "Resets monthly"
        case .sessionBased: return "Session-based reset"
        case .manual: return "Manual reset required"
        case .never: return "No reset"
        }
    }
}

// MARK: - Model/Agent Tracking

/// Tracks which AI model/agent was used
public struct ModelUsageInfo: Codable, Sendable, Hashable {
    public let modelName: String
    public let modelFamily: ModelFamily
    public let version: String?
    public let tier: ModelTier

    public enum ModelFamily: String, Codable, Sendable {
        case gpt4 = "gpt-4"
        case gpt35 = "gpt-3.5"
        case claude3 = "claude-3"
        case claude4 = "claude-4"
        case gemini = "gemini"
        case codex = "codex"
        case other = "other"
    }

    public enum ModelTier: String, Codable, Sendable {
        case opus = "opus"          // Highest tier
        case sonnet = "sonnet"      // Mid tier
        case haiku = "haiku"        // Fast/cheap tier
        case turbo = "turbo"
        case standard = "standard"
        case unknown = "unknown"
    }

    public init(
        modelName: String,
        modelFamily: ModelFamily = .other,
        version: String? = nil,
        tier: ModelTier = .unknown
    ) {
        self.modelName = modelName
        self.modelFamily = modelFamily
        self.version = version
        self.tier = tier
    }

    public var displayName: String {
        if let version {
            return "\(modelName) (\(version))"
        }
        return modelName
    }
}

// MARK: - Project Association

/// Associates usage with a specific project or workspace
public struct ProjectInfo: Codable, Sendable, Hashable {
    public let projectID: String
    public let projectName: String?
    public let workspacePath: String?
    public let repository: String?
    public let tags: [String]

    public init(
        projectID: String,
        projectName: String? = nil,
        workspacePath: String? = nil,
        repository: String? = nil,
        tags: [String] = []
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.workspacePath = workspacePath
        self.repository = repository
        self.tags = tags
    }

    public var displayName: String {
        projectName ?? projectID
    }
}

// MARK: - Enhanced Usage Snapshot

/// Extended usage snapshot with detailed tracking
public struct EnhancedUsageSnapshot: Codable, Sendable {
    // Core usage data (existing)
    public let provider: UsageProvider
    public let primary: RateWindow
    public let secondary: RateWindow?
    public let tertiary: RateWindow?

    // Account information
    public let accountType: AccountType
    public let accountEmail: String?
    public let accountOrganization: String?

    // Reset tracking
    public let primaryReset: UsageResetInfo?
    public let secondaryReset: UsageResetInfo?

    // Model/agent tracking
    public let recentModels: [ModelUsageInfo]
    public let primaryModel: ModelUsageInfo?

    // Project tracking
    public let activeProject: ProjectInfo?
    public let recentProjects: [ProjectInfo]

    // Session tracking
    public let sessionID: String?
    public let sessionStartedAt: Date?

    // Token usage breakdown
    public let tokenUsage: DetailedTokenUsage?

    // Cost information
    public let estimatedCost: Double?
    public let costCurrency: String

    // Metadata
    public let updatedAt: Date
    public let fetchSource: String // "oauth", "web", "cli"

    public init(
        provider: UsageProvider,
        primary: RateWindow,
        secondary: RateWindow? = nil,
        tertiary: RateWindow? = nil,
        accountType: AccountType = .unknown,
        accountEmail: String? = nil,
        accountOrganization: String? = nil,
        primaryReset: UsageResetInfo? = nil,
        secondaryReset: UsageResetInfo? = nil,
        recentModels: [ModelUsageInfo] = [],
        primaryModel: ModelUsageInfo? = nil,
        activeProject: ProjectInfo? = nil,
        recentProjects: [ProjectInfo] = [],
        sessionID: String? = nil,
        sessionStartedAt: Date? = nil,
        tokenUsage: DetailedTokenUsage? = nil,
        estimatedCost: Double? = nil,
        costCurrency: String = "USD",
        updatedAt: Date = Date(),
        fetchSource: String = "unknown"
    ) {
        self.provider = provider
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.accountType = accountType
        self.accountEmail = accountEmail
        self.accountOrganization = accountOrganization
        self.primaryReset = primaryReset
        self.secondaryReset = secondaryReset
        self.recentModels = recentModels
        self.primaryModel = primaryModel
        self.activeProject = activeProject
        self.recentProjects = recentProjects
        self.sessionID = sessionID
        self.sessionStartedAt = sessionStartedAt
        self.tokenUsage = tokenUsage
        self.estimatedCost = estimatedCost
        self.costCurrency = costCurrency
        self.updatedAt = updatedAt
        self.fetchSource = fetchSource
    }

    /// Convert from legacy UsageSnapshot
    public init(from legacy: UsageSnapshot, provider: UsageProvider) {
        self.init(
            provider: provider,
            primary: legacy.primary,
            secondary: legacy.secondary,
            tertiary: legacy.tertiary,
            accountEmail: legacy.identity?.accountEmail,
            accountOrganization: legacy.identity?.accountOrganization,
            updatedAt: legacy.updatedAt
        )
    }
}

// MARK: - Detailed Token Usage

/// Breakdown of token usage by category
public struct DetailedTokenUsage: Codable, Sendable, Hashable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let totalTokens: Int

    // Per-model breakdown
    public let modelBreakdown: [String: Int] // modelName -> token count

    // Per-project breakdown
    public let projectBreakdown: [String: Int] // projectID -> token count

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0,
        modelBreakdown: [String: Int] = [:],
        projectBreakdown: [String: Int] = [:]
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.totalTokens = inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
        self.modelBreakdown = modelBreakdown
        self.projectBreakdown = projectBreakdown
    }
}

// MARK: - Usage Alert

/// Proactive alerts for nearing limits
public struct UsageAlert: Codable, Sendable, Identifiable {
    public let id: String
    public let provider: UsageProvider
    public let severity: Severity
    public let title: String
    public let message: String
    public let threshold: Double // Percentage that triggered alert
    public let currentUsage: Double
    public let estimatedTimeToLimit: TimeInterval?
    public let recommendation: String
    public let createdAt: Date

    public enum Severity: String, Codable, Sendable {
        case info = "info"
        case warning = "warning"
        case critical = "critical"
        case urgent = "urgent"
    }

    public init(
        id: String = UUID().uuidString,
        provider: UsageProvider,
        severity: Severity,
        title: String,
        message: String,
        threshold: Double,
        currentUsage: Double,
        estimatedTimeToLimit: TimeInterval? = nil,
        recommendation: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.provider = provider
        self.severity = severity
        self.title = title
        self.message = message
        self.threshold = threshold
        self.currentUsage = currentUsage
        self.estimatedTimeToLimit = estimatedTimeToLimit
        self.recommendation = recommendation
        self.createdAt = createdAt
    }
}

// MARK: - Cross-Platform Sync

/// Sync state across devices
public struct SyncState: Codable, Sendable {
    public let deviceID: String
    public let deviceName: String
    public let platform: Platform
    public let lastSync: Date
    public let snapshots: [String: EnhancedUsageSnapshot] // providerID -> snapshot

    public enum Platform: String, Codable, Sendable {
        case macOS = "macos"
        case iOS = "ios"
        case android = "android"
        case windows = "windows"
        case cli = "cli"
    }

    public init(
        deviceID: String = UUID().uuidString,
        deviceName: String,
        platform: Platform,
        lastSync: Date = Date(),
        snapshots: [String: EnhancedUsageSnapshot] = [:]
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.platform = platform
        self.lastSync = lastSync
        self.snapshots = snapshots
    }
}
