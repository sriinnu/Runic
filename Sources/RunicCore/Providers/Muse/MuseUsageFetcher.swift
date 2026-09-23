import Foundation

// MARK: - API response models

/// `GET /v1/models`. Decoded leniently: an OpenAI-style `data[]` of `{id}`,
/// with `models[]` / `name` accepted too.
struct MuseModelsResponse: Decodable {
    let data: [Model]?
    let models: [Model]?

    struct Model: Decodable {
        let id: String?
        let name: String?
    }

    var modelNames: [String] {
        ((self.data ?? []) + (self.models ?? [])).compactMap { $0.id ?? $0.name }
    }
}

/// Per-minute rate limits from `x-ratelimit-*` response headers.
struct MuseRateLimits: Equatable {
    let requestLimit: Double?
    let requestRemaining: Double?
    let tokenLimit: Double?
    let tokenRemaining: Double?

    var isEmpty: Bool {
        self.requestLimit == nil && self.tokenLimit == nil
    }

    /// Reads the four `x-ratelimit-*` headers, matching names case-insensitively.
    static func parse(headers: [AnyHashable: Any]) -> MuseRateLimits {
        var lowered: [String: String] = [:]
        for (key, value) in headers {
            guard let name = key as? String else { continue }
            lowered[name.lowercased()] = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func number(_ name: String) -> Double? {
            lowered[name].flatMap(Double.init)
        }
        return MuseRateLimits(
            requestLimit: number("x-ratelimit-limit-requests"),
            requestRemaining: number("x-ratelimit-remaining-requests"),
            tokenLimit: number("x-ratelimit-limit-tokens"),
            tokenRemaining: number("x-ratelimit-remaining-tokens"))
    }

    var requestsWindow: RateWindow? {
        Self.window(limit: self.requestLimit, remaining: self.requestRemaining, unit: "requests", label: "Requests/min")
    }

    var tokensWindow: RateWindow? {
        Self.window(limit: self.tokenLimit, remaining: self.tokenRemaining, unit: "tokens", label: "Tokens/min")
    }

    private static func window(limit: Double?, remaining: Double?, unit: String, label: String) -> RateWindow? {
        guard let limit, limit > 0 else { return nil }
        let left = min(limit, max(0, remaining ?? limit))
        return RateWindow(
            usedPercent: min(100, max(0, (limit - left) / limit * 100)),
            windowMinutes: 1,
            resetsAt: nil,
            resetDescription: "\(Int(left)) of \(Int(limit)) \(unit) left this minute",
            label: label,
            hasKnownLimit: true)
    }
}

struct MuseModelsResult {
    let models: MuseModelsResponse
    let rateLimits: MuseRateLimits
}

// MARK: - Fetcher

enum MuseUsageFetcher {
    static let apiURL = URL(string: "https://api.meta.ai/v1/models")!

    static func fetchModels(apiKey: String) async throws -> MuseModelsResult {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MuseAPIError.invalidResponse
        }
        if let error = MuseAPIError.from(statusCode: httpResponse.statusCode, body: data) {
            throw error
        }
        let models: MuseModelsResponse
        do {
            models = try JSONDecoder().decode(MuseModelsResponse.self, from: data)
        } catch {
            throw MuseAPIError.decodingError
        }
        return MuseModelsResult(
            models: models,
            rateLimits: MuseRateLimits.parse(headers: httpResponse.allHeaderFields))
    }
}

// MARK: - Snapshot conversion

extension MuseModelsResult {
    func toUsageSnapshot(now: Date = Date()) -> UsageSnapshot {
        let names = self.models.modelNames
        var modelsLine = "\(names.count) models available"
        let preview = names.prefix(3).joined(separator: ", ")
        if !preview.isEmpty {
            modelsLine += " (\(preview))"
        }
        let informational = RateWindow(
            usedPercent: 0,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: modelsLine,
            hasKnownLimit: false)

        let requests = self.rateLimits.requestsWindow
        let tokens = self.rateLimits.tokensWindow
        let primary: RateWindow
        let secondary: RateWindow?
        switch (requests, tokens) {
        case let (req?, tok):
            primary = req
            secondary = tok
        case let (nil, tok?):
            primary = tok
            secondary = nil
        case (nil, nil):
            primary = informational
            secondary = nil
        }

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            updatedAt: now,
            identity: nil)
    }
}

// MARK: - Errors

enum MuseAPIError: LocalizedError, Equatable {
    case invalidResponse
    case invalidKey(statusCode: Int)
    case outOfCredits
    case httpError(statusCode: Int)
    case decodingError

    private struct ErrorBody: Decodable {
        struct Detail: Decodable {
            let type: String?
        }

        let error: Detail?
        let type: String?
    }

    /// Maps a non-2xx response to an error; nil for success. A 402, or any
    /// body whose error `type` is `billing_error`, means the account is out
    /// of credits.
    static func from(statusCode: Int, body: Data?) -> MuseAPIError? {
        if (200..<300).contains(statusCode) { return nil }
        let type = body.flatMap { try? JSONDecoder().decode(ErrorBody.self, from: $0) }
            .flatMap { $0.error?.type ?? $0.type }
        if statusCode == 402 || type == "billing_error" { return .outOfCredits }
        if statusCode == 401 || statusCode == 403 { return .invalidKey(statusCode: statusCode) }
        return .httpError(statusCode: statusCode)
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Meta Model API returned an invalid response."
        case let .invalidKey(statusCode):
            "Meta Model API rejected the API key (HTTP \(statusCode)). Check the key at dev.meta.ai."
        case .outOfCredits:
            "Out of Meta Model API credits — add billing at dev.meta.ai."
        case let .httpError(statusCode):
            "Meta Model API request failed (HTTP \(statusCode))."
        case .decodingError:
            "Meta Model API response could not be decoded."
        }
    }
}
