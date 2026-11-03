import Foundation
#if os(macOS)
import Silo
#endif

/// The Claude Console credit balance and its grants.
///
/// No API key can read these: the Admin API has no balance endpoint and is
/// closed to individual accounts. The Console's billing page reads
/// `GET platform.claude.com/api/organizations/{org}/prepaid/credits` with its
/// login, and claude.ai's login gets a 403 for that org, so this needs its own
/// connection. The endpoint is undocumented: on any failure the card falls back
/// to the plan's monthly amount and Settings says why.
public enum ClaudeConsoleCredits {
    public enum Failure: LocalizedError, Sendable {
        /// `details` says what each browser answered, when one had a problem.
        case notSignedIn(details: String?)
        case sessionExpired
        case noConsoleOrganization
        case unexpectedReply(String)

        public var errorDescription: String? {
            switch self {
            case let .notSignedIn(details):
                "No Claude Console login found. Runic reads Chrome, Edge, Brave and Arc (allow the Keychain "
                    + "prompt when it appears). Sign in at platform.claude.com in one of them, then turn this on again."
                    + (details.map { "\n\n\($0)" } ?? "")
            case .sessionExpired:
                "The saved Claude Console login expired. Turn this off and on again to reconnect."
            case .noConsoleOrganization:
                "This login has no Claude Console organization, so there are no API credits to show."
            case let .unexpectedReply(details):
                "Claude Console sent an unexpected reply (\(details))."
            }
        }
    }

    private static let baseURL = "https://platform.claude.com/api/organizations"
    private static let session = SavedBrowserSession.claudeConsole

    private static let failureLock = NSLock()
    private nonisolated(unsafe) static var failure: String?

    /// Why the last fetch failed, for the settings status line.
    public static var lastFailure: String? {
        self.failureLock.withLock { self.failure }
    }

    private static func setLastFailure(_ message: String?) {
        self.failureLock.withLock { self.failure = message }
    }

    public static var isConnected: Bool {
        self.session.isConnected
    }

    public static func disconnect() {
        self.session.clear()
        self.setLastFailure(nil)
    }

    /// Settings action: read the Console login from the browser (the one read
    /// allowed to show the "Chrome Safe Storage" dialog), check it returns a
    /// balance, and keep Runic's own copy. Returns where it was found.
    public static func connect() async throws -> String {
        #if os(macOS)
        var trace: [String] = []
        let reads = ReadReports()
        let reporter: @Sendable (BrowserCookieReadReport) -> Void = { reads.add($0) }
        let candidates = BrowserCookieAccess.$allowsKeychainPrompt.withValue(true) {
            BrowserCookieAccess.$readReporter.withValue(reporter) {
                Self.browserSessions(trace: &trace)
            }
        }
        trace += reads.lines
        guard !candidates.isEmpty else {
            Self.recordConnectTrace(trace, outcome: "no candidates")
            let problems = trace.filter { $0.contains(": failed: ") && !$0.contains("not found") }
            throw Failure.notSignedIn(details: problems.isEmpty ? nil : problems.joined(separator: "\n"))
        }
        var lastError: Error = Failure.notSignedIn(details: nil)
        for candidate in candidates {
            do {
                _ = try await Self.fetch(cookieHeader: candidate.cookieHeader)
                Self.session.store(candidate.cookieHeader)
                Self.setLastFailure(nil)
                Self.recordConnectTrace(trace, outcome: "connected via \(candidate.source)")
                return candidate.source
            } catch {
                trace.append("\(candidate.source): \(error.localizedDescription)")
                lastError = error
            }
        }
        Self.recordConnectTrace(trace, outcome: "every candidate failed")
        throw lastError
        #else
        throw Failure.notSignedIn(details: nil)
        #endif
    }

