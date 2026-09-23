import Foundation

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
