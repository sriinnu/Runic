import Foundation
import Silo
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MiniMaxWebUsageResult: Sendable {
    public let usage: UsageSnapshot
    public let sourceLabel: String

    public init(usage: UsageSnapshot, sourceLabel: String) {
        self.usage = usage
        self.sourceLabel = sourceLabel
    }
}

public enum MiniMaxWebUsageError: LocalizedError, Sendable {
    case unsupportedPlatform
    case noSession
    case notLoggedIn(String)
    case apiError(String)
    case networkError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            "MiniMax web usage is only available on macOS."
        case .noSession:
            "No MiniMax session found. Log in to platform.minimax.io or paste a Cookie header in Settings."
        case let .notLoggedIn(message):
            "MiniMax session is not logged in. \(message)"
        case let .apiError(message):
            "MiniMax API error: \(message)"
        case let .networkError(message):
            "MiniMax network error: \(message)"
        case let .parseFailed(message):
            "MiniMax parsing error: \(message)"
        }
    }
}

public struct MiniMaxWebUsageFetcher: Sendable {
    private static let codingPlanURL = URL(string: "https://platform.minimax.io/user-center/payment/coding-plan")!
    private static let remainsURL = URL(string: "https://platform.minimax.io/v1/api/openplatform/coding_plan/remains")!

    public init() {}

    public func fetchUsage(
        timeout: TimeInterval = 15.0,
        logger: ((String) -> Void)? = nil) async throws -> MiniMaxWebUsageResult
    {
        #if os(macOS)
        let log: (String) -> Void = { message in
            logger?("[minimax] \(message)")
        }
        let sessions = self.resolveSessions(logger: log)
        var lastError: Error?

        for session in sessions {
            do {
                let usage = try await self.fetchUsage(session: session, timeout: timeout, logger: log)
                return MiniMaxWebUsageResult(usage: usage, sourceLabel: session.sourceLabel)
            } catch {
                lastError = error
                if case MiniMaxWebUsageError.notLoggedIn = error {
                    log("Session rejected (\(session.sourceLabel)); trying next source")
                    continue
                }
                log("Session failed (\(session.sourceLabel)): \(error.localizedDescription)")
            }
        }

        if let lastError { throw lastError }
        throw MiniMaxWebUsageError.noSession
        #else
        throw MiniMaxWebUsageError.unsupportedPlatform
        #endif
    }

    #if os(macOS)
    private func resolveSessions(logger: @escaping (String) -> Void) -> [MiniMaxWebSession] {
        var sessions: [MiniMaxWebSession] = []
        let fallbackGroupID = ProviderTokenResolver.minimaxGroupID()

        if let manual = self.manualSession() {
            let resolved = MiniMaxWebSession(
                cookieHeader: manual.cookieHeader,
                accessToken: manual.accessToken,
                groupID: manual.groupID ?? fallbackGroupID,
                sourceLabel: manual.sourceLabel,
                isManual: true)
            sessions.append(resolved)
        }

        let tokenCandidates = MiniMaxLocalStorageImporter.importTokens(logger: logger)
        let cookieSessions = MiniMaxCookieImporter.importSessions(logger: logger)

        for cookieSession in cookieSessions {
            if tokenCandidates.isEmpty {
                sessions.append(MiniMaxWebSession(
                    cookieHeader: cookieSession.cookieHeader,
                    accessToken: nil,
                    groupID: fallbackGroupID,
                    sourceLabel: cookieSession.sourceLabel,
                    isManual: false))
                continue
            }

            for token in tokenCandidates {
                sessions.append(MiniMaxWebSession(
                    cookieHeader: cookieSession.cookieHeader,
                    accessToken: token.accessToken,
                    groupID: token.groupID ?? fallbackGroupID,
                    sourceLabel: "\(cookieSession.sourceLabel)",
                    isManual: false))
            }

            sessions.append(MiniMaxWebSession(
                cookieHeader: cookieSession.cookieHeader,
                accessToken: nil,
                groupID: fallbackGroupID,
                sourceLabel: cookieSession.sourceLabel,
                isManual: false))
        }

        if sessions.isEmpty {
            logger("No MiniMax cookie sessions found.")
        }

        return sessions
    }

