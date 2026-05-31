import Foundation
import Silo

#if os(macOS)

let factoryCookieImportOrder: BrowserCookieImportOrder =
    ProviderDefaults.metadata[.factory]?.browserCookieOrder ?? Browser.defaultImportOrder

// MARK: - Factory Cookie Importer

/// Imports Factory session cookies from browser cookies.
public enum FactoryCookieImporter {
    private static let cookieClient = BrowserCookieClient()
    private static let sessionCookieNames: Set<String> = [
        "wos-session",
        "__Secure-next-auth.session-token",
        "next-auth.session-token",
        "__Secure-authjs.session-token",
        "__Host-authjs.csrf-token",
        "authjs.session-token",
        "session",
        "access-token",
    ]

    private static let authSessionCookieNames: Set<String> = [
        "__Secure-next-auth.session-token",
        "next-auth.session-token",
        "__Secure-authjs.session-token",
        "authjs.session-token",
    ]

    public struct SessionInfo: Sendable {
        public let cookies: [HTTPCookie]
        public let sourceLabel: String

        public init(cookies: [HTTPCookie], sourceLabel: String) {
            self.cookies = cookies
            self.sourceLabel = sourceLabel
        }

        public var cookieHeader: String {
            self.cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        }
    }

    /// Returns all Factory sessions across supported browsers.
    public static func importSessions(logger: ((String) -> Void)? = nil) throws -> [SessionInfo] {
        let log: (String) -> Void = { msg in logger?("[factory-cookie] \(msg)") }
        var sessions: [SessionInfo] = []

        for browserSource in factoryCookieImportOrder {
            do {
                let perSource = try self.importSessions(from: browserSource, logger: logger)
                sessions.append(contentsOf: perSource)
            } catch {
                log("\(browserSource.displayName) cookie import failed: \(error.localizedDescription)")
            }
        }

        guard !sessions.isEmpty else {
            throw FactoryStatusProbeError.noSessionCookie
        }
        return sessions
    }

    public static func importSessions(
        from browserSource: Browser,
        logger: ((String) -> Void)? = nil) throws -> [SessionInfo]
    {
        let log: (String) -> Void = { msg in logger?("[factory-cookie] \(msg)") }
        let cookieDomains = ["factory.ai", "app.factory.ai", "auth.factory.ai"]
        let query = BrowserCookieQuery(domains: cookieDomains)
        let sources = try Self.cookieClient.records(
            matching: query,
            in: browserSource)

        var sessions: [SessionInfo] = []
        for source in sources where !source.records.isEmpty {
            let httpCookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
            if httpCookies.contains(where: { Self.sessionCookieNames.contains($0.name) }) {
                log("Found \(httpCookies.count) Factory cookies in \(source.label)")
                log("\(source.label) cookie names: \(self.cookieNames(from: httpCookies))")
                if let token = httpCookies.first(where: { $0.name == "access-token" })?.value {
                    let hint = token.contains(".") ? "jwt" : "opaque"
                    log("\(source.label) access-token cookie: \(token.count) chars (\(hint))")
                }
                if let token = httpCookies.first(where: { self.authSessionCookieNames.contains($0.name) })?.value {
                    let hint = token.contains(".") ? "jwt" : "opaque"
                    log("\(source.label) session cookie: \(token.count) chars (\(hint))")
                }
                sessions.append(SessionInfo(cookies: httpCookies, sourceLabel: source.label))
            } else {
                log("\(source.label) cookies found, but no Factory session cookie present")
            }
        }
        return sessions
    }

    /// Attempts to import Factory cookies using the standard browser import order.
    public static func importSession(logger: ((String) -> Void)? = nil) throws -> SessionInfo {
        let sessions = try self.importSessions(logger: logger)
        guard let first = sessions.first else {
            throw FactoryStatusProbeError.noSessionCookie
        }
        return first
    }

    /// Check if Factory session cookies are available
    public static func hasSession(logger: ((String) -> Void)? = nil) -> Bool {
        do {
            return try !(self.importSessions(logger: logger)).isEmpty
        } catch {
            return false
        }
    }

    private static func cookieNames(from cookies: [HTTPCookie]) -> String {
        let names = Set(cookies.map { "\($0.name)@\($0.domain)" }).sorted()
        return names.joined(separator: ", ")
    }
}

#endif
