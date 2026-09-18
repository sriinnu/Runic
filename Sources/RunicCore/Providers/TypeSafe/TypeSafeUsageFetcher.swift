import Foundation

struct TypeSafeModelsResponse: Decodable {
    let models: [Model]?

    struct Model: Decodable {
        let name: String?
        let description: String?
        let releaseDate: String?

        enum CodingKeys: String, CodingKey {
            case name
            case description
            case releaseDate = "release_date"
        }
    }
}

enum TypeSafeUsageFetcher {
    static let apiURL = URL(string: "https://api.typesafe.ai/v1/models")!

    static func fetchModels(apiKey: String) async throws -> TypeSafeModelsResponse {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TypeSafeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TypeSafeAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(TypeSafeModelsResponse.self, from: data)
        } catch {
            throw TypeSafeAPIError.decodingError
        }
    }
}

extension TypeSafeModelsResponse {
    func toUsageSnapshot() -> UsageSnapshot {
        let models = (self.models ?? []).compactMap(\.name)
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
                resetDescription: summary,
                hasKnownLimit: false),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }
}

enum TypeSafeAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "TypeSafe returned an invalid response."
        case let .httpError(statusCode):
            statusCode == 401 || statusCode == 403
                ? "TypeSafe rejected the API key (HTTP \(statusCode))."
                : "TypeSafe request failed (HTTP \(statusCode))."
        case .decodingError:
            "TypeSafe response could not be decoded."
        }
    }
}
