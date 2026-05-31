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
        // Primary: Standard tokens used (as percentage of allowance, capped reasonably)
        let standardPercent = self.calculateUsagePercent(
            used: self.standardUserTokens,
            allowance: self.standardAllowance)

        let primary = RateWindow(
            usedPercent: standardPercent,
            windowMinutes: nil,
            resetsAt: self.periodEnd,
            resetDescription: self.periodEnd.map { Self.formatResetDate($0) })

        // Secondary: Premium tokens used
        let premiumPercent = self.calculateUsagePercent(
            used: self.premiumUserTokens,
            allowance: self.premiumAllowance)

        let secondary = RateWindow(
            usedPercent: premiumPercent,
            windowMinutes: nil,
            resetsAt: self.periodEnd,
            resetDescription: self.periodEnd.map { Self.formatResetDate($0) })

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

    private func calculateUsagePercent(used: Int64, allowance: Int64) -> Double {
        // Treat very large allowances (> 1 trillion) as unlimited
        let unlimitedThreshold: Int64 = 1_000_000_000_000
        if allowance > unlimitedThreshold {
            // For unlimited, show a token count-based pseudo-percentage (capped at 100%)
            // Use 100M tokens as a reference point for "100%"
            let referenceTokens: Double = 100_000_000
            return min(100, Double(used) / referenceTokens * 100)
        }
        guard allowance > 0 else { return 0 }
        return min(100, Double(used) / Double(allowance) * 100)
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
