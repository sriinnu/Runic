import Foundation

/// A prepaid API credit balance and the grants behind it (Claude Console).
public struct ProviderAPICredits: Equatable, Codable, Sendable {
    public struct Grant: Equatable, Codable, Sendable {
        public let name: String?
        public let remaining: Double
        public let granted: Double?
        public let expiresAt: Date?

        public init(name: String?, remaining: Double, granted: Double?, expiresAt: Date?) {
            self.name = name
            self.remaining = remaining
            self.granted = granted
            self.expiresAt = expiresAt
        }
    }

    public let available: Double
    public let currencyCode: String
    public let grants: [Grant]
    public let fetchedAt: Date

    public init(available: Double, currencyCode: String, grants: [Grant], fetchedAt: Date = Date()) {
        self.available = available
        self.currencyCode = currencyCode
        self.grants = grants
        self.fetchedAt = fetchedAt
    }

    /// The balance at `now`, without grants that expired since the last fetch,
    /// so a card left unrefreshed doesn't keep counting money that is gone. A
    /// grant already expired when fetched isn't taken off: the balance the
    /// reply gave was current then.
    public func available(at now: Date) -> Double {
        let expired = self.grants
            .filter { grant in
                guard let expiresAt = grant.expiresAt else { return false }
                return expiresAt > self.fetchedAt && expiresAt <= now
            }
            .reduce(0) { $0 + $1.remaining }
        return max(0, self.available - expired)
    }

    /// The next grant still holding money that will expire.
    public func nextExpiring(after now: Date) -> Grant? {
        self.grants
            .filter { $0.remaining > 0 && ($0.expiresAt ?? .distantPast) > now }
            .min { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }
}

/// Provider-specific spend/budget snapshot (e.g. Claude "Extra usage" monthly spend vs limit).
public struct ProviderCostSnapshot: Equatable, Codable, Sendable {
    public let used: Double
    public let limit: Double
    public let currencyCode: String
    /// Human-friendly period label (e.g. "Monthly"). Optional; some providers don't expose a period.
    public let period: String?
    /// Optional renewal/reset timestamp for the period.
    public let resetsAt: Date?
    public let updatedAt: Date
    /// Whether the provider has the spend feature switched on (Claude usage
    /// credits). Nil when the provider doesn't say.
    public var isEnabled: Bool?
    /// Prepaid balance behind the spend, when reported (Claude usage credits).
    public var balance: Double?
    /// Monthly API credit the plan includes (Claude Max: $100 or $200), in
    /// USD. Nil when the plan grants none, so nothing is shown.
    public var includedMonthlyCreditUSD: Double?
    /// When the next monthly credit lands — the subscription's next charge.
    public var includedCreditNextGrantAt: Date?
    /// The real API credit balance, when the Console is connected. Wins over
    /// the plan's monthly amount, which only says what the plan includes.
    public var apiCredits: ProviderAPICredits?

    public init(
        used: Double,
        limit: Double,
        currencyCode: String,
        period: String? = nil,
        resetsAt: Date? = nil,
        updatedAt: Date)
    {
        self.used = used
        self.limit = limit
        self.currencyCode = currencyCode
        self.period = period
        self.resetsAt = resetsAt
        self.updatedAt = updatedAt
    }
}