    private func manualSession() -> MiniMaxWebSession? {
        guard let resolution = ProviderTokenResolver.minimaxCookieHeaderResolution(),
              let parsed = MiniMaxWebParsing.parseManualInput(resolution.token)
        else {
            return nil
        }

        let label = resolution.source == .environment ? "manual (env)" : "manual"
        return MiniMaxWebSession(
            cookieHeader: parsed.cookieHeader,
            accessToken: parsed.accessToken,
            groupID: parsed.groupID,
            sourceLabel: label,
            isManual: true)
    }

    private func fetchUsage(
        session: MiniMaxWebSession,
        timeout: TimeInterval,
        logger: (String) -> Void) async throws -> UsageSnapshot
    {
        let now = Date()
        if let html = try? await self.fetchCodingPlanHTML(
            session: session,
            timeout: timeout)
        {
            if let parsed = MiniMaxWebParsing.parseHTMLUsage(html, now: now) {
                logger("Parsed usage from coding plan HTML.")
                return parsed.toUsageSnapshot(updatedAt: now)
            }
        }

        let data = try await self.fetchRemainsAPI(session: session, timeout: timeout)
        let parsed = try MiniMaxWebParsing.parseRemainsResponse(data, now: now)
        return parsed.toUsageSnapshot(updatedAt: now)
    }

    private func fetchCodingPlanHTML(session: MiniMaxWebSession, timeout: TimeInterval) async throws -> String {
        var request = URLRequest(url: Self.codingPlanURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue(session.cookieHeader, forHTTPHeaderField: "Cookie")
        if let accessToken = session.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxWebUsageError.networkError("Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            throw MiniMaxWebUsageError.networkError("HTTP \(httpResponse.statusCode)")
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    }

    private func fetchRemainsAPI(session: MiniMaxWebSession, timeout: TimeInterval) async throws -> Data {
        var url = Self.remainsURL
        if let groupID = session.groupID, !groupID.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "GroupId", value: groupID)]
            if let withQuery = components?.url {
                url = withQuery
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue(session.cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue(Self.codingPlanURL.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken = session.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxWebUsageError.networkError("Invalid response")
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw MiniMaxWebUsageError.notLoggedIn("HTTP \(httpResponse.statusCode)")
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw MiniMaxWebUsageError.apiError("HTTP \(httpResponse.statusCode): \(body)")
        }
        return data
    }
    #endif
}

// MARK: - Parsing helpers

struct MiniMaxManualInput: Sendable {
    let cookieHeader: String
    let accessToken: String?
    let groupID: String?
}

struct MiniMaxParsedUsage: Sendable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: Date?
    let resetDescription: String?
    let planName: String?
    let modelName: String?

    func toUsageSnapshot(updatedAt: Date) -> UsageSnapshot {
        let primary = RateWindow(
            usedPercent: min(100, max(0, self.usedPercent)),
            windowMinutes: self.windowMinutes,
            resetsAt: self.resetsAt,
            resetDescription: self.resetDescription,
            label: self.modelName)
        let identity = ProviderIdentitySnapshot(
            providerID: .minimax,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: self.planName)
        return UsageSnapshot(
            primary: primary,
            secondary: nil,
            tertiary: nil,
            providerCost: nil,
            updatedAt: updatedAt,
            identity: identity)
    }
}

enum MiniMaxWebParsing {
    static func parseManualInput(_ raw: String) -> MiniMaxManualInput? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cookieHeader = self.extractCookieHeader(from: trimmed)
            ?? (self.looksLikeCookieHeader(trimmed) ? trimmed : nil)
        guard let cookieHeader, !cookieHeader.isEmpty else { return nil }

        let accessToken = self.extractBearerToken(from: trimmed)
        let groupID = self.extractGroupID(from: trimmed)
        return MiniMaxManualInput(cookieHeader: cookieHeader, accessToken: accessToken, groupID: groupID)
    }

