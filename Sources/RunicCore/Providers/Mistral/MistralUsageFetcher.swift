import Foundation

struct MistralModelsResponse: Decodable {
    let data: [Model]?

    struct Model: Decodable {
        let id: String?
    }
}

struct MistralUsageFetcher {
    static let apiURL = URL(string: "https://api.mistral.ai/v1/models")!

    static func fetchModels(apiKey: String) async throws -> MistralModelsResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MistralAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw MistralAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(MistralModelsResponse.self, from: data)
    }
}

extension MistralModelsResponse {
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

enum MistralAPIError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Mistral API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Mistral API returned status code \(statusCode): \(body)"
            }
            return "Mistral API returned status code \(statusCode)"
        }
    }
}
