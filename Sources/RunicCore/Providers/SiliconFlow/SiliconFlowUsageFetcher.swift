import Foundation

/// SiliconFlow retired `GET /v1/user/info` (the only balance endpoint) on
/// 2026-08-14 — it now answers 410 `{"code":20092}` — and has named no
/// replacement. `GET /v1/models` is what is left, so the tile reports key health
/// and the model count, like Groq's.
struct SiliconFlowModelsResponse: Decodable {
    let data: [Model]?

    struct Model: Decodable {
        let id: String?
    }
}

enum SiliconFlowUsageFetcher {
    /// Separate platforms: keys do not cross over between `.com` and `.cn`.
    static let apiURL = URL(string: "https://api.siliconflow.com/v1/models")!
    static let apiURLChina = URL(string: "https://api.siliconflow.cn/v1/models")!

    static func fetchModels(apiKey: String, china: Bool = false) async throws -> SiliconFlowModelsResponse {
        var request = URLRequest(url: china ? self.apiURLChina : self.apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await ProviderRequestSession.data(for: request)
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
        guard let decoded = try? JSONDecoder().decode(SiliconFlowModelsResponse.self, from: data) else {
            throw SiliconFlowAPIError.invalidResponse
        }
        return decoded
    }
}

extension SiliconFlowModelsResponse {
    /// `balanceIssue`: why the console balance was not read this refresh. It
    /// replaces the model preview, so the fallback never hides its reason.
    func toUsageSnapshot(balanceIssue: String? = nil) -> UsageSnapshot {
        let models = (self.data ?? []).compactMap(\.id)
        var summary = "Key active · \(models.count) models"
        if let balanceIssue {
            summary += " · No balance: \(balanceIssue)"
        } else {
            let preview = models.prefix(3).joined(separator: ", ")
            if !preview.isEmpty {
                summary += " (\(preview))"
            }
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
