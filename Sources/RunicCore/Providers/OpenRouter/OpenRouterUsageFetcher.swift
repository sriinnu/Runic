import Foundation

struct OpenRouterCreditsResponse: Decodable {
    let data: CreditData?
    let credits: Double?

    struct CreditData: Decodable {
        let credits: Double?
    }
}

struct OpenRouterUsageFetcher {
    static let apiURL = URL(string: "https://openrouter.ai/api/v1/credits")!

    static func fetchCredits(apiKey: String) async throws -> OpenRouterCreditsResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OpenRouterAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(OpenRouterCreditsResponse.self, from: data)
    }

    func toUsageSnapshot() -> UsageSnapshot {
        UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }
}

extension OpenRouterCreditsResponse {
    func toUsageSnapshot() -> UsageSnapshot {
        let creditsValue = data?.credits ?? credits ?? 0
        let remainingCredits = max(0, creditsValue)

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Credits: \(String(format: "%.2f", remainingCredits))"),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }

    func toCreditsSnapshot() -> CreditsSnapshot {
        let creditsValue = data?.credits ?? credits ?? 0
        return CreditsSnapshot(
            remaining: creditsValue,
            events: [],
            updatedAt: Date())
    }
}

enum OpenRouterAPIError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from OpenRouter API"
        case let .httpError(statusCode):
            "OpenRouter API returned status code \(statusCode)"
        case .decodingError:
            "Failed to decode OpenRouter API response"
        }
    }
}
