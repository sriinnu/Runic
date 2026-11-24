import Foundation

/// Complete z.ai usage response including all 3 endpoints.
public struct ZaiUsageSnapshot: Sendable {
    public let tokenLimit: ZaiLimitEntry?
    public let timeLimit: ZaiLimitEntry?
    public let extraLimits: [ZaiLimitEntry]
    public let planName: String?
    public let modelUsage: ZaiModelUsageSummary?
    public let toolUsage: ZaiToolUsageSummary?
    public let updatedAt: Date

    public init(
        tokenLimit: ZaiLimitEntry?,
        timeLimit: ZaiLimitEntry?,
        extraLimits: [ZaiLimitEntry] = [],
        planName: String?,
        modelUsage: ZaiModelUsageSummary? = nil,
        toolUsage: ZaiToolUsageSummary? = nil,
        updatedAt: Date)
    {
        self.tokenLimit = tokenLimit
        self.timeLimit = timeLimit
        self.extraLimits = extraLimits
        self.planName = planName
        self.modelUsage = modelUsage
        self.toolUsage = toolUsage
        self.updatedAt = updatedAt
    }

    public var isValid: Bool {
        self.tokenLimit != nil || self.timeLimit != nil || !self.extraLimits.isEmpty
    }
}

extension ZaiUsageSnapshot {
    public func toUsageSnapshot(providerID: UsageProvider = .zai) -> UsageSnapshot {
        let primaryLimit = self.tokenLimit ?? self.timeLimit
        let secondaryLimit = (self.tokenLimit != nil && self.timeLimit != nil) ? self.timeLimit : nil

        let primary = primaryLimit.map { Self.rateWindow(for: $0) } ?? .noLimitsReported
        let secondary = secondaryLimit.map { Self.rateWindow(for: $0) }
        let extraWindows = self.extraLimits.map { Self.rateWindow(for: $0) }
        let tertiary = extraWindows.first
        let additional = extraWindows.count > 1 ? Array(extraWindows.dropFirst()) : nil

        let planName = self.planName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let loginMethod = (planName?.isEmpty ?? true) ? nil : planName
        let identity = ProviderIdentitySnapshot(
            providerID: providerID,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: loginMethod)
        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            additionalWindows: additional,
            providerCost: nil,
            zaiUsage: self,
            updatedAt: self.updatedAt,
            identity: identity)
    }

    private static func rateWindow(for limit: ZaiLimitEntry) -> RateWindow {
        RateWindow(
            usedPercent: limit.usedPercent,
            windowMinutes: limit.windowMinutes,
            resetsAt: limit.nextResetTime,
            resetDescription: self.resetDescription(for: limit),
            label: self.windowLabel(for: limit),
            hasKnownLimit: true)
    }

    private static func windowLabel(for limit: ZaiLimitEntry) -> String {
        switch limit.type {
        case .timeLimit:
            return "MCP"
        case .tokensLimit:
            guard let minutes = limit.windowMinutes else { return "Tokens" }
            if minutes == 300 { return "5h Tokens" }
            if minutes >= 6 * 24 * 60, minutes <= 8 * 24 * 60 { return "Weekly Tokens" }
            if let desc = limit.windowDescription { return "\(desc) Tokens" }
            return "Tokens"
        }
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
