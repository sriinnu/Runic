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
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case let .notSignedIn(china):
            "Not signed in to \(SiliconFlowConsole.host(china: china)). " +
                "Sign in there in your browser for the balance, or add an API key for a key check."
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
}

#if os(macOS)
enum SiliconFlowConsoleFetcher {
    static func fetchBalance(
        china: Bool,
        environment: [String: String],
        logger: ((String) -> Void)? = nil) async throws -> SiliconFlowBalanceResponse
    {
        let sessions = SiliconFlowCookieImporter.importSessions(china: china, logger: logger)
        guard !sessions.isEmpty else { throw SiliconFlowConsoleError.notSignedIn(china: china) }
        let envSubject = environment[china ? "SILICONFLOW_CN_SUBJECT_ID" : "SILICONFLOW_SUBJECT_ID"]

        var sawSignedIn = false
        sessionLoop: for session in sessions {
            let subjects = SiliconFlowConsole.subjectCandidates(
                environment: envSubject,
                cookie: session.subjectCookie)
            for subject in subjects {
                switch try await self.request(china: china, cookieHeader: session.cookieHeader, subject: subject) {
                case let .balance(response):
                    return response
                case .signedInWithoutBalance:
                    sawSignedIn = true
                case .signedOut:
                    logger?("[siliconflow-cookie] \(session.sourceLabel) is signed out")
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

    private static func request(china: Bool, cookieHeader: String, subject: String?) async throws -> Outcome {
        let host = SiliconFlowConsole.host(china: china)
        var request = URLRequest(url: URL(string: "https://\(host)/biz-server/api/v1/user/info")!)
        request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("https://\(host)", forHTTPHeaderField: "Origin")
        request.addValue("https://\(host)/me/expensebill", forHTTPHeaderField: "Referer")
        if let subject { request.addValue(subject, forHTTPHeaderField: "X-Subject-ID") }
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SiliconFlowAPIError.invalidResponse }
        // A dead session is bounced to account.siliconflow.* (the login page).
        if http.url?.host?.hasPrefix("account.") == true || http.statusCode == 401 || http.statusCode == 403 {
            return .signedOut
        }
        guard http.statusCode == 200 else { throw SiliconFlowConsoleError.httpError(statusCode: http.statusCode) }
        guard let decoded = try? JSONDecoder().decode(SiliconFlowBalanceResponse.self, from: data) else {
            return .signedOut
        }
        return decoded.hasBalance ? .balance(decoded) : .signedInWithoutBalance
    }
}

struct SiliconFlowCookieSession {
    let cookieHeader: String
    let subjectCookie: String?
    let sourceLabel: String
}

enum SiliconFlowCookieImporter {
    private static let cookieClient = BrowserCookieClient()

    /// One session per browser profile holding a SiliconFlow login cookie
    /// (`__SF_auth.session-token`), same flow as the Cursor and Ollama importers.
    static func importSessions(china: Bool, logger: ((String) -> Void)? = nil) -> [SiliconFlowCookieSession] {
        let log: (String) -> Void = { msg in logger?("[siliconflow-cookie] \(msg)") }
        let provider: UsageProvider = china ? .siliconflowCN : .siliconflow
        let order = ProviderDefaults.metadata[provider]?.browserCookieOrder ?? Browser.defaultImportOrder
        let domains = china ? ["siliconflow.cn"] : ["siliconflow.com"]
        var sessions: [SiliconFlowCookieSession] = []
        for browserSource in order {
            do {
                let query = BrowserCookieQuery(domains: domains)
                let sources = try Self.cookieClient.records(matching: query, in: browserSource)
                for source in sources where !source.records.isEmpty {
                    let cookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
                    guard cookies.contains(where: { $0.name.lowercased().contains("session-token") }) else {
                        continue
                    }
                    log("Found a SiliconFlow session in \(source.label)")
                    sessions.append(SiliconFlowCookieSession(
                        cookieHeader: cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "),
                        subjectCookie: cookies.first(where: { $0.name.lowercased().contains("subject") })?.value,
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
