import Foundation
import Silo

/// The balance moved off the public API when SiliconFlow retired `/v1/user/info`
/// (410, code 20092), but the console still reads it from
/// `cloud.siliconflow.{com,cn}/biz-server/api/v1/user/info` with the browser's
/// login cookie (`__SF_auth.session-token`), optionally scoped by the account's
/// subject ID in `X-Subject-ID`. The reply keeps the old `{code, status,
/// data:{balance, chargeBalance, totalBalance, status}}` shape.
struct SiliconFlowBalanceResponse: Decodable {
    let code: Int?
    let status: Bool?
    let data: Info?

    struct Info: Decodable {
        let balance: Double?
        let chargeBalance: Double?
        let totalBalance: Double?
        let status: String?

        private enum CodingKeys: String, CodingKey {
            case balance, chargeBalance, totalBalance, status
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.balance = Self.amount(c, .balance)
            self.chargeBalance = Self.amount(c, .chargeBalance)
            self.totalBalance = Self.amount(c, .totalBalance)
            self.status = try? c.decodeIfPresent(String.self, forKey: .status)
        }

        private static func amount(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
            if let number = try? c.decodeIfPresent(Double.self, forKey: key) { return number }
            guard let raw = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
            return Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// The console answers 200 with `code != 20000` when the session or subject
    /// is wrong, so success is judged by the envelope, not the status code.
    var hasBalance: Bool {
        guard let data = self.data else { return false }
        let envelopeOK = (self.code == nil || self.code == 20000) && self.status != false
        return envelopeOK && (data.totalBalance != nil || data.balance != nil || data.chargeBalance != nil)
    }

    /// `totalBalance` = granted + topped-up; fall back to the parts if absent.
    var remainingBalance: Double {
        guard let info = self.data else { return 0 }
        return info.totalBalance ?? ((info.balance ?? 0) + (info.chargeBalance ?? 0))
    }

    func toUsageSnapshot(currency: String) -> UsageSnapshot {
        // No limit is exposed, so the window is limit-less (see DeepSeek).
        UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: \(String(format: "%.2f", self.remainingBalance)) \(currency)",
                hasKnownLimit: false),
            secondary: nil,
            tertiary: nil,
            balance: ProviderBalance(
                available: self.remainingBalance,
                currency: currency,
                components: [
                    self.data?.chargeBalance.map { .init(label: "Paid", amount: $0) },
                    self.data?.balance.map { .init(label: "Bonus", amount: $0) },
                ].compactMap(\.self),
                apiCallsAllowed: self.data?.status.map { $0.lowercased() == "normal" }),
            updatedAt: Date(),
            identity: nil)
    }

    func toCreditsSnapshot() -> CreditsSnapshot {
        CreditsSnapshot(remaining: self.remainingBalance, events: [], updatedAt: Date())
    }
}

enum SiliconFlowConsoleError: LocalizedError, Equatable {
    case notSignedIn(china: Bool)
    case needsSubjectID(china: Bool)
    case notConnected(china: Bool)
    case sessionExpired(china: Bool)
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case let .notSignedIn(china):
            "No \(SiliconFlowConsole.host(china: china)) sign-in found in Safari, Chrome, Edge, Brave or Arc. " +
                "Sign in there, then connect again (allow the Keychain prompt)."
        case let .notConnected(china):
            "Balance needs your SiliconFlow sign-in: turn on “Balance from browser sign-in” in " +
                "Settings → Providers → \(china ? "SiliconFlow (China)" : "SiliconFlow")."
        case let .sessionExpired(china):
            "The saved \(SiliconFlowConsole.host(china: china)) sign-in expired. Sign in again in your browser, " +
                "then turn “Balance from browser sign-in” off and on."
        case let .needsSubjectID(china):
            "Signed in to SiliconFlow, but the console also wants your user ID " +
                "(avatar menu, top right of the console). Export " +
                "\(china ? "SILICONFLOW_CN_SUBJECT_ID" : "SILICONFLOW_SUBJECT_ID") with it."
        case let .httpError(statusCode):
            "SiliconFlow console returned status code \(statusCode)."
        }
    }
}

enum SiliconFlowConsole {
    static func host(china: Bool) -> String {
        china ? "cloud.siliconflow.cn" : "cloud.siliconflow.com"
    }

    /// Subject IDs to try, in order: explicit env value, a subject-looking
    /// cookie, then none at all. Blanks and duplicates are dropped.
    static func subjectCandidates(environment: String?, cookie: String?) -> [String?] {
        var result: [String?] = []
        for raw in [environment, cookie] {
            guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
                  !result.contains(value) else { continue }
            result.append(value)
        }
        result.append(nil)
        return result
    }

    /// First value in a `Cookie:` header whose name passes `matches`.
    static func cookieValue(in header: String, where matches: (String) -> Bool) -> String? {
        for pair in header.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            if matches(name) { return String(parts[1]).trimmingCharacters(in: .whitespaces) }
        }
        return nil
    }
}

