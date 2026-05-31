import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct GeminiModelQuota: Sendable {
    public let modelId: String
    public let percentLeft: Double
    public let resetTime: Date?
    public let resetDescription: String?
}

public struct GeminiStatusSnapshot: Sendable {
    public let modelQuotas: [GeminiModelQuota]
    public let rawText: String
    public let accountEmail: String?
    public let accountPlan: String?

    // Convenience: lowest quota across all models (for icon display)
    public var lowestPercentLeft: Double? {
        self.modelQuotas.min(by: { $0.percentLeft < $1.percentLeft })?.percentLeft
    }

    /// Legacy compatibility
    public var dailyPercentLeft: Double? {
        self.lowestPercentLeft
    }

    public var resetDescription: String? {
        self.modelQuotas.min(by: { $0.percentLeft < $1.percentLeft })?.resetDescription
    }

    /// Converts Gemini quotas to a unified UsageSnapshot.
    /// Prioritizes Pro and Flash tiers, then fills an optional tertiary slot with the next-most-constrained model.
    public func toUsageSnapshot() -> UsageSnapshot {
        let selected = Self.selectDisplayQuotas(self.modelQuotas)
        let primaryQuota = selected.first
        let secondaryQuota = selected.count > 1 ? selected[1] : nil
        let tertiaryQuota = selected.count > 2 ? selected[2] : nil

        let primary = Self.rateWindow(from: primaryQuota) ?? RateWindow(
            usedPercent: 0,
            windowMinutes: 1440,
            resetsAt: nil,
            resetDescription: nil,
            label: nil)
        let secondary = Self.rateWindow(from: secondaryQuota)
        let tertiary = Self.rateWindow(from: tertiaryQuota)

        let identity = ProviderIdentitySnapshot(
            providerID: .gemini,
            accountEmail: self.accountEmail,
            accountOrganization: nil,
            loginMethod: self.accountPlan)
        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            updatedAt: Date(),
            identity: identity)
    }

    private static func selectDisplayQuotas(_ quotas: [GeminiModelQuota]) -> [GeminiModelQuota] {
        guard !quotas.isEmpty else { return [] }

        let normalized = quotas.map { (quota: $0, lowerModelID: $0.modelId.lowercased()) }
        let pro = normalized
            .filter { $0.lowerModelID.contains("pro") }
            .map(\.quota)
            .min(by: { $0.percentLeft < $1.percentLeft })
        let flash = normalized
            .filter { $0.lowerModelID.contains("flash") }
            .map(\.quota)
            .min(by: { $0.percentLeft < $1.percentLeft })

        var ordered: [GeminiModelQuota] = []
        if let pro {
            ordered.append(pro)
        }
        if let flash, !Self.containsModel(ordered, matching: flash) {
            ordered.append(flash)
        }

        for quota in quotas.sorted(by: { lhs, rhs in
            if lhs.percentLeft == rhs.percentLeft {
                return lhs.modelId.localizedCaseInsensitiveCompare(rhs.modelId) == .orderedAscending
            }
            return lhs.percentLeft < rhs.percentLeft
        }) where ordered.count < 3 {
            guard !Self.containsModel(ordered, matching: quota) else { continue }
            ordered.append(quota)
        }

        return Array(ordered.prefix(3))
    }

    private static func containsModel(_ quotas: [GeminiModelQuota], matching candidate: GeminiModelQuota) -> Bool {
        let normalized = candidate.modelId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return quotas.contains {
            $0.modelId
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == normalized
        }
    }

    private static func rateWindow(from quota: GeminiModelQuota?) -> RateWindow? {
        guard let quota else { return nil }
        return RateWindow(
            usedPercent: max(0, min(100, 100 - quota.percentLeft)),
            windowMinutes: 1440,
            resetsAt: quota.resetTime,
            resetDescription: quota.resetDescription,
            label: self.formattedModelLabel(quota.modelId))
    }

    private static func formattedModelLabel(_ modelID: String) -> String? {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lastPathComponent = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
        let normalized = lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

public enum GeminiStatusProbeError: LocalizedError, Sendable, Equatable {
    case geminiNotInstalled
    case notLoggedIn
    case unsupportedAuthType(String)
    case parseFailed(String)
    case timedOut
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .geminiNotInstalled:
            "Gemini CLI is not installed or not on PATH."
        case .notLoggedIn:
            "Not logged in to Gemini. Run 'gemini' in Terminal to authenticate."
        case let .unsupportedAuthType(authType):
            "Gemini \(authType) auth not supported. Use Google account (OAuth) instead."
        case let .parseFailed(msg):
            "Could not parse Gemini usage: \(msg)"
        case .timedOut:
            "Gemini quota API request timed out."
        case let .apiError(msg):
            "Gemini API error: \(msg)"
        }
    }
}

