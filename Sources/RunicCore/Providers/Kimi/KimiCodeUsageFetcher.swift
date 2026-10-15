import Foundation

/// Kimi Code (the Kimi membership / "Kimi for Coding" subscription) plan usage.
///
/// A subscription key is not a Moonshot Open Platform key: `api.moonshot.cn` and
/// `api.moonshot.ai` reject it on `/v1/users/me/balance`, so a subscriber saw no
/// data at all. Kimi's own CLI reads plan usage from `GET {base}/usages` on the
/// Kimi Code platform (`https://api.kimi.com/coding/v1`, overridable with
/// `KIMI_CODE_BASE_URL`, same as kimi-cli). Shape:
///
/// ```json
/// { "usage":  { "limit": "2048", "used": "214", "remaining": "1834",
///               "resetTime": "2026-01-09T15:23:13.716839300Z" },
///   "limits": [ { "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
///                 "detail": { "limit": "200", "used": "139", "remaining": "61",
///                             "resetTime": "2026-01-06T13:33:02.717479433Z" } } ],
///   "usages": { "limit_5h": { "used_ratio": 0.1 },
///               "limit_month_total": { "used_ratio": 0.0338, "reset_time": "2026-10-15T07:49:10Z" } } }
/// ```
///
/// Numbers arrive as strings or numbers; `usages` is newer and may appear
/// instead of, or alongside, `usage`/`limits`. Since 2026-10 the monthly pool
/// also comes as `limit_month_code` (same ratio as `limit_month_total`), and
/// new plans carry no weekly `usage` block at all. Parsing is defensive.
///
/// Kimi runs two hosts for the plan API: `api.kimi.com` (China-side) and
/// `api.kimi.ai` (overseas). Both serve `/coding/v1/usages` for the same key.
enum KimiCodeUsageFetcher {
    static let defaultBaseURL = "https://api.kimi.com/coding/v1"
    private static let requestTimeout: TimeInterval = 20

    /// True when the configured Kimi base URL points at the Kimi Code plan
    /// platform (`api.kimi.com`, `api.kimi.ai`) rather than the Moonshot Open
    /// Platform (`api.moonshot.ai` / `.cn`). The plan platform serves no
    /// balance route — `/v1/users/me/balance` 404s there — so a caller should
    /// go straight to plan usage. Exact API hosts only: `www.kimi.com` is the
    /// web app and a pasted console URL must not be sent a key.
    static func isKimiCodeHost(_ baseURL: String?) -> Bool {
        guard let host = components(baseURL)?.host?.lowercased() else { return false }
        return host == "api.kimi.com" || host == "api.kimi.ai"
    }

    /// True for any host Kimi itself runs (Moonshot Open Platform or Kimi Code).
    /// A key may be retried on the plan platform after such a host rejects it;
    /// a third-party gateway's rejection stays where it is.
    static func isKimiOperatedHost(_ baseURL: String?) -> Bool {
        guard let host = components(baseURL)?.host?.lowercased() else { return false }
        for domain in ["kimi.com", "kimi.ai", "moonshot.ai", "moonshot.cn"]
            where host == domain || host.hasSuffix("." + domain)
        {
            return true
        }
        return false
    }