    /// Whether a cookie is one a browser would send to platform.claude.com, as
    /// opposed to the docs or support sites.
    public static func isConsoleCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
        return domain == "claude.com" || domain == "platform.claude.com"
    }

    /// Settings action for a login made inside Runic: keep these cookies if the
    /// Console accepts them. False while the page is still signed out.
    public static func connect(cookies: [HTTPCookie]) async -> Bool {
        let kept = cookies.filter(Self.isConsoleCookie)
        guard !kept.isEmpty else { return false }
        let header = kept.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        guard await (try? Self.fetch(cookieHeader: header)) != nil else { return false }
        Self.session.store(header)
        Self.setLastFailure(nil)
        return true
    }

    /// Adds the credits to a snapshot. Best effort: the usage still shows when
    /// this fails. Saved login only, never the browser, never a prompt.
    static func attach(to snapshot: ClaudeUsageSnapshot) async -> ClaudeUsageSnapshot {
        guard let cookieHeader = self.session.load() else { return snapshot }
        do {
            let credits = try await self.fetch(cookieHeader: cookieHeader)
            self.setLastFailure(nil)
            return snapshot.with(apiCredits: credits)
        } catch {
            self.setLastFailure(error.localizedDescription)
            return snapshot
        }
    }

    private static func fetch(cookieHeader: String) async throws -> ProviderAPICredits {
        let organizations = try await self.get(self.baseURL, cookieHeader: cookieHeader)
        guard let organization = self.consoleOrganizationID(organizations) else {
            throw Failure.noConsoleOrganization
        }
        let reply = try await self.get("\(self.baseURL)/\(organization)/prepaid/credits", cookieHeader: cookieHeader)
        guard let credits = self.parseCredits(reply) else {
            throw Failure.unexpectedReply("no balance")
        }
        return credits
    }

    private static func get(_ address: String, cookieHeader: String) async throws -> Data {
        guard let url = URL(string: address) else { throw Failure.unexpectedReply("bad address") }
        var request = URLRequest(url: url)
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (data, response) = try await ProviderRequestSession.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return data
        case 401, 403: throw Failure.sessionExpired
        default: throw Failure.unexpectedReply("HTTP \(status)")
        }
    }

    /// A login can hold a chat org and a Console org; credits live on the one
    /// with the "api" capability. The chat org answers 403.
    static func consoleOrganizationID(_ data: Data) -> String? {
        struct Organization: Decodable {
            let uuid: String?
            let capabilities: [String]?
        }
        let organizations = (try? JSONDecoder().decode([Organization].self, from: data)) ?? []
        return organizations.first { ($0.capabilities ?? []).contains("api") }?.uuid
    }

    static func parseCredits(_ data: Data) -> ProviderAPICredits? {
        struct Tranche: Decodable {
            let name: String?
            let currency: String?
            let remainingMinor: Double?
            let grantedMinor: Double?
            let expiresAt: String?

            private enum CodingKeys: String, CodingKey {
                case name
                case currency
                case remainingMinor = "remaining_amount_minor_units"
                case grantedMinor = "granted_amount_minor_units"
                case expiresAt = "expires_at"
            }
        }
        struct Reply: Decodable {
            struct Balance: Decodable {
                let money: ClaudeMoney?
                let credits: ClaudeMoney?
            }

            let currency: String?
            let balance: Balance?
            let tranches: [Tranche]?
            let promoTranches: [Tranche]?

            private enum CodingKeys: String, CodingKey {
                case currency
                case balance
                case tranches
                case promoTranches = "promo_tranches"
            }
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data),
              let available = reply.balance?.money ?? reply.balance?.credits
        else { return nil }
        let grants = ((reply.promoTranches ?? []) + (reply.tranches ?? [])).compactMap { tranche
            -> ProviderAPICredits.Grant? in
            guard let remaining = tranche.remainingMinor else { return nil }
            return ProviderAPICredits.Grant(
                name: tranche.name,
                remaining: remaining / 100,
                granted: tranche.grantedMinor.map { $0 / 100 },
                expiresAt: ClaudeOAuthUsageFetcher.parseISO8601Date(tranche.expiresAt))
        }
        return ProviderAPICredits(
            available: available.value,
            currencyCode: available.currency ?? reply.currency ?? "USD",
            grants: grants)
    }

    #if os(macOS)
    /// Summaries of each database read, keeping only Claude's hosts: the
    /// rest of the host table is browsing data and stays out of the file.
    private final class ReadReports: @unchecked Sendable {
        private let lock = NSLock()
        private var collected: [String] = []

        func add(_ report: BrowserCookieReadReport) {
            let claude = report.hosts
                .filter { $0.key.contains("claude") }
                .sorted { $0.key < $1.key }
                .map { "\($0.key) \($0.value.failed)/\($0.value.rows) failed" }
                .joined(separator: ", ")
            let line = "\(report.store): \(report.rows) rows, \(report.encrypted) encrypted, "
                + "\(report.failed) failed, formats \(report.prefixes), failed formats \(report.failedPrefixes); "
                + "Claude hosts: \(claude.isEmpty ? "none" : claude)"
            self.lock.withLock { self.collected.append(line) }
        }

        var lines: [String] {
            self.lock.withLock { self.collected }
        }
    }

    private struct BrowserSession {
        let cookieHeader: String
        let source: String
    }

    /// One candidate per browser profile holding Console cookies. Whether a
    /// profile is signed in is settled by asking the Console, not by cookie name.
    private static func browserSessions(trace: inout [String]) -> [BrowserSession] {
        let client = BrowserCookieClient()
        let order = ProviderDefaults.metadata[.claude]?.browserCookieOrder ?? Browser.defaultImportOrder
        var sessions: [BrowserSession] = []
        for browser in order {
            let query = BrowserCookieQuery(domains: ["claude.com"])
            let sources: [BrowserCookieStoreRecords]
            do {
                sources = try client.records(matching: query, in: browser)
            } catch {
                trace.append("\(browser.displayName): failed: \(error.localizedDescription)")
                continue
            }
            if sources.allSatisfy(\.records.isEmpty) {
                trace.append("\(browser.displayName): no claude.com cookies readable")
            }
            for source in sources where !source.records.isEmpty {
                let cookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
                    .filter(Self.isConsoleCookie)
                // Names only, never values: enough to spot a renamed login cookie.
                let names = Set(cookies.map(\.name)).sorted().joined(separator: ", ")
                trace.append("\(source.label): \(source.records.count) claude.com, \(cookies.count) kept (\(names))")
                guard !cookies.isEmpty else { continue }
                sessions.append(BrowserSession(
                    cookieHeader: cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "),
                    source: source.label))
            }
        }
        return sessions
    }

    /// The unified log redacts its messages, so keep the last connect attempt
    /// in `diagnostics/`. Browser names, counts and cookie names; no values.
    private static func recordConnectTrace(_ trace: [String], outcome: String) {
        let report: [String: Any] = [
            "at": ISO8601DateFormatter().string(from: Date()),
            "outcome": outcome,
            "trace": trace,
        ]
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Runic/diagnostics", isDirectory: true),
            let json = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? json.write(to: directory.appendingPathComponent("claude-console-connect.json"), options: .atomic)
    }
    #endif
}
