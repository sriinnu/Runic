import Foundation

struct FireworksModelsResponse: Decodable {
    let data: [Model]?

    struct Model: Decodable {
        let id: String?
    }
}

struct FireworksUsageFetcher {
    static let apiURL = URL(string: "https://api.fireworks.ai/inference/v1/models")!

    static func fetchModels(apiKey: String) async throws -> FireworksModelsResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FireworksAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw FireworksAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(FireworksModelsResponse.self, from: data)
    }
}

extension FireworksModelsResponse {
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

enum FireworksAPIError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Fireworks API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Fireworks API returned status code \(statusCode): \(body)"
            }
            return "Fireworks API returned status code \(statusCode)"
        }
    }
}
