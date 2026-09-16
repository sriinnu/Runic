import Foundation

/// A prepaid money balance, as a provider's API reports it (Moonshot/Kimi,
/// DeepSeek, OpenRouter, Vercel AI Gateway, StepFun).
///
/// Balance APIs return a snapshot and nothing else: no spend today, no monthly
/// bill, no top-up history. Runic records these readings over time
/// (`BalanceSampleStore`) and derives spend and runway from the drops
/// (`BalanceSpendSummary`).
public struct ProviderBalance: Codable, Sendable, Equatable {
    /// One named part of the balance ("Paid", "Bonus").
    public struct Component: Codable, Sendable, Equatable {
        public let label: String
        public let amount: Double

        public init(label: String, amount: Double) {
            self.label = label
            self.amount = amount
        }
    }

    /// What can still be spent.
    public let available: Double
    /// ISO 4217 code when the provider's platform fixes it ("CNY" on
    /// api.moonshot.cn, "USD" on api.moonshot.ai). Nil when unknown: shown as a
    /// bare number, never a guessed symbol.
    public let currency: String?
    /// Breakdown of `available`, when the API splits it.
    public let components: [Component]
    /// Lifetime spend, when the API reports it directly (OpenRouter, Vercel).
    public let lifetimeSpent: Double?
    /// The provider's own verdict on whether API calls still go through
    /// (DeepSeek `is_available`). Nil when the API doesn't say.
    public let apiCallsAllowed: Bool?
    /// Spend the provider reports directly (OpenRouter's key usage), which beats
    /// deriving it from balance drops. Nil when the API has none.
    public let reportedSpend: ReportedSpend?

    /// Provider-reported spend for calendar periods (UTC on OpenRouter).
    public struct ReportedSpend: Codable, Sendable, Equatable {
        public let today: Double
        public let thisWeek: Double?
        public let thisMonth: Double
        /// What the figures cover when narrower than the account ("this key").
        public let scope: String?

        public init(today: Double, thisWeek: Double?, thisMonth: Double, scope: String?) {
            self.today = today
            self.thisWeek = thisWeek
            self.thisMonth = thisMonth
            self.scope = scope
        }
    }

    public init(
        available: Double,
        currency: String?,
        components: [Component] = [],
        lifetimeSpent: Double? = nil,
        apiCallsAllowed: Bool? = nil,
        reportedSpend: ReportedSpend? = nil)
    {
        self.available = available
        self.currency = currency
        self.components = components
        self.lifetimeSpent = lifetimeSpent
        self.apiCallsAllowed = apiCallsAllowed
        self.reportedSpend = reportedSpend
    }

    /// Paid API calls will fail: the provider says so, or, when it doesn't say,
    /// nothing is left (Moonshot documents that inference stops at a balance of
    /// zero or less; OpenRouter rejects paid requests without credits).
    public var blocksAPICalls: Bool {
        self.apiCallsAllowed.map { !$0 } ?? (self.available <= 0)
    }
}

/// Money formatting for balances: a symbol for the few currencies Runic's
/// providers bill in, the ISO code otherwise, a bare number when unknown.
public enum BalanceFormatter {
    public static func amount(_ value: Double, currency: String?) -> String {
        let number = Self.decimal(value)
        switch currency?.uppercased() {
        case "CNY", "RMB": return "¥\(number)"
        case "USD": return "$\(number)"
        case "EUR": return "€\(number)"
        case let code?: return "\(number) \(code)"
        case nil: return number
        }
    }

    private static func decimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
