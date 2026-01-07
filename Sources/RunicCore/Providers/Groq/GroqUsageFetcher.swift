import Foundation

struct GroqUsageResponse: Decodable {
    let usage: UsageInfo?
    let object: String?

    struct UsageInfo: Decodable {
        let prompt_tokens: Int?
        let completion_tokens: Int?
        let total_tokens: Int?
    }
}

struct GroqUsageFetcher {
    static let apiURL = URL(string: "https://api.groq.com/openai/v1/models")!

    static func fetchUsage(apiKey: String) async throws -> GroqUsageResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GroqAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GroqUsageResponse.self, from: data)
    }
}

extension GroqUsageResponse {
    func toUsageSnapshot() -> UsageSnapshot {
        let totalTokens = usage?.total_tokens ?? 0

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Total Tokens: \(totalTokens)"),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }
}

enum GroqAPIError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from Groq API"
        case let .httpError(statusCode):
            "Groq API returned status code \(statusCode)"
        case .decodingError:
            "Failed to decode Groq API response"
        }
    }
}