    /// Scheme (https if missing), host and port of a user-typed base URL; the
    /// path, query and fragment are irrelevant to a Kimi Code host and dropped
    /// so a pasted full endpoint (`…/coding/v1/usages`) cannot double up.
    private static func components(_ raw: String?) -> URLComponents? {
        var base = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !base.isEmpty else { return nil }
        if !base.contains("://") {
            base = "https://\(base)"
        }
        guard var components = URLComponents(string: base), components.host?.isEmpty == false else {
            return nil
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components
    }

    /// Resolution: a Kimi Code host from the provider's base-URL setting wins
    /// (so a user on `api.kimi.ai` stays on `api.kimi.ai`), then kimi-cli's
    /// `KIMI_CODE_BASE_URL` (any proxy), then the default host.
    static func usagesURL(baseURL: String? = nil, environment: [String: String]) -> URL? {
        if self.isKimiCodeHost(baseURL), var components = components(baseURL) {
            components.path = "/coding/v1/usages"
            return components.url
        }
        var base = environment["KIMI_CODE_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if base.isEmpty { base = Self.defaultBaseURL }
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return URL(string: "\(base)/usages")
    }

    static func fetchUsage(
        apiKey: String,
        baseURL: String? = nil,
        environment: [String: String]) async throws -> UsageSnapshot
    {
        guard let url = self.usagesURL(baseURL: baseURL, environment: environment) else {
            throw KimiAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KimiAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw KimiAPIError.httpError(
                statusCode: httpResponse.statusCode,
                body: body?.isEmpty == false ? body : nil)
        }
        return try self.parse(data)
    }

    // MARK: - Parsing

    static func parse(_ data: Data, now: Date = Date()) throws -> UsageSnapshot {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KimiAPIError.invalidResponse
        }

        // Per-window caps (the 5h rolling limit), shortest first.
        var windows: [RateWindow] = (payload["limits"] as? [Any] ?? [])
            .compactMap { $0 as? [String: Any] }
            .compactMap { item in
                let detail = item["detail"] as? [String: Any] ?? item
                let window = item["window"] as? [String: Any] ?? [:]
                let minutes = Self.windowMinutes(
                    duration: window["duration"] ?? item["duration"] ?? detail["duration"],
                    timeUnit: window["timeUnit"] ?? item["timeUnit"] ?? detail["timeUnit"])
                return Self.countWindow(detail, windowMinutes: minutes, fallbackLabel: nil)
            }
            .sorted { ($0.windowMinutes ?? .max) < ($1.windowMinutes ?? .max) }

        // The plan-wide summary kimi-cli labels "Weekly limit".
        if let usage = payload["usage"] as? [String: Any],
           let weekly = Self.countWindow(usage, windowMinutes: nil, fallbackLabel: "Weekly")
        {
            windows.append(weekly)
        }

        // Newer ratio pools. Only fill in what the count-based fields didn't cover.
        if let pools = payload["usages"] as? [String: Any] {
            let hasShortWindow = windows.contains { ($0.windowMinutes ?? .max) <= 300 }
            if !hasShortWindow, let pool = pools["limit_5h"] as? [String: Any],
               let window = Self.ratioWindow(pool, windowMinutes: 300, label: "5h")
            {
                windows.insert(window, at: 0)
            }
            // `limit_month_total` first, `limit_month_code` when the total is
            // absent, null, or carries no ratio.
            let monthly = ["limit_month_total", "limit_month_code"].lazy
                .compactMap { pools[$0] as? [String: Any] }
                .compactMap { Self.ratioWindow($0, windowMinutes: nil, label: "Monthly") }
                .first
            if let monthly {
                windows.append(monthly)
            }
        }

        guard let primary = windows.first else {
            throw KimiCodeUsageError.noUsageData
        }
        return UsageSnapshot(
            primary: primary,
            secondary: windows.dropFirst().first,
            tertiary: windows.dropFirst(2).first,
            updatedAt: now,
            identity: nil)
    }

    private static func countWindow(
        _ data: [String: Any],
        windowMinutes: Int?,
        fallbackLabel: String?) -> RateWindow?
    {
        let limit = Self.number(data["limit"])
        var used = Self.number(data["used"])
        if used == nil, let remaining = Self.number(data["remaining"]), let limit {
            used = limit - remaining
        }
        guard let limit, limit > 0, let used else { return nil }
        let label = (data["name"] as? String) ?? (data["title"] as? String)
            ?? windowMinutes.map(Self.windowLabel) ?? fallbackLabel
        return RateWindow(
            usedPercent: min(100, max(0, used / limit * 100)),
            windowMinutes: windowMinutes,
            resetsAt: Self.resetDate(data),
            resetDescription: nil,
            label: label,
            hasKnownLimit: true)
    }

    private static func ratioWindow(_ data: [String: Any], windowMinutes: Int?, label: String) -> RateWindow? {
        guard let ratio = number(data["used_ratio"] ?? data["usedRatio"]) else { return nil }
        return RateWindow(
            usedPercent: min(100, max(0, ratio * 100)),
            windowMinutes: windowMinutes,
            resetsAt: Self.resetDate(data),
            resetDescription: nil,
            label: label,
            hasKnownLimit: true)
    }

    private static func windowMinutes(duration: Any?, timeUnit: Any?) -> Int? {
        guard let duration = number(duration).map(Int.init), duration > 0 else { return nil }
        let unit = (timeUnit as? String)?.uppercased() ?? ""
        if unit.contains("MINUTE") { return duration }
        if unit.contains("HOUR") { return duration * 60 }
        if unit.contains("DAY") { return duration * 1440 }
        if unit.contains("WEEK") { return duration * 10080 }
        return nil
    }

    private static func windowLabel(_ minutes: Int) -> String {
        if minutes % 10080 == 0 { return minutes == 10080 ? "Weekly" : "\(minutes / 10080)w" }
        if minutes % 1440 == 0 { return "\(minutes / 1440)d" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }

    static func number(_ value: Any?) -> Double? {
        switch value {
        case let value as NSNumber: value.doubleValue
        case let value as String: Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default: nil
        }
    }

    private static func resetDate(_ data: [String: Any]) -> Date? {
        for key in ["resetTime", "reset_time", "resetAt", "reset_at"] {
            if let raw = data[key] as? String, let date = parseTimestamp(raw) {
                return date
            }
        }
        return nil
    }

    /// RFC 3339 with up to nanosecond precision ("2026-01-06T13:33:02.717479433Z").
    /// `ISO8601DateFormatter` only takes milliseconds, so trim the fraction first.
    static func parseTimestamp(_ raw: String) -> Date? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dot = value.firstIndex(of: ".") {
            let fractionStart = value.index(after: dot)
            let fractionEnd = value[fractionStart...].firstIndex { !$0.isNumber } ?? value.endIndex
            let digits = value[fractionStart..<fractionEnd]
            if digits.count > 3 {
                value.replaceSubrange(fractionStart..<fractionEnd, with: digits.prefix(3))
            }
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = value.contains(".")
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

enum KimiCodeUsageError: LocalizedError {
    case noUsageData

    var errorDescription: String? {
        "Kimi Code returned no plan usage."
    }
}

extension KimiUsageFetcher {
    /// Usage for a Kimi key on the given host.
    ///
    /// A Kimi Code host (`api.kimi.com` / `api.kimi.ai`) serves plan usage only —
    /// the Moonshot balance route 404s there — so it goes straight to plan usage
    /// on that same host. Otherwise the Open Platform balance is tried first
    /// (pay-as-you-go keys). When the host rejects the key (401/403), or a
    /// Kimi-operated host has no such route (404), it may be a Kimi Code
    /// subscription key instead, so plan usage is tried next. If that is
    /// rejected too, the original balance error surfaces; any other plan error
    /// surfaces as-is (it's the likelier story). A 404 from a third-party
    /// gateway surfaces as-is: the key is not retried on a host the user did
    /// not configure.
    static func fetchSnapshot(
        apiKey: String,
        baseURL: String?,
        environment: [String: String]) async throws -> UsageSnapshot
    {
        if KimiCodeUsageFetcher.isKimiCodeHost(baseURL) {
            return try await KimiCodeUsageFetcher.fetchUsage(
                apiKey: apiKey, baseURL: baseURL, environment: environment)
        }
        do {
            let currency = KimiBalanceResponse.currency(forBalanceURL: self.balanceURL(baseURL: baseURL))
            return try await self.fetchBalance(apiKey: apiKey, baseURL: baseURL)
                .toUsageSnapshot(currency: currency)
        } catch let KimiAPIError.httpError(statusCode, body)
            where statusCode == 401 || statusCode == 403
            || (statusCode == 404 && KimiCodeUsageFetcher.isKimiOperatedHost(baseURL ?? Self.defaultBaseURL))
        {
            do {
                return try await KimiCodeUsageFetcher.fetchUsage(apiKey: apiKey, environment: environment)
            } catch let KimiAPIError.httpError(planStatus, _) where planStatus == 401 || planStatus == 403 {
                throw KimiAPIError.httpError(statusCode: statusCode, body: body)
            }
        }
    }
}
