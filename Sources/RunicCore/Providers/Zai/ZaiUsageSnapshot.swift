import Foundation

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
