import Foundation
import Silo

/// Fetches Claude usage data directly from the claude.ai API using browser session cookies.
///
/// This approach mirrors what Claude Usage Tracker does, but automatically extracts the session key
/// from browser cookies instead of requiring manual setup.
///
/// API endpoints used:
/// - `GET https://claude.ai/api/organizations` → get org UUID
/// - `GET https://claude.ai/api/organizations/{org_id}/usage` → usage percentages + reset times
public enum ClaudeWebAPIFetcher {
    static let baseURL = "https://claude.ai/api"
    static let maxProbeBytes = 200_000

    #if os(macOS)
    private static let cookieClient = BrowserCookieClient()
    private static let cookieImportOrder: BrowserCookieImportOrder =
        ProviderDefaults.metadata[.claude]?.browserCookieOrder ?? Browser.defaultImportOrder
    #endif

    // MARK: - Public API

    #if os(macOS)

    /// Attempts to fetch Claude usage data using cookies extracted from browsers.
    /// Tries browser cookies using the standard import order.
    public static func fetchUsage(logger: ((String) -> Void)? = nil) async throws -> WebUsageData {
        let log: (String) -> Void = { msg in logger?("[claude-web] \(msg)") }

        let sessionInfo = try extractSessionKeyInfo(logger: log)
        log("Found session key: \(sessionInfo.key.prefix(20))...")

        return try await self.fetchUsage(using: sessionInfo, logger: log)
    }

    public static func fetchUsage(
        using sessionKeyInfo: SessionKeyInfo,
        logger: ((String) -> Void)? = nil) async throws -> WebUsageData
    {
        let log: (String) -> Void = { msg in logger?(msg) }
        let sessionKey = sessionKeyInfo.key

        // Fetch organization info
        let organization = try await fetchOrganizationInfo(sessionKey: sessionKey, logger: log)
        log("Organization ID: \(organization.id)")
        if let name = organization.name { log("Organization name: \(name)") }

        var usage = try await fetchUsageData(orgId: organization.id, sessionKey: sessionKey, logger: log)
        if usage.extraUsageCost == nil,
           let extra = await fetchExtraUsageCost(orgId: organization.id, sessionKey: sessionKey, logger: log)
        {
            usage = WebUsageData(
                sessionPercentUsed: usage.sessionPercentUsed,
                sessionResetsAt: usage.sessionResetsAt,
                weeklyPercentUsed: usage.weeklyPercentUsed,
                weeklyResetsAt: usage.weeklyResetsAt,
                opusPercentUsed: usage.opusPercentUsed,
                extraUsageCost: extra,
                accountOrganization: usage.accountOrganization,
                accountEmail: usage.accountEmail,
                loginMethod: usage.loginMethod)
        }
        if let account = await fetchAccountInfo(sessionKey: sessionKey, orgId: organization.id, logger: log) {
            usage = WebUsageData(
                sessionPercentUsed: usage.sessionPercentUsed,
                sessionResetsAt: usage.sessionResetsAt,
                weeklyPercentUsed: usage.weeklyPercentUsed,
                weeklyResetsAt: usage.weeklyResetsAt,
                opusPercentUsed: usage.opusPercentUsed,
                extraUsageCost: usage.extraUsageCost,
                accountOrganization: usage.accountOrganization,
                accountEmail: account.email,
                loginMethod: account.loginMethod)
        }
        if usage.accountOrganization == nil, let name = organization.name {
            usage = WebUsageData(
                sessionPercentUsed: usage.sessionPercentUsed,
                sessionResetsAt: usage.sessionResetsAt,
                weeklyPercentUsed: usage.weeklyPercentUsed,
                weeklyResetsAt: usage.weeklyResetsAt,
                opusPercentUsed: usage.opusPercentUsed,
                extraUsageCost: usage.extraUsageCost,
                accountOrganization: name,
                accountEmail: usage.accountEmail,
                loginMethod: usage.loginMethod)
        }
        return usage
    }

    /// Checks if we can find a Claude session key in browser cookies without making API calls.
    public static func hasSessionKey(logger: ((String) -> Void)? = nil) -> Bool {
        do {
            _ = try self.sessionKeyInfo(logger: logger)
            return true
        } catch {
            return false
        }
    }

    public static func sessionKeyInfo(logger: ((String) -> Void)? = nil) throws -> SessionKeyInfo {
        try self.extractSessionKeyInfo(logger: logger)
    }

    // MARK: - Session Key Extraction

    static func extractSessionKeyInfo(logger: ((String) -> Void)? = nil) throws -> SessionKeyInfo {
        let log: (String) -> Void = { msg in logger?(msg) }

        let cookieDomains = ["claude.ai"]

        for browserSource in Self.cookieImportOrder {
            do {
                let query = BrowserCookieQuery(domains: cookieDomains)
                let sources = try Self.cookieClient.records(
                    matching: query,
                    in: browserSource)
                for source in sources {
                    if let sessionKey = findSessionKey(in: source.records.map { record in
                        (name: record.name, value: record.value)
                    }) {
                        log("Found sessionKey in \(source.label)")
                        return SessionKeyInfo(
                            key: sessionKey,
                            sourceLabel: source.label,
                            cookieCount: source.records.count)
                    }
                }
            } catch {
                log("\(browserSource.displayName) cookie load failed: \(error.localizedDescription)")
            }
        }

        throw FetchError.noSessionKeyFound
    }

    private static func findSessionKey(in cookies: [(name: String, value: String)]) -> String? {
        for cookie in cookies where cookie.name == "sessionKey" {
            let value = cookie.value.trimmingCharacters(in: .whitespacesAndNewlines)
            // Validate it looks like a Claude session key
            if value.hasPrefix("sk-ant-") {
                return value
            }
        }
        return nil
    }

    #else

    public static func fetchUsage(logger: ((String) -> Void)? = nil) async throws -> WebUsageData {
        throw FetchError.notSupportedOnThisPlatform
    }

    public static func fetchUsage(
        using sessionKeyInfo: SessionKeyInfo,
        logger: ((String) -> Void)? = nil) async throws -> WebUsageData
    {
        throw FetchError.notSupportedOnThisPlatform
    }

    public static func probeEndpoints(
        _ endpoints: [String],
        includePreview: Bool = false,
        logger: ((String) -> Void)? = nil) async throws -> [ProbeResult]
    {
        throw FetchError.notSupportedOnThisPlatform
    }

    public static func hasSessionKey(logger: ((String) -> Void)? = nil) -> Bool {
        false
    }

    public static func sessionKeyInfo(logger: ((String) -> Void)? = nil) throws -> SessionKeyInfo {
        throw FetchError.notSupportedOnThisPlatform
    }

    #endif
}
