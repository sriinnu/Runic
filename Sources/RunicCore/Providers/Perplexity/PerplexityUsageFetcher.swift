import Foundation

struct PerplexityModelsResponse: Decodable {
    let data: [Model]?

    struct Model: Decodable {
        let id: String?
    }
}

struct PerplexityUsageFetcher {
    static let apiURL = URL(string: "https://api.perplexity.ai/models")!

    static func fetchModels(apiKey: String) async throws -> PerplexityModelsResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerplexityAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw PerplexityAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(PerplexityModelsResponse.self, from: data)
    }
}

extension PerplexityModelsResponse {
    func toUsageSnapshot() -> UsageSnapshot {
        let models = (self.data ?? []).compactMap(\.id)
        var summary = "Models available: \(models.count)"
        let preview = models.prefix(3).joined(separator: ", ")
        if !preview.isEmpty {
            summary += " (\(preview))"
        }

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: summary),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }
}

enum PerplexityAPIError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Perplexity API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Perplexity API returned status code \(statusCode): \(body)"
            }
            return "Perplexity API returned status code \(statusCode)"
        }
    }
}