/// What the last console attempt saw, without any cookie or ID values: which
/// browsers held a SiliconFlow session, and per request the HTTP status, the
/// final host and the reply envelope. Written to
/// `diagnostics/siliconflow-console[-cn].json`; the last failure is also
/// appended to the API-key tile, so a silent fallback says why.
final class SiliconFlowConsoleTrace: @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var lastFailureByRegion: [Bool: String] = [:]

    private(set) var lines: [String] = []
    private var requests: [[String: Any]] = []

    func note(_ line: String) {
        self.lines.append(line)
    }

    // swiftlint:disable:next function_parameter_count
    func request(source: String, subject: String, status: Int, host: String?, code: Int?, message: String?) {
        var entry: [String: Any] = ["source": source, "subject": subject, "httpStatus": status]
        if let host { entry["finalHost"] = host }
        if let code { entry["code"] = code }
        if let message { entry["message"] = String(message.prefix(200)) }
        self.requests.append(entry)
    }

    func finish(china: Bool, failure: String?) {
        Self.lock.withLock { Self.lastFailureByRegion[china] = failure }
        var report: [String: Any] = [
            "at": ISO8601DateFormatter().string(from: Date()),
            "host": SiliconFlowConsole.host(china: china),
            "browsers": self.lines,
            "requests": self.requests,
        ]
        if let failure { report["failure"] = failure }
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Runic/diagnostics", isDirectory: true),
            let json = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = china ? "siliconflow-console-cn.json" : "siliconflow-console.json"
        try? json.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    static func lastFailure(china: Bool) -> String? {
        self.lock.withLock { self.lastFailureByRegion[china] }
    }
}

#if os(macOS)
public enum SiliconFlowConsoleFetcher {
    static func savedSession(china: Bool) -> SavedBrowserSession {
        china ? .siliconFlowCN : .siliconFlow
    }

    /// Settings action: read the SiliconFlow login from the browser (the one
    /// read allowed to show the "Chrome Safe Storage" Keychain dialog), check it
    /// returns a balance, and keep Runic's own copy. Returns where it was found.
    public static func connect(china: Bool, environment: [String: String]) async throws -> String {
        let trace = SiliconFlowConsoleTrace()
        do {
            let sessions = BrowserCookieAccess.$allowsKeychainPrompt.withValue(true) {
                SiliconFlowCookieImporter.importSessions(china: china) { trace.note($0) }
            }
            guard !sessions.isEmpty else { throw SiliconFlowConsoleError.notSignedIn(china: china) }
            let (_, session) = try await self.firstBalance(
                sessions: sessions,
                china: china,
                environment: environment,
                trace: trace)
            self.savedSession(china: china).store(session.cookieHeader)
            trace.finish(china: china, failure: nil)
            return session.sourceLabel
        } catch {
            trace.finish(china: china, failure: error.localizedDescription)
            throw error
        }
    }

    public static func disconnect(china: Bool) {
        self.savedSession(china: china).clear()
    }

    public static func isConnected(china: Bool) -> Bool {
        self.savedSession(china: china).isConnected
    }

    /// Refresh path: the saved sign-in only, never the browser, never a prompt.
    static func fetchBalance(
        china: Bool,
        environment: [String: String]) async throws -> SiliconFlowBalanceResponse
    {
        let trace = SiliconFlowConsoleTrace()
        do {
            guard let cookieHeader = self.savedSession(china: china).load() else {
                throw SiliconFlowConsoleError.notConnected(china: china)
            }
            let session = SiliconFlowCookieSession(cookieHeader: cookieHeader, sourceLabel: "saved sign-in")
            do {
                let (response, _) = try await self.firstBalance(
                    sessions: [session],
                    china: china,
                    environment: environment,
                    trace: trace)
                trace.finish(china: china, failure: nil)
                return response
            } catch SiliconFlowConsoleError.notSignedIn {
                throw SiliconFlowConsoleError.sessionExpired(china: china)
            }
        } catch {
            trace.finish(china: china, failure: error.localizedDescription)
            throw error
        }
    }

    private static func firstBalance(
        sessions: [SiliconFlowCookieSession],
        china: Bool,
        environment: [String: String],
        trace: SiliconFlowConsoleTrace) async throws -> (SiliconFlowBalanceResponse, SiliconFlowCookieSession)
    {
        let envSubject = environment[china ? "SILICONFLOW_CN_SUBJECT_ID" : "SILICONFLOW_SUBJECT_ID"]

        var sawSignedIn = false
        sessionLoop: for session in sessions {
            let subjects = SiliconFlowConsole.subjectCandidates(
                environment: envSubject,
                cookie: session.subjectCookie)
            for subject in subjects {
                let subjectSource = subject == nil ? "none"
                    : subject == envSubject?.trimmingCharacters(in: .whitespacesAndNewlines) ? "env" : "cookie"
                let outcome = try await self.request(
                    china: china,
                    cookieHeader: session.cookieHeader,
                    subject: subject)
                { status, host, code, message in
                    trace.request(
                        source: session.sourceLabel,
                        subject: subjectSource,
                        status: status,
                        host: host,
                        code: code,
                        message: message)
                }
                switch outcome {
                case let .balance(response):
                    return (response, session)
                case .signedInWithoutBalance:
                    sawSignedIn = true
                case .signedOut:
                    continue sessionLoop
                }
            }
        }
        throw sawSignedIn
            ? SiliconFlowConsoleError.needsSubjectID(china: china)
            : SiliconFlowConsoleError.notSignedIn(china: china)
    }

