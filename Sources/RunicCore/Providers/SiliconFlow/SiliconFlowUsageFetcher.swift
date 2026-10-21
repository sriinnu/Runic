import Foundation

/// `GET /v1/user/info` — account profile with the prepaid balance.
/// Money fields arrive as strings ("88.88"), but tolerate bare numbers too.
struct SiliconFlowBalanceResponse: Decodable {
    let data: Info?

    struct Info: Decodable {
        let balance: Double?
        let chargeBalance: Double?
        let totalBalance: Double?
        let status: String?

        private enum CodingKeys: String, CodingKey {
            case balance, chargeBalance, totalBalance, status
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.balance = Self.amount(c, .balance)
            self.chargeBalance = Self.amount(c, .chargeBalance)
            self.totalBalance = Self.amount(c, .totalBalance)
            self.status = try? c.decodeIfPresent(String.self, forKey: .status)
        }

        private static func amount(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
            if let number = try? c.decodeIfPresent(Double.self, forKey: key) { return number }
            guard let raw = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
            return Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

enum SiliconFlowUsageFetcher {
    static let apiURL = URL(string: "https://api.siliconflow.com/v1/user/info")!

    static func fetchBalance(apiKey: String) async throws -> SiliconFlowBalanceResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SiliconFlowAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw SiliconFlowAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }
        guard let decoded = try? JSONDecoder().decode(SiliconFlowBalanceResponse.self, from: data),
              decoded.data != nil
        else {
            throw SiliconFlowAPIError.invalidResponse
        }
        return decoded
    }
}

extension SiliconFlowBalanceResponse {
    /// `totalBalance` = granted + topped-up; fall back to the parts if absent.
    private var remainingBalance: Double {
        guard let info = self.data else { return 0 }
        return info.totalBalance ?? ((info.balance ?? 0) + (info.chargeBalance ?? 0))
    }

    func toUsageSnapshot() -> UsageSnapshot {
        // No limit is exposed, so mark the window limit-less (see DeepSeek).
        UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: \(String(format: "%.2f", self.remainingBalance)) USD",
                hasKnownLimit: false),
            secondary: nil,
            tertiary: nil,
            balance: ProviderBalance(
                available: self.remainingBalance,
                currency: "USD",
                components: [
                    self.data?.chargeBalance.map { .init(label: "Paid", amount: $0) },
                    self.data?.balance.map { .init(label: "Bonus", amount: $0) },
                ].compactMap(\.self),
                apiCallsAllowed: self.data?.status.map { $0.lowercased() == "normal" }),
            updatedAt: Date(),
            identity: nil)
    }

    func toCreditsSnapshot() -> CreditsSnapshot {
        CreditsSnapshot(remaining: self.remainingBalance, events: [], updatedAt: Date())
    }
}

enum SiliconFlowAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from SiliconFlow API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "SiliconFlow API returned status code \(statusCode): \(body)"
            }
            return "SiliconFlow API returned status code \(statusCode)"
        }
    }
}
