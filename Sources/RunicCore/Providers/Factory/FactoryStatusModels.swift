import Foundation
import Silo

#if os(macOS)

// MARK: - Factory API Models

public struct FactoryAuthResponse: Codable, Sendable {
    public let featureFlags: FactoryFeatureFlags?
    public let organization: FactoryOrganization?
}

public struct FactoryFeatureFlags: Codable, Sendable {
    public let flags: [String: Bool]?
    public let configs: [String: AnyCodable]?
}

public struct FactoryOrganization: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let subscription: FactorySubscription?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subscription
    }
}

public struct FactorySubscription: Codable, Sendable {
    public let factoryTier: String?
    public let orbSubscription: FactoryOrbSubscription?
}

public struct FactoryOrbSubscription: Codable, Sendable {
    public let plan: FactoryPlan?
    public let status: String?
}

public struct FactoryPlan: Codable, Sendable {
    public let name: String?
    public let id: String?
}

public struct FactoryUsageResponse: Codable, Sendable {
    public let usage: FactoryUsageData?
    public let source: String?
    public let userId: String?
}

public struct FactoryUsageData: Codable, Sendable {
    public let startDate: Int64?
    public let endDate: Int64?
    public let standard: FactoryTokenUsage?
    public let premium: FactoryTokenUsage?
}

public struct FactoryTokenUsage: Codable, Sendable {
    public let userTokens: Int64?
    public let orgTotalTokensUsed: Int64?
    public let totalAllowance: Int64?
    public let usedRatio: Double?
    public let orgOverageUsed: Int64?
    public let basicAllowance: Int64?
    public let orgOverageLimit: Int64?
}

/// Helper for encoding arbitrary JSON
public struct AnyCodable: Codable, Sendable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            return
        }
        _ = try? container.decode([String: AnyCodable].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

// MARK: - Factory Status Snapshot

public struct FactoryStatusSnapshot: Sendable {
    /// Standard token usage (user)
    public let standardUserTokens: Int64
    /// Standard token usage (org total)
    public let standardOrgTokens: Int64
    /// Standard token allowance
    public let standardAllowance: Int64
    /// Premium token usage (user)
    public let premiumUserTokens: Int64
    /// Premium token usage (org total)
    public let premiumOrgTokens: Int64
    /// Premium token allowance
    public let premiumAllowance: Int64
    /// API-reported fraction of the standard allowance used (0...1)
    public let standardUsedRatio: Double?
    /// API-reported fraction of the premium allowance used (0...1)
    public let premiumUsedRatio: Double?
    /// Billing period start
    public let periodStart: Date?
    /// Billing period end
    public let periodEnd: Date?
    /// Plan name
    public let planName: String?
    /// Factory tier (enterprise, team, etc.)
    public let tier: String?
    /// Organization name
    public let organizationName: String?
    /// User email
    public let accountEmail: String?
    /// User ID
    public let userId: String?
    /// Raw JSON for debugging
    public let rawJSON: String?

    public init(
        standardUserTokens: Int64,
        standardOrgTokens: Int64,
        standardAllowance: Int64,
        premiumUserTokens: Int64,
        premiumOrgTokens: Int64,
        premiumAllowance: Int64,
        standardUsedRatio: Double? = nil,
        premiumUsedRatio: Double? = nil,
        periodStart: Date?,
        periodEnd: Date?,
        planName: String?,
        tier: String?,
        organizationName: String?,
        accountEmail: String?,
        userId: String?,
        rawJSON: String?)
    {
        self.standardUserTokens = standardUserTokens
        self.standardOrgTokens = standardOrgTokens
        self.standardAllowance = standardAllowance
        self.premiumUserTokens = premiumUserTokens
        self.premiumOrgTokens = premiumOrgTokens
        self.premiumAllowance = premiumAllowance
        self.standardUsedRatio = standardUsedRatio
        self.premiumUsedRatio = premiumUsedRatio
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.planName = planName
        self.tier = tier
        self.organizationName = organizationName
        self.accountEmail = accountEmail
        self.userId = userId
        self.rawJSON = rawJSON
    }

    /// Convert to UsageSnapshot for the common provider interface
    public func toUsageSnapshot() -> UsageSnapshot {
        // Primary: Standard tokens used (as percentage of allowance)
        let standardUsage = self.calculateUsage(
            used: self.standardUserTokens,
            allowance: self.standardAllowance,
            usedRatio: self.standardUsedRatio)

        let primary = RateWindow(
            usedPercent: standardUsage.usedPercent,
            windowMinutes: nil,
            resetsAt: self.periodEnd,
            resetDescription: self.periodEnd.map { Self.formatResetDate($0) },
            hasKnownLimit: standardUsage.hasKnownLimit)

        // Secondary: Premium tokens used
        let premiumUsage = self.calculateUsage(
            used: self.premiumUserTokens,
            allowance: self.premiumAllowance,
            usedRatio: self.premiumUsedRatio)

        let secondary = RateWindow(
            usedPercent: premiumUsage.usedPercent,
            windowMinutes: nil,
            resetsAt: self.periodEnd,
            resetDescription: self.periodEnd.map { Self.formatResetDate($0) },
            hasKnownLimit: premiumUsage.hasKnownLimit)

        // Format login method as tier + plan
        let loginMethod: String? = {
            var parts: [String] = []
            if let tier = self.tier, !tier.isEmpty {
                parts.append("Factory \(tier.capitalized)")
            }
            if let plan = self.planName, !plan.isEmpty, !plan.lowercased().contains("factory") {
                parts.append(plan)
            }
            return parts.isEmpty ? nil : parts.joined(separator: " - ")
        }()

        let identity = ProviderIdentitySnapshot(
            providerID: .factory,
            accountEmail: self.accountEmail,
            accountOrganization: self.organizationName,
            loginMethod: loginMethod)
        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            providerCost: nil,
            updatedAt: Date(),
            identity: identity)
    }

    private func calculateUsage(
        used: Int64,
        allowance: Int64,
        usedRatio: Double?) -> (usedPercent: Double, hasKnownLimit: Bool?)
    {
        // Prefer the API's own used ratio whenever it reports one — it is the
        // provider's measurement against the real allowance.
        if let usedRatio {
            return (min(100, max(0, usedRatio * 100)), nil)
        }
        // Treat very large allowances (> 1 trillion) as unlimited. Without a
        // real denominator we don't fabricate a percentage (the old code
        // scaled against an arbitrary 100M-token reference) — mark the window
        // as limit-less instead.
        let unlimitedThreshold: Int64 = 1_000_000_000_000
        if allowance > unlimitedThreshold || allowance <= 0 {
            return (0, false)
        }
        return (min(100, Double(used) / Double(allowance) * 100), nil)
    }

    private static func formatResetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mma"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "Resets " + formatter.string(from: date)
    }
}

// MARK: - Factory Status Probe Error

public enum FactoryStatusProbeError: LocalizedError, Sendable {
    case notLoggedIn
    case networkError(String)
    case parseFailed(String)
    case noSessionCookie

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            "Not logged in to Factory. Please log in via the Runic menu."
        case let .networkError(msg):
            "Factory API error: \(msg)"
        case let .parseFailed(msg):
            "Could not parse Factory usage: \(msg)"
        case .noSessionCookie:
            "No Factory session found. Please log in to app.factory.ai in \(factoryCookieImportOrder.loginHint)."
        }
    }
}

#endif