    static func parseHTMLUsage(_ html: String, now: Date = Date()) -> MiniMaxParsedUsage? {
        let planName = self.extractHTMLTitle(from: html)
        guard let usage = self.extractAvailableUsage(from: html) else { return nil }
        let resetLine = self.extractResetLine(from: html)
        let resetInfo = resetLine.flatMap { self.parseResetDescription($0, now: now) }
        let windowMinutes = self.extractWindowMinutes(from: html)
        return MiniMaxParsedUsage(
            usedPercent: usage,
            windowMinutes: windowMinutes,
            resetsAt: resetInfo?.resetsAt,
            resetDescription: resetInfo?.resetDescription,
            planName: planName,
            modelName: nil)
    }

    static func parseRemainsResponse(_ data: Data, now: Date = Date()) throws -> MiniMaxParsedUsage {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MiniMaxWebUsageError.parseFailed("Invalid JSON")
        }

        if let base = json["base_resp"] as? [String: Any] {
            let retcode = self.doubleValue(base["retcode"]).map(Int.init) ?? 0
            let success = base["success"] as? Bool
            if success == false || retcode != 0 {
                let msg = base["msg"] as? String ?? "unknown error"
                if retcode == 1004 {
                    throw MiniMaxWebUsageError.notLoggedIn(msg)
                }
                throw MiniMaxWebUsageError.apiError(msg)
            }
        }

        let payload = (json["data"] as? [String: Any]) ?? json
        guard let modelRemains = self.extractModelRemains(from: payload) else {
            throw MiniMaxWebUsageError.parseFailed("Missing model_remains usage")
        }
        let usage = modelRemains.usedPercent

        let startTime = self.timestamp(payload["start_time"])
        let endTime = self.timestamp(payload["end_time"])
        let remainsTime = self.doubleValue(payload["remains_time"])
        let resetsAt = self.resolveResetDate(remainsTime: remainsTime, endTime: endTime, now: now)
        let windowMinutes = self.windowMinutes(start: startTime, end: endTime)
        let resetDescription = resetsAt.map { UsageFormatter.resetDescription(from: $0, now: now) }
        let planName = self.firstString(in: payload, keys: ["plan_name", "plan", "tier", "plan_title", "planType"])

