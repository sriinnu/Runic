import Foundation

/// Response from Moonshot's `/v1/users/me/balance` endpoint.
///
/// Shape: `{ "code": 0, "data": { "available_balance": …, "voucher_balance": …,
/// "cash_balance": … }, "scode": "0x0", "status": true }`.
struct KimiBalanceResponse: Decodable {
    let data: Balance?
    let status: Bool?

    struct Balance: Decodable {
        let availableBalance: Double?
        let voucherBalance: Double?
        let cashBalance: Double?

        enum CodingKeys: String, CodingKey {
            case availableBalance = "available_balance"
            case voucherBalance = "voucher_balance"
            case cashBalance = "cash_balance"
        }
    }
}

enum KimiUsageFetcher {
    /// Default international host. Overridable per the user's subscription region.
    static let defaultBaseURL = "https://api.moonshot.ai"
    private static let requestTimeout: TimeInterval = 20

    /// Build the balance URL from an optional user-supplied base URL.
    ///
    /// Accepts hosts with or without a scheme, a trailing slash, or a trailing
    /// `/v1` (for example `https://api.moonshot.cn`, `api.moonshot.cn/v1/`).
    static func balanceURL(baseURL: String?) -> URL? {
        var base = (baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? Self.defaultBaseURL

        if !base.contains("://") {
            base = "https://\(base)"
        }
        while base.hasSuffix("/") {
            base.removeLast()
        }
        if base.lowercased().hasSuffix("/v1") {
            base.removeLast(3)
        }
        // Reject a base that collapsed to just a scheme (e.g. degenerate "/v1/"
        // input) so the caller gets a clean error instead of an empty-host URL.
        guard let url = URL(string: "\(base)/v1/users/me/balance"), url.host?.isEmpty == false else {
            return nil
        }
        return url
    }

    static func fetchBalance(apiKey: String, baseURL: String?) async throws -> KimiBalanceResponse {
        guard let url = balanceURL(baseURL: baseURL) else {
            throw KimiAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KimiAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw KimiAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(KimiBalanceResponse.self, from: data)
    }
}

extension KimiBalanceResponse {
    func toUsageSnapshot() -> UsageSnapshot {
        let available = self.data?.availableBalance
        let summary = if let available {
            "Balance: \(Self.formatAmount(available))"
        } else {
            "Balance unavailable"
        }

        var parts: [String] = []
        if let voucher = self.data?.voucherBalance, voucher > 0 {
            parts.append("Voucher \(Self.formatAmount(voucher))")
        }
        if let cash = self.data?.cashBalance, cash > 0 {
            parts.append("Cash \(Self.formatAmount(cash))")
        }
        let detail = parts.isEmpty ? summary : "\(summary) (\(parts.joined(separator: ", ")))"

        // The balance API exposes no limit, so there is no denominator for a
        // percentage — mark the window as limit-less so UIs show the balance
        // text instead of a fake 0% gauge.
        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: detail,
                hasKnownLimit: false),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }

    /// Render the raw balance number as-is. The Moonshot balance API returns no
    /// currency code (it differs by platform — CNY on .cn, USD on .ai), so we never
    /// invent a symbol; we show exactly what the API returns.
    private static func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

enum KimiAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Kimi API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Kimi API returned status code \(statusCode): \(body)"
            }
            return "Kimi API returned status code \(statusCode)"
        }
    }
}
