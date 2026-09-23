import Foundation

// MARK: - Parsed reply

/// `GET https://ollama.com/api/usage`. The endpoint is undocumented, so the
/// reply is read through `JSONSerialization` and every field is optional:
/// numbers may arrive as JSON numbers or strings, and per-model request
/// counts live either in `limits.monthly.models[]` (monthly-credit plans) or
/// in a `models` map keyed by model name (legacy plans, top level or inside
/// `limits`).
struct OllamaCloudUsage: Equatable {
    struct ModelRequests: Equatable {
        let name: String
        let requests: Double
    }

    /// Monthly-credit plans: fraction (0–1) of the month's credits used.
    let monthlyUsage: Double?
    /// Legacy plans: fraction (0–1) of the session window used.
    let sessionUsage: Double?
    /// Legacy plans: fraction (0–1) of the weekly window used.
    let weeklyUsage: Double?
    /// Request counts, highest first.
    let models: [ModelRequests]
    /// `activity.cost`, in dollars.
    let cost: Double?

    static func parse(_ data: Data) throws -> OllamaCloudUsage {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw OllamaCloudAPIError.decodingError
        }
        return self.parse(root: root)
    }

    static func parse(root: [String: Any]) -> OllamaCloudUsage {
        let limits = root["limits"] as? [String: Any]
        let monthly = limits?["monthly"] as? [String: Any]
        let session = limits?["session"] as? [String: Any]
        let weekly = limits?["weekly"] as? [String: Any]
        let activity = root["activity"] as? [String: Any]

        let modelSources: [Any?] = [monthly?["models"], limits?["models"], root["models"]]
        let models = modelSources.lazy
            .map { self.modelRequests($0) }
            .first { !$0.isEmpty } ?? []

        return OllamaCloudUsage(
            monthlyUsage: self.number(monthly?["usage"]),
            sessionUsage: self.number(session?["usage"]),
            weeklyUsage: self.number(weekly?["usage"]),
            models: models,
            cost: self.number(activity?["cost"]))
    }

    /// A JSON number or a numeric string ("12.34", "$12.34", "1,234.5").
    /// Booleans are rejected even though `NSNumber` bridges them.
    static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            let double = number.doubleValue
            return double.isFinite ? double : nil
        }
        guard let string = value as? String else { return nil }
        let cleaned = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard let double = Double(cleaned), double.isFinite else { return nil }
        return double
    }

    /// Accepts `[{name, request_count}]` or `{"<name>": {request_count}}`.
    static func modelRequests(_ value: Any?) -> [ModelRequests] {
        var result: [ModelRequests] = []
        if let list = value as? [[String: Any]] {
            for entry in list {
                guard let name = (entry["name"] as? String ?? entry["model"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
                    let count = self.number(entry["request_count"] ?? entry["requests"])
                else { continue }
                result.append(ModelRequests(name: name, requests: count))
            }
        } else if let map = value as? [String: Any] {
            for (name, entry) in map {
                let count = (entry as? [String: Any]).flatMap { self.number($0["request_count"] ?? $0["requests"]) }
                    ?? self.number(entry)
                guard let count, !name.isEmpty else { continue }
                result.append(ModelRequests(name: name, requests: count))
            }
        }
        return result.sorted { lhs, rhs in
            lhs.requests != rhs.requests ? lhs.requests > rhs.requests : lhs.name < rhs.name
        }
    }

    /// "Top: glm-5 (120), qwen3-coder (40)" for the three busiest models.
    var topModelsText: String? {
        let top = self.models.prefix(3).map { "\($0.name) (\(Int($0.requests.rounded())))" }
        return top.isEmpty ? nil : "Top: " + top.joined(separator: ", ")
    }
}

// MARK: - Snapshot conversion

extension OllamaCloudUsage {
    static let monthlyWindowMinutes = 30 * 24 * 60
    static let sessionWindowMinutes = 5 * 60
    static let weeklyWindowMinutes = 7 * 24 * 60

    func toUsageSnapshot(now: Date = Date()) -> UsageSnapshot {
        let topModels = self.topModelsText
        let session = self.sessionUsage.map {
            Self.window(fraction: $0, minutes: Self.sessionWindowMinutes, label: "Session", description: nil)
        }
        let weekly = self.weeklyUsage.map {
            Self.window(fraction: $0, minutes: Self.weeklyWindowMinutes, label: "Weekly", description: nil)
        }

        var primary: RateWindow
        var secondary: RateWindow?
        if let monthly = self.monthlyUsage {
            primary = Self.window(
                fraction: monthly,
                minutes: Self.monthlyWindowMinutes,
                label: "Monthly credits",
                description: topModels)
            secondary = nil
        } else if let first = session ?? weekly {
            primary = first.withDescription(topModels)
            secondary = session == nil ? nil : weekly
        } else {
            primary = RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: ["Signed in · no usage limits reported", topModels]
                    .compactMap(\.self).joined(separator: " · "),
                hasKnownLimit: false)
            secondary = nil
        }

        let providerCost = self.cost.map {
            ProviderCostSnapshot(
                used: $0,
                limit: 0,
                currencyCode: "USD",
                period: "Last 4 weeks",
                resetsAt: nil,
                updatedAt: now)
        }

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            providerCost: providerCost,
            updatedAt: now,
            identity: nil)
    }

    private static func window(fraction: Double, minutes: Int, label: String, description: String?) -> RateWindow {
        RateWindow(
            usedPercent: min(100, max(0, fraction * 100)),
            windowMinutes: minutes,
            resetsAt: nil,
            resetDescription: description,
            label: label,
            hasKnownLimit: true)
    }
}

