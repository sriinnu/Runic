import Foundation

struct CohereModelsResponse: Decodable {
    let models: [Model]?
    let data: [Model]?

    struct Model: Decodable {
        let id: String?
        let name: String?

        var modelID: String? {
            let candidate = id ?? name
            guard let candidate else { return nil }
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

struct CohereUsageFetcher {
    static let apiURL = URL(string: "https://api.cohere.ai/v1/models")!

    static func fetchModels(apiKey: String) async throws -> CohereModelsResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CohereAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw CohereAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(CohereModelsResponse.self, from: data)
    }
}

extension CohereModelsResponse {
    func toUsageSnapshot() -> UsageSnapshot {
        let records = (self.models ?? []) + (self.data ?? [])
        let models = records.compactMap(\.modelID)
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

enum CohereAPIError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Cohere API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Cohere API returned status code \(statusCode): \(body)"
            }
            return "Cohere API returned status code \(statusCode)"
        }
    }
}