        return MiniMaxParsedUsage(
            usedPercent: usage,
            windowMinutes: windowMinutes,
            resetsAt: resetsAt,
            resetDescription: resetDescription,
            planName: planName,
            modelName: modelRemains.modelName)
    }

    // MARK: - Manual parsing

    private static func extractCookieHeader(from text: String) -> String? {
        let pattern = "(?i)(?:-H|--header)?\\s*['\\\"]?Cookie\\s*:\\s*([^'\\\"\\r\\n]+)"
        return self.firstCapture(in: text, pattern: pattern)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { self.stripCookiePrefix($0) }
    }

    private static func stripCookiePrefix(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("cookie:") {
            let stripped = String(trimmed.dropFirst("cookie:".count))
            return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func looksLikeCookieHeader(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("=") else { return false }
        return !trimmed.lowercased().contains("curl ")
    }

    private static func extractBearerToken(from text: String) -> String? {
        let pattern = "(?i)Authorization\\s*:\\s*Bearer\\s+([^'\\\"\\r\\n]+)"
        return self.firstCapture(in: text, pattern: pattern)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func extractGroupID(from text: String) -> String? {
        if let match = self.firstCapture(in: text, pattern: "(?i)GroupId\\s*[:=]\\s*([A-Za-z0-9_-]+)") {
            return match
        }
        if let match = self.firstCapture(in: text, pattern: "(?i)group_id\\s*[:=]\\s*([A-Za-z0-9_-]+)") {
            return match
        }
        if let match = self.firstCapture(in: text, pattern: "(?i)(?:GroupId|group_id)=([^&'\"\\s]+)") {
            return match
        }
        return nil
    }

    // MARK: - HTML parsing

    private static func extractHTMLTitle(from html: String) -> String? {
        guard let raw = self.firstCapture(in: html, pattern: "(?is)<title[^>]*>(.*?)</title>") else {
            return nil
        }
        let cleaned = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func extractAvailableUsage(from html: String) -> Double? {
        if let groups = self.captureGroups(
            in: html,
            pattern: "(?i)Available usage[^0-9]*([0-9]+(?:\\.[0-9]+)?)\\s*/\\s*([0-9]+(?:\\.[0-9]+)?)")
        {
            let remaining = self.doubleValue(groups[0]) ?? 0
            let total = self.doubleValue(groups[1]) ?? 0
            if total > 0 {
                return min(100, max(0, (total - remaining) / total * 100))
            }
        }

        if let percent = self.captureGroups(
            in: html,
            pattern: "(?i)Available usage[^0-9]*([0-9]+(?:\\.[0-9]+)?)\\s*%")?.first
        {
            let remaining = self.doubleValue(percent) ?? 0
            return min(100, max(0, 100 - remaining))
        }

        if let remaining = self.captureGroups(
            in: html,
            pattern: "(?i)Available usage[^0-9]*([0-9]+(?:\\.[0-9]+)?)")?.first,
           let total = self.captureGroups(
            in: html,
            pattern: "(?i)Total usage[^0-9]*([0-9]+(?:\\.[0-9]+)?)")?.first
        {
            let remainingValue = self.doubleValue(remaining) ?? 0
            let totalValue = self.doubleValue(total) ?? 0
            if totalValue > 0 {
                return min(100, max(0, (totalValue - remainingValue) / totalValue * 100))
            }
        }

        return nil
    }

    private static func extractResetLine(from html: String) -> String? {
        guard let line = self.firstCapture(in: html, pattern: "(?i)(Resets in[^<\\n\\r]*)") else {
            return nil
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseResetDescription(
        _ line: String,
        now: Date) -> (resetsAt: Date?, resetDescription: String?)
    {
        let cleaned = line.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        let minutes = self.parseDurationMinutes(from: trimmed)
        let resetsAt = minutes.map { now.addingTimeInterval(TimeInterval($0 * 60)) }
        return (resetsAt, trimmed)
    }

    private static func extractWindowMinutes(from html: String) -> Int? {
        guard let groups = self.captureGroups(
            in: html,
            pattern: "(?i)(?:cycle|duration|period)[^0-9]*([0-9]+)\\s*(day|hour|week|month)")
        else { return nil }

        guard let value = Int(groups[0]) else { return nil }
        let unit = groups[1].lowercased()
        switch unit {
        case "hour", "hours":
            return value * 60
        case "day", "days":
            return value * 24 * 60
        case "week", "weeks":
            return value * 7 * 24 * 60
        case "month", "months":
            return value * 30 * 24 * 60
        default:
            return nil
        }
    }

    // MARK: - JSON parsing

    private struct ModelRemainsUsage {
        let usedPercent: Double
        let modelName: String?
    }

    private static func extractModelRemains(from payload: [String: Any]) -> ModelRemainsUsage? {
        if let model = payload["model_remains"] {
            return self.extractUsagePercent(from: model)
        }
        if let model = payload["model_remain"] {
            return self.extractUsagePercent(from: model)
        }
        if let model = payload["remains"] {
            return self.extractUsagePercent(from: model)
        }
        return nil
    }

    private static func extractUsagePercent(from value: Any) -> ModelRemainsUsage? {
        if let dict = value as? [String: Any] {
            let used = self.doubleValue(dict["used"] ?? dict["used_quota"] ?? dict["usedQuota"])
            let total = self.doubleValue(dict["total"] ?? dict["total_quota"] ?? dict["totalQuota"])
            let remaining = self.doubleValue(dict["remaining"] ?? dict["remaining_quota"] ?? dict["remainingQuota"])
            let modelName = self.firstString(in: dict, keys: ["model_name", "model", "name", "label"])

            if let used, let total, total > 0 {
                return ModelRemainsUsage(
                    usedPercent: min(100, max(0, used / total * 100)),
                    modelName: modelName)
            }
            if let remaining, let total, total > 0 {
                return ModelRemainsUsage(
                    usedPercent: min(100, max(0, (total - remaining) / total * 100)),
                    modelName: modelName)
            }
        }
        if let dicts = value as? [[String: Any]] {
            for entry in dicts {
                if let percent = self.extractUsagePercent(from: entry) {
                    return percent
                }
            }
        }
        return nil
    }

    private static func windowMinutes(start: Date?, end: Date?) -> Int? {
        guard let start, let end else { return nil }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        return minutes > 0 ? minutes : nil
    }

    private static func resolveResetDate(remainsTime: Double?, endTime: Date?, now: Date) -> Date? {
        if let remains = remainsTime {
            if remains > 1_000_000_000 {
                return self.timestamp(remains)
            }
            return now.addingTimeInterval(remains)
        }
        return endTime
    }

    private static func timestamp(_ value: Any?) -> Date? {
        guard let value else { return nil }
        if let number = self.doubleValue(value) {
            return self.timestamp(number)
        }
        return nil
    }

    private static func timestamp(_ number: Double) -> Date? {
        if number > 10_000_000_000 {
            return Date(timeIntervalSince1970: number / 1000)
        }
        if number > 1_000_000_000 {
            return Date(timeIntervalSince1970: number)
        }
        return nil
    }

    private static func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    // MARK: - Regex helpers

    fileprivate static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange])
    }

    fileprivate static func captureGroups(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1
        else {
            return nil
        }
        var groups: [String] = []
        for index in 1..<match.numberOfRanges {
            guard let range = Range(match.range(at: index), in: text) else { continue }
            groups.append(String(text[range]))
        }
        return groups.isEmpty ? nil : groups
    }

    fileprivate static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let number = value as? Int64 { return Double(number) }
        if let number = value as? String {
            return Double(number.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func parseDurationMinutes(from line: String) -> Int? {
        var minutes = 0
        let patterns: [(String, Int)] = [
            ("(?i)([0-9]+)\\s*d", 24 * 60),
            ("(?i)([0-9]+)\\s*h", 60),
            ("(?i)([0-9]+)\\s*m", 1),
        ]
        for (pattern, multiplier) in patterns {
            if let capture = self.firstCapture(in: line, pattern: pattern),
               let value = Int(capture)
            {
                minutes += value * multiplier
            }
        }
        return minutes > 0 ? minutes : nil
    }
}

#if os(macOS)
private struct MiniMaxWebSession: Sendable {
    let cookieHeader: String
    let accessToken: String?
    let groupID: String?
    let sourceLabel: String
    let isManual: Bool
}

private struct MiniMaxCookieSession: Sendable {
    let cookieHeader: String
    let sourceLabel: String
}

private enum MiniMaxCookieImporter {
    private static let cookieClient = BrowserCookieClient()
    private static let cookieDomains = ["platform.minimax.io", "minimax.io"]

    static func importSessions(logger: ((String) -> Void)? = nil) -> [MiniMaxCookieSession] {
        let log: (String) -> Void = { msg in logger?("[minimax-cookie] \(msg)") }
        let order = ProviderDefaults.metadata[.minimax]?.browserCookieOrder ?? Browser.defaultImportOrder
        var sessions: [MiniMaxCookieSession] = []

        for browserSource in order {
            do {
                let query = BrowserCookieQuery(domains: self.cookieDomains)
                let sources = try Self.cookieClient.records(matching: query, in: browserSource)
                if sources.isEmpty { continue }

                let grouped = Dictionary(grouping: sources, by: { $0.store.profile })
                for (profile, records) in grouped {
                    let mergedRecords = records.flatMap(\.records)
                    guard !mergedRecords.isEmpty else { continue }
                    let cookies = BrowserCookieClient.makeHTTPCookies(mergedRecords, origin: query.origin)
                    guard !cookies.isEmpty else { continue }
                    let label = self.label(for: browserSource, profile: profile, sources: records)
                    log("Found \(cookies.count) cookies in \(label)")
                    sessions.append(MiniMaxCookieSession(
                        cookieHeader: cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "),
                        sourceLabel: label))
                }
            } catch {
                log("\(browserSource.displayName) cookie import failed: \(error.localizedDescription)")
            }
        }

        return sessions
    }

    private static func label(
        for browser: Browser,
        profile: BrowserProfile,
        sources: [BrowserCookieStoreRecords]) -> String
    {
        if sources.count == 1 {
            return sources[0].label
        }
        let suffix = profile.name.isEmpty ? "" : " \(profile.name)"
        return "\(browser.displayName)\(suffix) (merged)"
    }
}

private struct MiniMaxLocalStorageToken: Sendable {
    let accessToken: String
    let groupID: String?
    let sourceLabel: String
}

private enum MiniMaxLocalStorageImporter {
    static func importTokens(logger: ((String) -> Void)? = nil) -> [MiniMaxLocalStorageToken] {
        let log: (String) -> Void = { msg in logger?("[minimax-storage] \(msg)") }
        var tokens: [MiniMaxLocalStorageToken] = []

        let candidates = self.chromeLocalStorageCandidates()
        if !candidates.isEmpty {
            log("Chromium local storage candidates: \(candidates.count)")
        }

        for candidate in candidates {
            guard let match = self.readToken(from: candidate.levelDBURL) else { continue }
            log("Found MiniMax access_token in \(candidate.label)")
            tokens.append(MiniMaxLocalStorageToken(
                accessToken: match.accessToken,
                groupID: match.groupID,
                sourceLabel: candidate.label))
        }

        if tokens.isEmpty {
            log("No MiniMax access_token found in Chromium local storage")
        }

        return tokens
    }

    private struct LocalStorageCandidate: Sendable {
        let label: String
        let levelDBURL: URL
    }

    private static func chromeLocalStorageCandidates() -> [LocalStorageCandidate] {
        let roots: [(url: URL, labelPrefix: String)] = self.candidateHomes().flatMap { home in
            let appSupport = home
                .appendingPathComponent("Library")
                .appendingPathComponent("Application Support")
            return [
                (appSupport.appendingPathComponent("Google").appendingPathComponent("Chrome"), "Chrome"),
                (appSupport.appendingPathComponent("Google").appendingPathComponent("Chrome Beta"), "Chrome Beta"),
                (appSupport.appendingPathComponent("Google").appendingPathComponent("Chrome Canary"), "Chrome Canary"),
                (appSupport.appendingPathComponent("Arc").appendingPathComponent("User Data"), "Arc"),
                (appSupport.appendingPathComponent("Arc Beta").appendingPathComponent("User Data"), "Arc Beta"),
                (appSupport.appendingPathComponent("Arc Canary").appendingPathComponent("User Data"), "Arc Canary"),
                (
                    appSupport
                        .appendingPathComponent("com.openai.atlas")
                        .appendingPathComponent("browser-data")
                        .appendingPathComponent("host"),
                    "ChatGPT Atlas"),
                (appSupport.appendingPathComponent("Chromium"), "Chromium"),
                (appSupport.appendingPathComponent("BraveSoftware").appendingPathComponent("Brave-Browser"), "Brave"),
                (appSupport.appendingPathComponent("Microsoft Edge"), "Edge"),
            ]
        }

        var candidates: [LocalStorageCandidate] = []
        for root in roots {
            candidates.append(contentsOf: self.chromeProfileLocalStorageDirs(
                root: root.url,
                labelPrefix: root.labelPrefix))
        }
        return candidates
    }

    private static func chromeProfileLocalStorageDirs(
        root: URL,
        labelPrefix: String) -> [LocalStorageCandidate]
    {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])
        else { return [] }

        let profileDirs = entries.filter { url in
            guard let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory), isDir else {
                return false
            }
            let name = url.lastPathComponent
            return name == "Default" || name.hasPrefix("Profile ") || name.hasPrefix("user-")
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return profileDirs.compactMap { dir in
            let levelDBURL = dir.appendingPathComponent("Local Storage").appendingPathComponent("leveldb")
            guard FileManager.default.fileExists(atPath: levelDBURL.path) else { return nil }
            let label = "\(labelPrefix) \(dir.lastPathComponent)"
            return LocalStorageCandidate(label: label, levelDBURL: levelDBURL)
        }
    }

    private static func candidateHomes() -> [URL] {
        var homes: [URL] = []
        homes.append(FileManager.default.homeDirectoryForCurrentUser)
        if let userHome = NSHomeDirectoryForUser(NSUserName()) {
            homes.append(URL(fileURLWithPath: userHome))
        }
        if let envHome = ProcessInfo.processInfo.environment["HOME"], !envHome.isEmpty {
            homes.append(URL(fileURLWithPath: envHome))
        }
        var seen = Set<String>()
        return homes.filter { home in
            let path = home.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }

    private struct TokenMatch: Sendable {
        let accessToken: String
        let groupID: String?
    }

    private static func readToken(from levelDBURL: URL) -> TokenMatch? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: levelDBURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])
        else { return nil }

        let files = entries.filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "ldb" || ext == "log"
        }
        .sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            return (left ?? .distantPast) > (right ?? .distantPast)
        }

        for file in files {
            guard let data = try? Data(contentsOf: file, options: [.mappedIfSafe]) else { continue }
            if let match = self.extractToken(from: data) {
                return match
            }
        }
        return nil
    }

    private static func extractToken(from data: Data) -> TokenMatch? {
        guard let contents = String(data: data, encoding: .utf8) ??
            String(data: data, encoding: .isoLatin1)
        else { return nil }

        if let match = self.matchToken(in: contents) {
            return match
        }

        let jwtCandidates = self.extractJWTs(from: contents)
        for token in jwtCandidates {
            if self.isMiniMaxJWT(token) {
                let groupID = self.extractGroupID(from: contents) ?? self.groupID(from: token)
                return TokenMatch(accessToken: token, groupID: groupID)
            }
        }

        return nil
    }

    private static func matchToken(in contents: String) -> TokenMatch? {
        guard contents.contains("minimax") || contents.contains("platform.minimax") else { return nil }

        let tokenPattern = "(?i)access_token[^A-Za-z0-9._-]*([A-Za-z0-9._-]{20,})"
        guard let token = MiniMaxWebParsing.firstCapture(in: contents, pattern: tokenPattern) else { return nil }
        guard self.isMiniMaxJWT(token) || contents.contains("minimax.io") else { return nil }

        let groupID = self.extractGroupID(from: contents) ?? self.groupID(from: token)
        return TokenMatch(accessToken: token, groupID: groupID)
    }

    private static func extractJWTs(from contents: String) -> [String] {
        let pattern = "[A-Za-z0-9_-]{20,}\\.[A-Za-z0-9_-]{20,}\\.[A-Za-z0-9_-]{20,}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
        return regex.matches(in: contents, options: [], range: range).compactMap { match in
            guard let range = Range(match.range(at: 0), in: contents) else { return nil }
            return String(contents[range])
        }
    }

    private static func isMiniMaxJWT(_ token: String) -> Bool {
        guard let payload = self.decodeJWTPayload(token) else { return false }
        return payload.values.contains { value in
            guard let string = value as? String else { return false }
            let lower = string.lowercased()
            return lower.contains("minimax") || lower.contains("platform.minimax.io")
        }
    }

    private static func groupID(from token: String) -> String? {
        guard let payload = self.decodeJWTPayload(token) else { return nil }
        if let groupID = payload["group_id"] as? String { return groupID }
        if let groupID = payload["groupId"] as? String { return groupID }
        return nil
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        let payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = payload + String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json
    }

    private static func extractGroupID(from contents: String) -> String? {
        if let match = MiniMaxWebParsing.firstCapture(
            in: contents,
            pattern: "(?i)group_id[^A-Za-z0-9_-]*([A-Za-z0-9_-]+)")
        {
            return match
        }
        if let match = MiniMaxWebParsing.firstCapture(
            in: contents,
            pattern: "(?i)groupId[^A-Za-z0-9_-]*([A-Za-z0-9_-]+)")
        {
            return match
        }
        return nil
    }
}
#endif
