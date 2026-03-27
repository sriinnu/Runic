import Foundation

struct AzureOpenAIDeploymentsResponse: Decodable {
    struct Deployment: Decodable {
        let id: String?
        let model: String?
        let status: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case model
            case modelName
            case status
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let id = try container.decodeIfPresent(String.self, forKey: .id) {
                self.id = id
            } else {
                self.id = try container.decodeIfPresent(String.self, forKey: .name)
            }
            if let model = try container.decodeIfPresent(String.self, forKey: .model) {
                self.model = model
            } else {
                self.model = try container.decodeIfPresent(String.self, forKey: .modelName)
            }
            self.status = try container.decodeIfPresent(String.self, forKey: .status)
        }
    }

    let deployments: [Deployment]

    enum CodingKeys: String, CodingKey {
        case data
        case value
    }

    init(deployments: [Deployment]) {
        self.deployments = deployments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let deployments = try container.decodeIfPresent([Deployment].self, forKey: .data) {
            self.deployments = deployments
            return
        }
        if let deployments = try container.decodeIfPresent([Deployment].self, forKey: .value) {
            self.deployments = deployments
            return
        }
        self.deployments = []
    }
}

struct AzureUsageFetcher {
    static let defaultAPIVersion = "2024-10-21"

    static func fetchDeployments(
        endpoint: String,
        apiKey: String,
        apiVersion: String) async throws -> AzureOpenAIDeploymentsResponse
    {
        guard let url = self.deploymentsURL(endpoint: endpoint, apiVersion: apiVersion) else {
            throw AzureAPIError.invalidEndpoint(endpoint)
        }

        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AzureAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(AzureOpenAIDeploymentsResponse.self, from: data)
    }

    private static func deploymentsURL(endpoint: String, apiVersion: String) -> URL? {
        guard var normalized = self.cleaned(endpoint), !normalized.isEmpty else { return nil }
        if !normalized.contains("://") {
            normalized = "https://\(normalized)"
        }
        // Enforce HTTPS — reject http:// to prevent cleartext token leakage.
        guard normalized.lowercased().hasPrefix("https://") else { return nil }
        guard let baseURL = URL(string: normalized),
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.isEmpty {
            components.path = "/openai/deployments"
        } else {
            components.path = "/\(trimmedPath)/openai/deployments"
        }

        var items = components.queryItems ?? []
        items.removeAll { $0.name.caseInsensitiveCompare("api-version") == .orderedSame }
        items.append(URLQueryItem(name: "api-version", value: apiVersion))
        components.queryItems = items
        return components.url
    }

    private static func cleaned(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

extension AzureOpenAIDeploymentsResponse {
    func toUsageSnapshot(highlightedDeployment: String?) -> UsageSnapshot {
        let deploymentCount = self.deployments.count
        let uniqueModels = Self.uniqueOrdered(self.deployments.compactMap(\.model))
        let modelPreview = uniqueModels.prefix(3).joined(separator: ", ")

        var summaryParts = ["Deployments: \(deploymentCount)"]
        if !modelPreview.isEmpty {
            summaryParts.append("models \(modelPreview)")
        }
        if let highlightedDeployment,
           !highlightedDeployment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            summaryParts.append("target \(highlightedDeployment)")
        }
        let summary = summaryParts.joined(separator: " • ")

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: summary,
                label: "Deployments"),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }

    private static func uniqueOrdered(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            ordered.append(trimmed)
        }
        return ordered
    }
}

enum AzureAPIError: LocalizedError {
    case invalidEndpoint(String)
    case invalidResponse
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case let .invalidEndpoint(endpoint):
            return "Invalid Azure OpenAI endpoint: \(endpoint)"
        case .invalidResponse:
            return "Invalid response from Azure OpenAI API"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Azure OpenAI API returned status code \(statusCode): \(body)"
            }
            return "Azure OpenAI API returned status code \(statusCode)"
        }
    }
}
