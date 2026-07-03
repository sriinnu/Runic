import Foundation

public struct RateWindow: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let windowMinutes: Int?
    public let resetsAt: Date?
    /// Optional textual reset description (used by Claude CLI UI scrape).
    public let resetDescription: String?
    /// Optional label for this quota window (for example, a model name).
    public let label: String?
    /// Whether `usedPercent` is backed by a real denominator.
    ///
    /// `nil`/`true` means the percentage is a real measurement. `false` marks
    /// informational windows (balances or usage counters with no limit) whose
    /// `usedPercent` is a placeholder — UIs must not render a percent gauge
    /// for them or fold them into cross-provider averages.
    public let hasKnownLimit: Bool?

    public init(
        usedPercent: Double,
        windowMinutes: Int?,
        resetsAt: Date?,
        resetDescription: String?,
        label: String? = nil,
        hasKnownLimit: Bool? = nil)
    {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.resetDescription = resetDescription
        self.label = label
        self.hasKnownLimit = hasKnownLimit
    }

    public var remainingPercent: Double {
        max(0, 100 - self.usedPercent)
    }

    /// The percentage to render on a quota gauge, or `nil` when this window
    /// has no real limit (`hasKnownLimit == false`) and no gauge should be
    /// shown at all.
    ///
    /// - Parameter showUsed: `true` returns the used percentage, `false`
    ///   returns the remaining percentage. Both are clamped to `0...100`.
    public func gaugePercent(showUsed: Bool) -> Double? {
        guard self.hasKnownLimit != false else { return nil }
        let used = min(100, max(0, self.usedPercent))
        return showUsed ? used : 100 - used
    }
}

public struct ProviderIdentitySnapshot: Codable, Sendable {
    public let providerID: UsageProvider?
    public let accountEmail: String?
    public let accountOrganization: String?
    public let loginMethod: String?

    public init(
        providerID: UsageProvider?,
        accountEmail: String?,
        accountOrganization: String?,
        loginMethod: String?)
    {
        self.providerID = providerID
        self.accountEmail = accountEmail
        self.accountOrganization = accountOrganization
        self.loginMethod = loginMethod
    }

    public func scoped(to provider: UsageProvider) -> ProviderIdentitySnapshot {
        if self.providerID == provider { return self }
        return ProviderIdentitySnapshot(
            providerID: provider,
            accountEmail: self.accountEmail,
            accountOrganization: self.accountOrganization,
            loginMethod: self.loginMethod)
    }
}

public struct UsageSnapshot: Codable, Sendable {
    public let primary: RateWindow
    public let secondary: RateWindow?
    public let tertiary: RateWindow?
    public let providerCost: ProviderCostSnapshot?
    public let zaiUsage: ZaiUsageSnapshot?
    public let updatedAt: Date
    public let identity: ProviderIdentitySnapshot?

    private enum CodingKeys: String, CodingKey {
        case primary
        case secondary
        case tertiary
        case providerCost
        case updatedAt
        case identity
        case accountEmail
        case accountOrganization
        case loginMethod
    }

    public init(
        primary: RateWindow,
        secondary: RateWindow?,
        tertiary: RateWindow? = nil,
        providerCost: ProviderCostSnapshot? = nil,
        zaiUsage: ZaiUsageSnapshot? = nil,
        updatedAt: Date,
        identity: ProviderIdentitySnapshot? = nil)
    {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.providerCost = providerCost
        self.zaiUsage = zaiUsage
        self.updatedAt = updatedAt
        self.identity = identity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.primary = try container.decode(RateWindow.self, forKey: .primary)
        self.secondary = try container.decodeIfPresent(RateWindow.self, forKey: .secondary)
        self.tertiary = try container.decodeIfPresent(RateWindow.self, forKey: .tertiary)
        self.providerCost = try container.decodeIfPresent(ProviderCostSnapshot.self, forKey: .providerCost)
        self.zaiUsage = nil // Not persisted, fetched fresh each time
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        if let identity = try container.decodeIfPresent(ProviderIdentitySnapshot.self, forKey: .identity) {
            self.identity = identity
        } else {
            let email = try container.decodeIfPresent(String.self, forKey: .accountEmail)
            let organization = try container.decodeIfPresent(String.self, forKey: .accountOrganization)
            let loginMethod = try container.decodeIfPresent(String.self, forKey: .loginMethod)
            if email != nil || organization != nil || loginMethod != nil {
                self.identity = ProviderIdentitySnapshot(
                    providerID: nil,
                    accountEmail: email,
                    accountOrganization: organization,
                    loginMethod: loginMethod)
            } else {
                self.identity = nil
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.primary, forKey: .primary)
        if let secondary = self.secondary {
            try container.encode(secondary, forKey: .secondary)
        } else {
            try container.encodeNil(forKey: .secondary)
        }
        try container.encodeIfPresent(self.tertiary, forKey: .tertiary)
        try container.encodeIfPresent(self.providerCost, forKey: .providerCost)
        try container.encode(self.updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(self.identity, forKey: .identity)
        try container.encodeIfPresent(self.identity?.accountEmail, forKey: .accountEmail)
        try container.encodeIfPresent(self.identity?.accountOrganization, forKey: .accountOrganization)
        try container.encodeIfPresent(self.identity?.loginMethod, forKey: .loginMethod)
    }

    public func identity(for provider: UsageProvider) -> ProviderIdentitySnapshot? {
        guard let identity, identity.providerID == provider else { return nil }
        return identity
    }

    public func accountEmail(for provider: UsageProvider) -> String? {
        self.identity(for: provider)?.accountEmail
    }

    public func accountOrganization(for provider: UsageProvider) -> String? {
        self.identity(for: provider)?.accountOrganization
    }

    public func loginMethod(for provider: UsageProvider) -> String? {
        self.identity(for: provider)?.loginMethod
    }

    public func scoped(to provider: UsageProvider) -> UsageSnapshot {
        guard let identity else { return self }
        let scopedIdentity = identity.scoped(to: provider)
        if scopedIdentity.providerID == identity.providerID { return self }
        return UsageSnapshot(
            primary: self.primary,
            secondary: self.secondary,
            tertiary: self.tertiary,
            providerCost: self.providerCost,
            zaiUsage: self.zaiUsage,
            updatedAt: self.updatedAt,
            identity: scopedIdentity)
    }
}

public struct AccountInfo: Equatable, Sendable {
    public let email: String?
    public let plan: String?

    public init(email: String?, plan: String?) {
        self.email = email
        self.plan = plan
    }
}

public enum UsageError: LocalizedError, Sendable {
    case noSessions
    case noRateLimitsFound
    case decodeFailed

    public var errorDescription: String? {
        switch self {
        case .noSessions:
            "No Codex sessions found yet. Run at least one Codex prompt first."
        case .noRateLimitsFound:
            "Found sessions, but no rate limit events yet."
        case .decodeFailed:
            "Could not parse Codex session log."
        }
    }
}
