import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension GeminiStatusProbe {
    static func fetchViaAPI(
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
        var didRefresh = false
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
            didRefresh = true
        }

        func performQuotaRequest(token: String) async throws -> (Data, HTTPURLResponse) {
            // Discover the Gemini project ID for accurate quota data
            let projectId = try? await Self.discoverGeminiProjectId(
                accessToken: token,
                timeout: timeout,
                dataLoader: dataLoader)

            guard let url = URL(string: Self.quotaEndpoint) else {
                throw GeminiStatusProbeError.apiError("Invalid endpoint URL")
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Include project ID if discovered for accurate quota
            if let projectId {
                request.httpBody = Data("{\"project\": \"\(projectId)\"}".utf8)
            } else {
                request.httpBody = Data("{}".utf8)
            }
            request.timeoutInterval = timeout

            let (responseData, response) = try await dataLoader(request)
            guard let http = response as? HTTPURLResponse else {
                throw GeminiStatusProbeError.apiError("Invalid response")
            }
            return (responseData, http)
        }

        var (data, httpResponse) = try await performQuotaRequest(token: accessToken)

        if httpResponse.statusCode == 401, !didRefresh, let refreshToken = creds.refreshToken {
            Self.log.info("Quota request returned 401; attempting token refresh")
            accessToken = try await Self.refreshAccessToken(
                refreshToken: refreshToken,
                timeout: timeout,
                homeDirectory: homeDirectory,
                dataLoader: dataLoader)
            (data, httpResponse) = try await performQuotaRequest(token: accessToken)
        }

        if httpResponse.statusCode == 401 {
            throw GeminiStatusProbeError.notLoggedIn
        }

        if httpResponse.statusCode == 403 {
            let message = await Self.describeForbiddenError(
                responseData: data,
                accessToken: accessToken,
                timeout: timeout,
                dataLoader: dataLoader)
            throw GeminiStatusProbeError.apiError(message)
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiStatusProbeError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Extract account info from JWT
        let claims = Self.extractClaimsFromToken(creds.idToken)
        let snapshot = try Self.parseAPIResponse(data, email: claims.email)

        // Detect plan via loadCodeAssist API (paidTier reflects Google AI Ultra/Pro even when
        // currentTier reports standard-tier or free-tier).
        let plan = await Self.fetchAccountPlan(
            accessToken: accessToken,
            hostedDomain: claims.hostedDomain,
            timeout: timeout,
            dataLoader: dataLoader)

        return GeminiStatusSnapshot(
            modelQuotas: snapshot.modelQuotas,
            rawText: snapshot.rawText,
            accountEmail: snapshot.accountEmail,
            accountPlan: plan)
    }

    static func discoverGeminiProjectId(
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

    struct GeminiTierDescriptor: Equatable {
        let id: String?
        let name: String?
    }

    public static func resolvePlan(from json: [String: Any], hostedDomain: String?) -> String? {
        let paidTier = Self.tierDescriptor(from: json["paidTier"] as? [String: Any])
        let currentTier = Self.tierDescriptor(from: json["currentTier"] as? [String: Any])

        if let paidTier,
           let resolved = Self.planName(for: paidTier, hostedDomain: hostedDomain, isPaidTier: true)
        {
            return resolved
        }
        if let currentTier,
           let resolved = Self.planName(for: currentTier, hostedDomain: hostedDomain, isPaidTier: false)
        {
            return resolved
        }
        return nil
    }

    private static func tierDescriptor(from raw: [String: Any]?) -> GeminiTierDescriptor? {
        guard let raw else { return nil }
        let id = (raw["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (raw["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (id?.isEmpty == false) || (name?.isEmpty == false) else { return nil }
        return GeminiTierDescriptor(
            id: id?.isEmpty == false ? id : nil,
            name: name?.isEmpty == false ? name : nil)
    }

    private static func planName(
        for descriptor: GeminiTierDescriptor,
        hostedDomain: String?,
        isPaidTier: Bool) -> String?
    {
        let tierId = descriptor.id?.lowercased() ?? ""
        let tierName = descriptor.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lowerName = tierName.lowercased()

        if tierId == GeminiUserTierId.g1Ultra.rawValue || lowerName.contains("ultra") {
            return "Google AI Ultra"
        }
        if tierId == GeminiUserTierId.g1Pro.rawValue || lowerName.contains("ai pro") || lowerName.contains("one pro") {
            return "Google AI Pro"
        }
        if lowerName.contains("enterprise") {
            return "Enterprise"
        }
        if tierId == GeminiUserTierId.standard.rawValue {
            if lowerName.contains("pro") { return "Google AI Pro" }
            return "Paid"
        }
        if tierId == GeminiUserTierId.free.rawValue {
            if isPaidTier { return nil }
            if let domain = hostedDomain, !domain.isEmpty {
                Self.log.info("Workspace account detected", metadata: ["domain": domain])
                return "Workspace"
            }
            Self.log.info("Personal free account")
            return "Free"
        }
        if tierId == GeminiUserTierId.legacy.rawValue {
            return "Legacy"
        }
        if !tierName.isEmpty {
            return tierName
        }
        return nil
    }

    static func fetchAccountPlan(
        accessToken: String,
        hostedDomain: String?,
        timeout: TimeInterval,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async -> String?
    {
        guard let json = await postLoadCodeAssist(
            accessToken: accessToken,
            timeout: timeout,
            dataLoader: dataLoader)
        else { return nil }

        if let resolved = Self.resolvePlan(from: json, hostedDomain: hostedDomain) {
            Self.log.info("loadCodeAssist: plan resolved", metadata: ["plan": resolved])
            return resolved
        }

        Self.log.warning("loadCodeAssist: no tier metadata in response", metadata: [
            "json": "\(json)",
        ])
        return nil
    }

    static func fetchUserTier(
        accessToken: String,
        timeout: TimeInterval,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async -> GeminiUserTierId?
    {
        guard let json = await postLoadCodeAssist(
            accessToken: accessToken,
            timeout: timeout,
            dataLoader: dataLoader)
        else { return nil }

        let tierId = ((json["paidTier"] as? [String: Any])?["id"] as? String)
            ?? ((json["currentTier"] as? [String: Any])?["id"] as? String)
        guard let tierId else {
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

    private static func describeForbiddenError(
        responseData: Data,
        accessToken: String,
        timeout: TimeInterval,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async -> String
    {
        if let json = await postLoadCodeAssist(
            accessToken: accessToken,
            timeout: timeout,
            dataLoader: dataLoader),
            let ineligible = json["ineligibleTiers"] as? [[String: Any]],
            ineligible.contains(where: { ($0["reasonCode"] as? String) == "UNSUPPORTED_CLIENT" })
        {
            return "Google deprecated personal Gemini CLI OAuth; use Antigravity for Google AI Pro/Ultra quotas."
        }

        if let rawBody = String(data: responseData, encoding: .utf8),
           rawBody.contains("SUBSCRIPTION_REQUIRED")
        {
            return "Gemini Code Assist license required (HTTP 403). For Google AI Pro/Ultra, use Antigravity."
        }

        return "HTTP 403"
    }

    private static func postLoadCodeAssist(
        accessToken: String,
        timeout: TimeInterval,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async -> [String: Any]?
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

        return json
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

    static func parseAPIResponse(_ data: Data, email: String?) throws -> GeminiStatusSnapshot {
        let decoder = JSONDecoder()
        guard let response = try? decoder.decode(QuotaResponse.self, from: data) else {
            throw GeminiStatusProbeError.parseFailed("Invalid quota response")
        }

        let buckets = response.buckets ?? []

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

    static func parseResetTime(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: isoString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString)
    }

    static func formatResetTime(_ isoString: String) -> String {
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
}
