import Foundation

struct AuggieUsageMetrics: Sendable {
    let requestCount: Int?
    let totalTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?

    func toUsageSnapshot() -> UsageSnapshot {
        var parts: [String] = []
        if let requestCount, requestCount > 0 {
            parts.append("Requests: \(requestCount)")
        }
        if let totalTokens, totalTokens > 0 {
            parts.append("Tokens: \(totalTokens)")
        } else {
            if let inputTokens, inputTokens > 0 {
                parts.append("Input: \(inputTokens)")
            }
            if let outputTokens, outputTokens > 0 {
                parts.append("Output: \(outputTokens)")
            }
        }

        let summary = parts.isEmpty ? "Usage fetched from analytics API." : parts.joined(separator: " · ")
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

struct AuggieUsageFetcher {
    static let baseURL = URL(string: "https://api.augmentcode.com/analytics/v0/daily-usage")!
    private static let requestTimeout: TimeInterval = 20

    static func fetchDailyUsage(apiKey: String) async throws -> AuggieUsageMetrics {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "window", value: "day"),
            URLQueryItem(name: "days", value: "1"),
        ]
        let url = components?.url ?? baseURL

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuggieAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AuggieAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuggieAPIError.decodingError
        }

        let requestCount = Int(self.sumMetric(in: root, keys: ["requests", "request_count", "total_requests"]))
        let inputTokens = Int(self.sumMetric(in: root, keys: ["input_tokens", "prompt_tokens"]))
        let outputTokens = Int(self.sumMetric(in: root, keys: ["output_tokens", "completion_tokens"]))
        let totalTokensValue = self.sumMetric(in: root, keys: ["total_tokens"])
        let totalTokens = totalTokensValue > 0 ? Int(totalTokensValue) : {
            let fallback = inputTokens + outputTokens
            return fallback > 0 ? fallback : 0
        }()

        return AuggieUsageMetrics(
            requestCount: requestCount > 0 ? requestCount : nil,
            totalTokens: totalTokens > 0 ? totalTokens : nil,
            inputTokens: inputTokens > 0 ? inputTokens : nil,
            outputTokens: outputTokens > 0 ? outputTokens : nil)
    }

    private static func sumMetric(in value: Any, keys: Set<String>) -> Double {
        var total: Double = 0

        if let dict = value as? [String: Any] {
            for (key, child) in dict {
                let normalizedKey = key.lowercased()
                if keys.contains(normalizedKey), let metric = self.number(from: child) {
                    total += metric
                }
                total += self.sumMetric(in: child, keys: keys)
            }
            return total
        }

        if let list = value as? [Any] {
            for child in list {
                total += self.sumMetric(in: child, keys: keys)
            }
        }

        return total
    }

    private static func number(from value: Any) -> Double? {
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        if let value = value as? String {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

enum AuggieAPIError: LocalizedError, Sendable {
    case invalidResponse
    case decodingError
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Auggie API"
        case .decodingError:
            return "Failed to decode Auggie API response"
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Auggie API returned status code \(statusCode): \(body)"
            }
            return "Auggie API returned status code \(statusCode)"
        }
    }
}
