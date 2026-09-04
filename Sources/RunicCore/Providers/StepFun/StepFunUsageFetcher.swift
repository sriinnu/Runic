import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetches account/balance info from StepFun's `/v1/accounts` endpoint.
///
/// StepFun's exact response schema is not publicly documented in detail, so
/// this parses defensively with `JSONSerialization` and looks for common
/// balance-shaped keys rather than a strict `Decodable` struct — a schema
/// mismatch degrades to a "connected, balance not recognized" message
/// instead of a hard failure.
public enum StepFunUsageFetcher {
    private static let requestTimeout: TimeInterval = 20
    private static let balanceKeys = [
        "available_balance", "balance", "total_balance", "remaining_balance", "quota", "remaining",
    ]

    public static func fetchAccount(apiKey: String, baseURL: String) async throws -> StepFunAccountSnapshot {
        guard let url = URL(string: "\(baseURL)/v1/accounts") else {
            throw StepFunAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StepFunAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw StepFunAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }

        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let payload = (object?["data"] as? [String: Any]) ?? object ?? [:]
        let balance = Self.findBalance(in: payload)
        return StepFunAccountSnapshot(availableBalance: balance, updatedAt: Date())
    }

    /// Recursively looks (one level deep, since payloads are typically flat or
    /// single-nested) for the first numeric value under a recognized key name.
    private static func findBalance(in payload: [String: Any]) -> Double? {
        for key in self.balanceKeys {
            if let value = payload[key] {
                if let number = value as? Double { return number }
                if let number = value as? Int { return Double(number) }
                if let string = value as? String, let number = Double(string) { return number }
            }
        }
        for value in payload.values {
            if let nested = value as? [String: Any], let found = findBalance(in: nested) {
                return found
            }
        }
        return nil
    }
}

public struct StepFunAccountSnapshot: Sendable {
    public let availableBalance: Double?
    public let updatedAt: Date
}

extension StepFunAccountSnapshot {
    public func toUsageSnapshot(providerID: UsageProvider) -> UsageSnapshot {
        let detail = if let availableBalance {
            "Balance: \(Self.formatAmount(availableBalance))"
        } else {
            "Connected (balance format not recognized — check dashboard)"
        }

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: detail,
                hasKnownLimit: false),
            secondary: nil,
            tertiary: nil,
            updatedAt: self.updatedAt,
            identity: ProviderIdentitySnapshot(
                providerID: providerID,
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: "api-key"))
    }

    private static func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

public enum StepFunAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from StepFun API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "StepFun API returned status code \(statusCode): \(body)"
            }
            return "StepFun API returned status code \(statusCode)"
        }
    }
}
