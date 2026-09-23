import Foundation

/// Money as Claude's APIs send it: `{amount_minor, currency, exponent}`, or
/// occasionally a bare number already in major units.
struct ClaudeMoney: Decodable, Equatable {
    let value: Double
    let currency: String?

    private enum CodingKeys: String, CodingKey {
        case amountMinor = "amount_minor"
        case currency
        case exponent
    }

    init(value: Double, currency: String?) {
        self.value = value
        self.currency = currency
    }

    init(from decoder: Decoder) throws {
        if let number = try? decoder.singleValueContainer().decode(Double.self) {
            self.init(value: number, currency: nil)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let minor = try container.decode(Double.self, forKey: .amountMinor)
        let exponent = try container.decodeIfPresent(Int.self, forKey: .exponent) ?? 2
        try self.init(
            value: minor / pow(10, Double(exponent)),
            currency: container.decodeIfPresent(String.self, forKey: .currency))
    }
}

/// The `spend` block of Claude's usage reply: usage credits, which cover you
/// after a plan limit is hit. Replaces the older `extra_usage` block.
struct OAuthSpend: Decodable, Equatable {
    let used: ClaudeMoney?
    let limit: ClaudeMoney?
    let balance: ClaudeMoney?
    let enabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case used
        case limit
        case balance
        case enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Each field on its own: one unexpected shape must not drop the rest.
        self.used = try? container.decodeIfPresent(ClaudeMoney.self, forKey: .used)
        self.limit = try? container.decodeIfPresent(ClaudeMoney.self, forKey: .limit)
        self.balance = try? container.decodeIfPresent(ClaudeMoney.self, forKey: .balance)
        self.enabled = try? container.decodeIfPresent(Bool.self, forKey: .enabled)
    }

    var costSnapshot: ProviderCostSnapshot? {
        guard self.enabled != nil || self.used != nil || self.balance != nil else { return nil }
        let currency = self.used?.currency ?? self.limit?.currency ?? self.balance?.currency ?? "USD"
        var cost = ProviderCostSnapshot(
            used: self.used?.value ?? 0,
            limit: self.limit?.value ?? 0,
            currencyCode: currency,
            period: "Monthly",
            resetsAt: nil,
            updatedAt: Date())
        cost.isEnabled = self.enabled
        cost.balance = self.balance?.value
        return cost
    }
}