    private enum Outcome {
        case balance(SiliconFlowBalanceResponse)
        case signedInWithoutBalance
        case signedOut
    }

    private struct Envelope: Decodable {
        let code: Int?
        let message: String?
    }

    private static func request(
        china: Bool,
        cookieHeader: String,
        subject: String?,
        record: (Int, String?, Int?, String?) -> Void) async throws -> Outcome
    {
        let (outcome, status, host, data) = try await self.send(
            china: china,
            cookieHeader: cookieHeader,
            subject: subject)
        let envelope = data.flatMap { try? JSONDecoder().decode(Envelope.self, from: $0) }
        record(status, host, envelope?.code, envelope?.message)
        return outcome
    }

    private static func send(
        china: Bool,
        cookieHeader: String,
        subject: String?) async throws -> (Outcome, Int, String?, Data?)
    {
        let host = SiliconFlowConsole.host(china: china)
        var request = URLRequest(url: URL(string: "https://\(host)/biz-server/api/v1/user/info")!)
        request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("https://\(host)", forHTTPHeaderField: "Origin")
        request.addValue("https://\(host)/me/expensebill", forHTTPHeaderField: "Referer")
        if let subject { request.addValue(subject, forHTTPHeaderField: "X-Subject-ID") }
        request.timeoutInterval = 15

        let (data, response) = try await ProviderRequestSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SiliconFlowAPIError.invalidResponse }
        let finalHost = http.url?.host
        // A dead session is bounced to account.siliconflow.* (the login page).
        if finalHost?.hasPrefix("account.") == true || http.statusCode == 401 || http.statusCode == 403 {
            return (.signedOut, http.statusCode, finalHost, data)
        }
        guard http.statusCode == 200 else { throw SiliconFlowConsoleError.httpError(statusCode: http.statusCode) }
        guard let decoded = try? JSONDecoder().decode(SiliconFlowBalanceResponse.self, from: data) else {
            return (.signedOut, http.statusCode, finalHost, data)
        }
        return (decoded.hasBalance ? .balance(decoded) : .signedInWithoutBalance, http.statusCode, finalHost, data)
    }
}

struct SiliconFlowCookieSession {
    let cookieHeader: String
    let sourceLabel: String

    /// A subject-looking cookie's value, read back out of the header so a saved
    /// session keeps it too.
    var subjectCookie: String? {
        SiliconFlowConsole.cookieValue(in: self.cookieHeader) { $0.lowercased().contains("subject") }
    }
}

enum SiliconFlowCookieImporter {
    private static let cookieClient = BrowserCookieClient()

    /// One session per browser profile holding a SiliconFlow login cookie
    /// (`__SF_auth.session-token`), same flow as the Cursor and Ollama importers.
    static func importSessions(china: Bool, log: (String) -> Void) -> [SiliconFlowCookieSession] {
        let provider: UsageProvider = china ? .siliconflowCN : .siliconflow
        let order = ProviderDefaults.metadata[provider]?.browserCookieOrder ?? Browser.defaultImportOrder
        let domains = china ? ["siliconflow.cn"] : ["siliconflow.com"]
        var sessions: [SiliconFlowCookieSession] = []
        for browserSource in order {
            do {
                let query = BrowserCookieQuery(domains: domains)
                let sources = try Self.cookieClient.records(matching: query, in: browserSource)
                if sources.allSatisfy(\.records.isEmpty) {
                    log("\(browserSource.displayName): no \(domains[0]) cookies")
                }
                for source in sources where !source.records.isEmpty {
                    let cookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
                    guard cookies.contains(where: { $0.name.lowercased().contains("session-token") }) else {
                        // Names only, never values: enough to spot a renamed login cookie.
                        let names = Set(cookies.map(\.name)).sorted().joined(separator: ", ")
                        log("\(source.label): \(cookies.count) cookies, no session-token (\(names))")
                        continue
                    }
                    log("\(source.label): SiliconFlow session found")
                    sessions.append(SiliconFlowCookieSession(
                        cookieHeader: cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "),
                        sourceLabel: source.label))
                }
            } catch {
                log("\(browserSource.displayName) cookie import failed: \(error.localizedDescription)")
            }
        }
        return sessions
    }
}
#endif
