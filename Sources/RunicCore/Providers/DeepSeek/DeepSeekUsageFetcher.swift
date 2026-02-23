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
            Self.parse(self.total_balance) ??
                Self.parse(self.topped_up_balance) ??
                Self.parse(self.granted_balance)
        }

        private static func parse(_ raw: String?) -> Double? {
            guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return nil
            }
            return Double(raw)
        }
    }
}

struct DeepSeekUsageFetcher {
    static let apiURL = URL(string: "https://api.deepseek.com/user/balance")!

    static func fetchBalance(apiKey: String) async throws -> DeepSeekBalanceResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

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

    private var currencyCode: String {
        self.preferredBalanceInfo?.currency?.uppercased() ?? "USD"
    }

    func toUsageSnapshot() -> UsageSnapshot {
        UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: \(String(format: "%.2f", self.remainingBalance)) \(self.currencyCode)"),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }

    func toCreditsSnapshot() -> CreditsSnapshot {
        CreditsSnapshot(
            remaining: self.remainingBalance,
            events: [],
            updatedAt: Date())
    }
}

enum DeepSeekAPIError: LocalizedError, Sendable {
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