extension RateWindow {
    fileprivate func withDescription(_ description: String?) -> RateWindow {
        RateWindow(
            usedPercent: self.usedPercent,
            windowMinutes: self.windowMinutes,
            resetsAt: self.resetsAt,
            resetDescription: description,
            label: self.label,
            hasKnownLimit: self.hasKnownLimit)
    }
}

// MARK: - Fetcher

enum OllamaCloudUsageFetcher {
    static let apiURL = URL(string: "https://ollama.com/api/usage")!
    static let shapeFileName = "ollama-cloud-usage-shape.json"

    static func fetchUsage(apiKey: String) async throws -> OllamaCloudUsage {
        var request = URLRequest(url: apiURL)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaCloudAPIError.invalidResponse
        }
        if let error = OllamaCloudAPIError.from(statusCode: httpResponse.statusCode) {
            throw error
        }
        let usage = try OllamaCloudUsage.parse(data)
        self.recordShape(data)
        return usage
    }

    /// Sorted key paths of a reply with every value dropped. Arrays become
    /// `key[]`; the per-model `models` map is keyed by model name, so its
    /// keys collapse to `models.*` rather than being written out.
    static func shapeKeyPaths(of object: Any, prefix: String = "") -> [String] {
        var paths: Set<String> = []
        func walk(_ value: Any, _ path: String) {
            if let dict = value as? [String: Any] {
                let collapse = path == "models" || path.hasSuffix(".models")
                for (key, child) in dict {
                    let childPath = (path.isEmpty ? "" : path + ".") + (collapse ? "*" : key)
                    paths.insert(childPath)
                    walk(child, childPath)
                }
            } else if let array = value as? [Any] {
                let childPath = path + "[]"
                if !path.isEmpty { paths.insert(childPath) }
                for element in array {
                    walk(element, childPath)
                }
            }
        }
        walk(object, prefix)
        return paths.sorted()
    }

    /// Writes the reply's shape (key paths only, never values) to
    /// `~/Library/Application Support/Runic/diagnostics/ollama-cloud-usage-shape.json`,
    /// so a changed undocumented payload can be diagnosed without logging usage.
    static func recordShape(_ data: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return }
        let shape: [String: Any] = [
            "at": ISO8601DateFormatter().string(from: Date()),
            "keyPaths": self.shapeKeyPaths(of: root),
        ]
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Runic/diagnostics", isDirectory: true),
            let json = try? JSONSerialization.data(withJSONObject: shape, options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? json.write(to: directory.appendingPathComponent(self.shapeFileName), options: .atomic)
    }
}

// MARK: - Errors

enum OllamaCloudAPIError: LocalizedError, Equatable {
    case invalidResponse
    case invalidKey(statusCode: Int)
    case limitReached
    case rateLimited
    case httpError(statusCode: Int)
    case decodingError

    /// Maps a non-2xx status to an error; nil for success.
    static func from(statusCode: Int) -> OllamaCloudAPIError? {
        switch statusCode {
        case 200..<300: nil
        case 401, 403: .invalidKey(statusCode: statusCode)
        case 402: .limitReached
        case 429: .rateLimited
        default: .httpError(statusCode: statusCode)
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Ollama Cloud returned an invalid response."
        case let .invalidKey(statusCode):
            "Ollama rejected the API key (HTTP \(statusCode)). Check it at ollama.com/settings/keys."
        case .limitReached:
            "Ollama Cloud usage limit reached — upgrade or wait for the reset."
        case .rateLimited:
            "Ollama Cloud rate limited the usage request — try again shortly."
        case let .httpError(statusCode):
            "Ollama Cloud usage request failed (HTTP \(statusCode))."
        case .decodingError:
            "Ollama Cloud usage response could not be decoded."
        }
    }
}
