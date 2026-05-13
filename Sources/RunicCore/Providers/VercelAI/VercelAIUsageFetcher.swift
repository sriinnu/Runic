import Foundation

struct VercelAIModelsResponse: Decodable {
    let data: [Model]?

    struct Model: Decodable {
        let id: String?
        let name: String?
        let type: String?
        let contextWindow: Int?
        let maxTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case type
            case contextWindow = "context_window"
            case maxTokens = "max_tokens"
        }
    }
}

struct VercelAICreditsResponse: Decodable {
    let balance: Double
    let totalUsed: Double

    private enum CodingKeys: String, CodingKey {
        case balance
        case totalUsed = "total_used"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.balance = try Self.decodeAmount(container, forKey: .balance)
        self.totalUsed = try Self.decodeAmount(container, forKey: .totalUsed)
    }

    init(balance: Double, totalUsed: Double) {
        self.balance = balance
        self.totalUsed = totalUsed
    }

    var totalCredits: Double {
        max(0, self.balance + self.totalUsed)
    }

    var usedPercent: Double {
        guard self.totalCredits > 0 else { return 0 }
        return min(100, max(0, (self.totalUsed / self.totalCredits) * 100))
    }

    private static func decodeAmount<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K) throws -> Double
    {
        if let double = try? container.decode(Double.self, forKey: key) {
            return double
        }
        if let string = try? container.decode(String.self, forKey: key),
           let double = Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            return double
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Expected a numeric string or number.")
    }
}

enum VercelAIUsageFetcher {
    static let creditsURL = URL(string: "https://ai-gateway.vercel.sh/v1/credits")!
    static let modelsURL = URL(string: "https://ai-gateway.vercel.sh/v1/models")!
    private static let requestTimeout: TimeInterval = 15
    private static let log = RunicLog.logger("vercelai-usage")

    static func fetchAll(apiKey: String) async throws -> (VercelAICreditsResponse, VercelAIModelsResponse?) {
        async let creditsTask = Self.fetchCredits(apiKey: apiKey)
        async let modelsTask = Self.fetchModelsBestEffort()

        let credits = try await creditsTask
        let models = await modelsTask
        return (credits, models)
    }

    static func fetchCredits(apiKey: String) async throws -> VercelAICreditsResponse {
        var request = URLRequest(url: creditsURL)
        request.timeoutInterval = Self.requestTimeout
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VercelAIAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw VercelAIAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: Self.responseBody(data))
        }

        Self.log.debug("Vercel AI credits response: HTTP \(httpResponse.statusCode), \(data.count) bytes")
        return try JSONDecoder().decode(VercelAICreditsResponse.self, from: data)
    }

    static func fetchModels() async throws -> VercelAIModelsResponse {
        var request = URLRequest(url: modelsURL)
        request.timeoutInterval = Self.requestTimeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VercelAIAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw VercelAIAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: Self.responseBody(data))
        }

        Self.log.debug("Vercel AI models response: HTTP \(httpResponse.statusCode), \(data.count) bytes")
        return try JSONDecoder().decode(VercelAIModelsResponse.self, from: data)
    }

    private static func fetchModelsBestEffort() async -> VercelAIModelsResponse? {
        do {
            return try await self.fetchModels()
        } catch {
            self.log.info("Vercel AI models unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    private static func responseBody(_ data: Data) -> String? {
        let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return body?.isEmpty == false ? body : nil
    }
}

extension VercelAICreditsResponse {
    func toUsageSnapshot(models: VercelAIModelsResponse? = nil, tokenSource: String? = nil) -> UsageSnapshot {
        let balance = max(0, self.balance)
        let used = max(0, self.totalUsed)

        var resetDesc = "Balance: \(Self.creditString(balance)) credits"
        if used > 0 {
            resetDesc += " · Used: \(Self.creditString(used))"
        }

        let modelIDs = (models?.data ?? []).compactMap(\.id)
        if !modelIDs.isEmpty {
            resetDesc += " · Models: \(modelIDs.count)"
            let preview = modelIDs.prefix(2).joined(separator: ", ")
            if !preview.isEmpty {
                resetDesc += " (\(preview))"
            }
        }

        let identity = tokenSource.map {
            ProviderIdentitySnapshot(
                providerID: .vercelai,
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: "API key (\($0))")
        }

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: self.usedPercent,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: resetDesc),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: identity)
    }

    func toCreditsSnapshot() -> CreditsSnapshot {
        CreditsSnapshot(
            remaining: max(0, self.balance),
            events: [],
            updatedAt: Date())
    }

    private static func creditString(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

enum VercelAIAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from Vercel AI Gateway API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                "Vercel AI Gateway API returned status code \(statusCode): \(body)"
            } else {
                "Vercel AI Gateway API returned status code \(statusCode)"
            }
        }
    }
}