public enum GeminiAuthType: String, Sendable {
    case oauthPersonal = "oauth-personal"
    case apiKey = "api-key"
    case vertexAI = "vertex-ai"
    case unknown
}

/// User tier IDs returned from the Cloud Code Private API (loadCodeAssist).
/// Maps to: google3/cloud/developer_experience/cloudcode/pa/service/usertier.go
public enum GeminiUserTierId: String, Sendable {
    case free = "free-tier"
    case legacy = "legacy-tier"
    case standard = "standard-tier"
}

public struct GeminiStatusProbe: Sendable {
    public var timeout: TimeInterval = 10.0
    public var homeDirectory: String
    public var dataLoader: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private static let log = RunicLog.logger("gemini-probe")
    private static let quotaEndpoint = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
    private static let loadCodeAssistEndpoint = "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist"
    private static let projectsEndpoint = "https://cloudresourcemanager.googleapis.com/v1/projects"
    private static let settingsPath = "/.gemini/settings.json"

    public init(
        timeout: TimeInterval = 10.0,
        homeDirectory: String = NSHomeDirectory(),
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        })
    {
        self.timeout = timeout
        self.homeDirectory = homeDirectory
        self.dataLoader = dataLoader
    }

    /// Reads the current Gemini auth type from settings.json
    public static func currentAuthType(homeDirectory: String = NSHomeDirectory()) -> GeminiAuthType {
        let settingsURL = URL(fileURLWithPath: homeDirectory + Self.settingsPath)

        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let security = json["security"] as? [String: Any],
              let auth = security["auth"] as? [String: Any],
              let selectedType = auth["selectedType"] as? String
        else {
            return .unknown
        }

        return GeminiAuthType(rawValue: selectedType) ?? .unknown
    }

    public func fetch() async throws -> GeminiStatusSnapshot {
        // Block explicitly unsupported auth types; allow unknown to try OAuth creds
        let authType = Self.currentAuthType(homeDirectory: self.homeDirectory)
        switch authType {
        case .apiKey:
            throw GeminiStatusProbeError.unsupportedAuthType("API key")
        case .vertexAI:
            throw GeminiStatusProbeError.unsupportedAuthType("Vertex AI")
        case .oauthPersonal, .unknown:
            break
        }

        let snap = try await Self.fetchViaAPI(
            timeout: self.timeout,
            homeDirectory: self.homeDirectory,
            dataLoader: self.dataLoader)

        Self.log.info("Gemini API fetch ok", metadata: [
            "dailyPercentLeft": "\(snap.dailyPercentLeft ?? -1)",
        ])
        return snap
    }

    // MARK: - Direct API approach

    private static func fetchViaAPI(
        timeout: TimeInterval,
        homeDirectory: String,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async throws
        -> GeminiStatusSnapshot
    {
        let creds = try Self.loadCredentials(homeDirectory: homeDirectory)

        let expiryStr = creds.expiryDate.map { "\($0)" } ?? "nil"
        let hasRefresh = creds.refreshToken != nil
        Self.log.debug("Token check", metadata: [
            "expiry": expiryStr,
            "hasRefresh": hasRefresh ? "1" : "0",
            "now": "\(Date())",
        ])

        guard let storedAccessToken = creds.accessToken, !storedAccessToken.isEmpty else {
            Self.log.error("No access token found")
            throw GeminiStatusProbeError.notLoggedIn
        }

        var accessToken = storedAccessToken
        if let expiry = creds.expiryDate, expiry < Date() {
            Self.log.info("Token expired; attempting refresh", metadata: [
                "expiry": "\(expiry)",
            ])

            guard let refreshToken = creds.refreshToken else {
                Self.log.error("No refresh token available")
                throw GeminiStatusProbeError.notLoggedIn
            }

            accessToken = try await Self.refreshAccessToken(
                refreshToken: refreshToken,
                timeout: timeout,
                homeDirectory: homeDirectory,
                dataLoader: dataLoader)
        }

        // Discover the Gemini project ID for accurate quota data
        let projectId = try? await Self.discoverGeminiProjectId(
            accessToken: accessToken,
            timeout: timeout,
            dataLoader: dataLoader)

        guard let url = URL(string: Self.quotaEndpoint) else {
            throw GeminiStatusProbeError.apiError("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Include project ID if discovered for accurate quota
        if let projectId {
            request.httpBody = Data("{\"project\": \"\(projectId)\"}".utf8)
        } else {
            request.httpBody = Data("{}".utf8)
        }
        request.timeoutInterval = timeout

        let (data, response) = try await dataLoader(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiStatusProbeError.apiError("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw GeminiStatusProbeError.notLoggedIn
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiStatusProbeError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Extract account info from JWT
        let claims = Self.extractClaimsFromToken(creds.idToken)
        let snapshot = try Self.parseAPIResponse(data, email: claims.email)

        // Detect plan via loadCodeAssist API (most reliable method)
        let userTier = await Self.fetchUserTier(
            accessToken: accessToken,
            timeout: timeout,
            dataLoader: dataLoader)

        // Plan display strings with tier mapping:
        // - standard-tier: Paid subscription (AI Pro, AI Ultra, Code Assist
        //   Standard/Enterprise, Developer Program Premium)
        // - free-tier + hd claim: Workspace account (Gemini included free since Jan 2025)
        // - free-tier: Personal free account (1000 req/day limit)
        // - legacy-tier: Unknown legacy/grandfathered tier
        // - nil (API failed): Leave blank (no display)
        let plan: String? = switch (userTier, claims.hostedDomain) {
        case (.standard, _):
            "Paid"
        case let (.free, .some(domain)):
            { Self.log.info("Workspace account detected", metadata: ["domain": domain]); return "Workspace" }()
        case (.free, .none):
            { Self.log.info("Personal free account"); return "Free" }()
        case (.legacy, _):
            "Legacy"
        case (.none, _):
            { Self.log.info("Tier detection failed, leaving plan blank"); return nil }()
        }

        return GeminiStatusSnapshot(
            modelQuotas: snapshot.modelQuotas,
            rawText: snapshot.rawText,
            accountEmail: snapshot.accountEmail,
            accountPlan: plan)
    }

    private static func discoverGeminiProjectId(
        accessToken: String,
        timeout: TimeInterval,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async throws
        -> String?
    {
        guard let url = URL(string: projectsEndpoint) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        let (data, response) = try await dataLoader(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [[String: Any]]
        else {
            return nil
        }

        // Look for Gemini API project (has "generative-language" label or "gen-lang-client" prefix)
        for project in projects {
            guard let projectId = project["projectId"] as? String else { continue }

            // Check for gen-lang-client prefix (Gemini CLI projects)
            if projectId.hasPrefix("gen-lang-client") {
                return projectId
            }

            // Check for generative-language label
            if let labels = project["labels"] as? [String: String],
               labels["generative-language"] != nil
            {
                return projectId
            }
        }

        return nil
    }

    private static func fetchUserTier(
        accessToken: String,
        timeout: TimeInterval,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async -> GeminiUserTierId?
    {
        guard let url = URL(string: loadCodeAssistEndpoint) else {
            self.log.warning("loadCodeAssist: invalid endpoint URL")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{\"metadata\":{\"ideType\":\"GEMINI_CLI\",\"pluginType\":\"GEMINI\"}}".utf8)
        request.timeoutInterval = timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await dataLoader(request)
        } catch {
            Self.log.warning("loadCodeAssist: request failed", metadata: ["error": "\(error)"])
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            Self.log.warning("loadCodeAssist: invalid response type")
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            Self.log.warning("loadCodeAssist: HTTP error", metadata: [
                "statusCode": "\(httpResponse.statusCode)",
                "body": String(data: data, encoding: .utf8) ?? "<binary>",
            ])
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Self.log.warning("loadCodeAssist: failed to parse JSON", metadata: [
                "body": String(data: data, encoding: .utf8) ?? "<binary>",
            ])
            return nil
        }

        guard let currentTier = json["currentTier"] as? [String: Any],
              let tierId = currentTier["id"] as? String
        else {
            Self.log.warning("loadCodeAssist: no currentTier.id in response", metadata: [
                "json": "\(json)",
            ])
            return nil
        }

        guard let tier = GeminiUserTierId(rawValue: tierId) else {
            Self.log.warning("loadCodeAssist: unknown tier ID", metadata: ["tierId": tierId])
            return nil
        }

        Self.log.info("loadCodeAssist: tier detected", metadata: ["tier": tierId])
        return tier
    }

    private struct QuotaBucket: Decodable {
        let remainingFraction: Double?
        let resetTime: String?
        let modelId: String?
        let tokenType: String?
    }

    private struct QuotaResponse: Decodable {
        let buckets: [QuotaBucket]?
    }

    private static func parseAPIResponse(_ data: Data, email: String?) throws -> GeminiStatusSnapshot {
        let decoder = JSONDecoder()
        let response = try decoder.decode(QuotaResponse.self, from: data)

        guard let buckets = response.buckets, !buckets.isEmpty else {
            throw GeminiStatusProbeError.parseFailed("No quota buckets in response")
        }

        // Group quotas by model, keeping lowest per model (input tokens usually)
        var modelQuotaMap: [String: (fraction: Double, resetString: String?)] = [:]

        for bucket in buckets {
            guard let modelId = bucket.modelId, let fraction = bucket.remainingFraction else { continue }

            if let existing = modelQuotaMap[modelId] {
                if fraction < existing.fraction {
                    modelQuotaMap[modelId] = (fraction, bucket.resetTime)
                }
            } else {
                modelQuotaMap[modelId] = (fraction, bucket.resetTime)
            }
        }

        // Convert to sorted array (by model name for consistent ordering)
        let quotas = modelQuotaMap
            .sorted { $0.key < $1.key }
            .map { modelId, info in
                let resetDate = info.resetString.flatMap { Self.parseResetTime($0) }
                return GeminiModelQuota(
                    modelId: modelId,
                    percentLeft: info.fraction * 100,
                    resetTime: resetDate,
                    resetDescription: info.resetString.flatMap { Self.formatResetTime($0) })
            }

        let rawText = String(data: data, encoding: .utf8) ?? ""

        return GeminiStatusSnapshot(
            modelQuotas: quotas,
            rawText: rawText,
            accountEmail: email,
            accountPlan: nil)
    }

    private static func parseResetTime(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: isoString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString)
    }

    private static func formatResetTime(_ isoString: String) -> String {
        guard let resetDate = parseResetTime(isoString) else {
            return "Resets soon"
        }

        let now = Date()
        let interval = resetDate.timeIntervalSince(now)

        if interval <= 0 {
            return "Resets soon"
        }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    // MARK: - Legacy CLI parsing (kept for fallback)

    public static func parse(text: String) throws -> GeminiStatusSnapshot {
        let clean = TextParsing.stripANSICodes(text)
        guard !clean.isEmpty else { throw GeminiStatusProbeError.timedOut }

        let quotas = Self.parseModelUsageTable(clean)

        if quotas.isEmpty {
            if clean.contains("Login with Google") || clean.contains("Use Gemini API key") {
                throw GeminiStatusProbeError.notLoggedIn
            }
            if clean.contains("Waiting for auth"), !clean.contains("Usage") {
                throw GeminiStatusProbeError.notLoggedIn
            }
            throw GeminiStatusProbeError.parseFailed("No usage data found in /stats output")
        }

        return GeminiStatusSnapshot(
            modelQuotas: quotas,
            rawText: text,
            accountEmail: nil,
            accountPlan: nil)
    }

    private static func parseModelUsageTable(_ text: String) -> [GeminiModelQuota] {
        let lines = text.components(separatedBy: .newlines)
        var quotas: [GeminiModelQuota] = []

        let pattern = #"(gemini[-\w.]+)\s+[\d-]+\s+([0-9]+(?:\.[0-9]+)?)\s*%\s*\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        for line in lines {
            let cleanLine = line.replacingOccurrences(of: "│", with: " ")
            let range = NSRange(cleanLine.startIndex..<cleanLine.endIndex, in: cleanLine)
            guard let match = regex.firstMatch(in: cleanLine, options: [], range: range),
                  match.numberOfRanges >= 4 else { continue }

            guard let modelRange = Range(match.range(at: 1), in: cleanLine),
                  let pctRange = Range(match.range(at: 2), in: cleanLine),
                  let pct = Double(cleanLine[pctRange])
            else { continue }

            let modelId = String(cleanLine[modelRange])
            var resetDesc: String?
            if let resetRange = Range(match.range(at: 3), in: cleanLine) {
                resetDesc = String(cleanLine[resetRange]).trimmingCharacters(in: .whitespaces)
            }

            quotas.append(GeminiModelQuota(
                modelId: modelId,
                percentLeft: pct,
                resetTime: nil,
                resetDescription: resetDesc))
        }

        return quotas
    }
}
