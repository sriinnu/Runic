import Foundation

/// Usage data fetched from custom provider
public struct UsageData: Sendable {
    public var quota: Double?
    public var used: Double?
    public var remaining: Double?
    public var cost: Double?
    public var resetDate: Date?
    public var tokens: Int?

    public init(
        quota: Double? = nil,
        used: Double? = nil,
        remaining: Double? = nil,
        cost: Double? = nil,
        resetDate: Date? = nil,
        tokens: Int? = nil)
    {
        self.quota = quota
        self.used = used
        self.remaining = remaining
        self.cost = cost
        self.resetDate = resetDate
        self.tokens = tokens
    }

    public func toCustomUsageData() -> CustomUsageData {
        CustomUsageData(
            quota: self.quota,
            used: self.used,
            remaining: self.remaining,
            cost: self.cost,
            resetDate: self.resetDate,
            tokens: self.tokens)
    }
}

/// Balance data fetched from custom provider
public struct BalanceData: Sendable {
    public var balance: Double?
    public var currency: String?

    public init(balance: Double? = nil, currency: String? = nil) {
        self.balance = balance
        self.currency = currency
    }
}
