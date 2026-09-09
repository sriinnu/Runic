import Foundation

/// A banked, manually-redeemable limit reset — the "you have 2 resets"
/// allowance some providers grant on top of the automatic window cycle.
/// Distinct from a window's `resetsAt`: that is when the meter flips on its
/// own; this is a credit the user can spend to flip it early.
public struct UsageResetCredit: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    /// Provider's own name for the credit ("Full reset").
    public let title: String?
    /// Provider status string ("available", "redeemed", "expired"...).
    public let status: String
    public let grantedAt: Date?
    /// When the credit stops being usable. Nil when the provider grants it
    /// without an expiry.
    public let expiresAt: Date?
    /// Provider-specific kind ("codex_rate_limits").
    public let resetType: String?

    public init(
        id: String,
        title: String? = nil,
        status: String,
        grantedAt: Date? = nil,
        expiresAt: Date? = nil,
        resetType: String? = nil)
    {
        self.id = id
        self.title = title
        self.status = status
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.resetType = resetType
    }

    public func isAvailable(now: Date = .init()) -> Bool {
        guard self.status.lowercased() == "available" else { return false }
        if let expiresAt, expiresAt <= now { return false }
        return true
    }
}

/// Reset credits for one provider: the count the provider reports plus, when
/// it lists them, each credit with its expiry.
public struct UsageResetCredits: Codable, Sendable, Hashable {
    /// Count reported by the provider's summary. Authoritative even when the
    /// detailed list could not be fetched.
    public let availableCount: Int
    public let credits: [UsageResetCredit]

    public init(availableCount: Int, credits: [UsageResetCredit] = []) {
        self.availableCount = max(0, availableCount)
        self.credits = credits
    }

    /// Credits still usable right now, soonest expiry first.
    public func available(now: Date = .init()) -> [UsageResetCredit] {
        self.credits
            .filter { $0.isAvailable(now: now) }
            .sorted { lhs, rhs in
                switch (lhs.expiresAt, rhs.expiresAt) {
                case let (l?, r?): l < r
                case (nil, _?): false
                case (_?, nil): true
                case (nil, nil): lhs.id < rhs.id
                }
            }
    }

    /// The first expiry among usable credits — the deadline that matters.
    public func nearestExpiry(now: Date = .init()) -> Date? {
        self.available(now: now).compactMap(\.expiresAt).min()
    }

    /// The last expiry — "usable until" for the whole bank.
    public func latestExpiry(now: Date = .init()) -> Date? {
        self.available(now: now).compactMap(\.expiresAt).max()
    }

    public var hasAny: Bool {
        self.availableCount > 0
    }
}
