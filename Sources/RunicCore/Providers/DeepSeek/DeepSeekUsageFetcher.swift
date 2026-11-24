import Foundation

struct DeepSeekBalanceResponse: Decodable {
    let is_available: Bool?
    let balance_infos: [BalanceInfo]?

    struct BalanceInfo: Decodable {
        let currency: String?
        let total_balance: String?
        let granted_balance: String?
        let topped_up_balance: String?

        var totalBalanceValue: Double? {
            if let total = Self.parse(self.total_balance) {
                return total
            }
            let toppedUp = Self.parse(self.topped_up_balance)
            let granted = Self.parse(self.granted_balance)
            if toppedUp != nil || granted != nil {
                return (toppedUp ?? 0) + (granted ?? 0)
            }
            return nil
        }

        private static func parse(_ raw: String?) -> Double? {
            guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return nil
            }
            return Double(raw)
        }
    }
}

enum DeepSeekUsageFetcher {
    static let apiURL = URL(string: "https://api.deepseek.com/user/balance")!

    static func fetchBalance(apiKey: String) async throws -> DeepSeekBalanceResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await ProviderRequestSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw DeepSeekAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(DeepSeekBalanceResponse.self, from: data)
    }
}

extension DeepSeekBalanceResponse {
    private var preferredBalanceInfo: BalanceInfo? {
        guard let infos = self.balance_infos, !infos.isEmpty else { return nil }
        if let funded = infos.first(where: { ($0.totalBalanceValue ?? 0) > 0 }) {
            return funded
        }
        return infos.first
    }

    private var remainingBalance: Double {
        self.preferredBalanceInfo?.totalBalanceValue ?? 0
    }

    private var currencyCode: String? {
        guard let raw = self.preferredBalanceInfo?.currency?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
            !raw.isEmpty
        else { return nil }
        return raw
    }

    private var additionalCurrencySummary: String? {
        let preferredCurrency = self.currencyCode
        let extras = (self.balance_infos ?? []).compactMap { info -> String? in
            guard let value = info.totalBalanceValue, value > 0 else { return nil }
            let code = info.currency?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard code != preferredCurrency else { return nil }
            let formatted = String(format: "%.2f", value)
            return code.map { "\(formatted) \($0)" } ?? formatted
        }
        return extras.isEmpty ? nil : extras.joined(separator: " · ")
    }

    func toUsageSnapshot() -> UsageSnapshot {
        // The balance API exposes no limit, so there is no denominator for a
        // percentage — mark the window as limit-less so UIs show the balance
        // text instead of a fake 0% gauge. The live balance itself flows to
        // the UI through `toCreditsSnapshot()`.
        let primaryAmount = String(format: "%.2f", self.remainingBalance)
        let baseDescription = self.currencyCode.map { "Balance: \(primaryAmount) \($0)" }
            ?? "Balance: \(primaryAmount)"
        let resetDescription = [baseDescription, self.additionalCurrencySummary]
            .compactMap(\.self)
            .joined(separator: " · ")

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: resetDescription,
                hasKnownLimit: false),
            secondary: nil,
            tertiary: nil,
            balance: ProviderBalance(
                available: self.remainingBalance,
                currency: self.currencyCode,
                components: [
                    Self.amount(self.preferredBalanceInfo?.topped_up_balance).map { .init(label: "Paid", amount: $0) },
                    Self.amount(self.preferredBalanceInfo?.granted_balance).map { .init(label: "Bonus", amount: $0) },
                ].compactMap(\.self),
                apiCallsAllowed: self.is_available),
            updatedAt: Date(),
            identity: nil)
    }

    private static func amount(_ raw: String?) -> Double? {
        raw.flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    func toCreditsSnapshot() -> CreditsSnapshot {
        CreditsSnapshot(
            remaining: self.remainingBalance,
            events: [],
            updatedAt: Date())
    }
}

enum DeepSeekAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from DeepSeek API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "DeepSeek API returned status code \(statusCode): \(body)"
            }
            return "DeepSeek API returned status code \(statusCode)"
        }
    }
}
