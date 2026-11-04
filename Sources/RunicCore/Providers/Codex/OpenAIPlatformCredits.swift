import Foundation

/// OpenAI API credits, which sit on platform.openai.com rather than the ChatGPT
/// login Codex uses. No API key can read them. The billing page's own API takes
/// the dashboard's bearer token, so Runic keeps that token from a login made in
/// its own window and sends it only to `api.openai.com`.
///
/// Undocumented, so it can change. Shape captured from a real account on
/// 2026-11-04; how long the token lasts is unknown, so an expired one has to
/// read as "sign in again", never as an error on the card.
public enum OpenAIPlatformCredits {
    public static let apiPrefix = "https://api.openai.com/v1/dashboard/billing"
    public static let signInURL = URL(string: "https://platform.openai.com/settings/organization/billing/overview")!

    public enum Failure: LocalizedError {
        case needsSignIn
        case signInExpired
        case unexpectedReply(String)

        public var errorDescription: String? {
            switch self {
            case .needsSignIn:
                "Sign in to platform.openai.com to read your API credits."
            case .signInExpired:
                "Your platform.openai.com sign-in expired. Turn this off and on to sign in again."
            case let .unexpectedReply(detail):
                "OpenAI's billing reply wasn't readable: \(detail)"
            }
        }
    }

    private struct Session: Codable {
        let authorization: String
        let organization: String?
    }

    private struct Reply: Decodable {
        struct Grants: Decodable {
            let data: [Grant]
        }

        struct Grant: Decodable {
            let grantAmount: Double
            let usedAmount: Double
            let expiresAt: Double?
            let isScheduled: Bool?

            enum CodingKeys: String, CodingKey {
                case grantAmount = "grant_amount"
                case usedAmount = "used_amount"
                case expiresAt = "expires_at"
                case isScheduled = "is_scheduled"
            }
        }

        let totalAvailable: Double
        let grants: Grants

        enum CodingKeys: String, CodingKey {
            case totalAvailable = "total_available"
            case grants
        }
    }

    private static let saved = SavedBrowserSession.openAIPlatform
    private static let deadlineSeconds = 10
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
        self.saved.isConnected
    }

    public static func disconnect() {
        self.saved.clear()
        self.setLastFailure(nil)
    }

    /// For a login made in Runic's window: what to do to keep this token, or nil
    /// while OpenAI doesn't accept it.
    public static func validate(
        authorization: String,
        organization: String?) async -> (@Sendable () -> Void)?
    {
        guard let session = Self.session(authorization: authorization, organization: organization),
              let value = try? String(data: JSONEncoder().encode(session), encoding: .utf8),
              await (try? Self.fetch(session)) != nil
        else { return nil }
        return {
            guard Self.saved.store(value) else { return }
            Self.setLastFailure(nil)
        }
    }

    /// Adds the credits to a snapshot. Best effort: the usage still shows when
    /// this fails. Saved login only, never a browser, never a prompt.
    static func attach(to snapshot: UsageSnapshot) async -> UsageSnapshot {
        guard let value = saved.load(),
              let session = try? JSONDecoder().decode(Session.self, from: Data(value.utf8))
        else { return snapshot }
        do {
            let credits = try await Self.fetchWithinDeadline(session)
            Self.setLastFailure(nil)
            return snapshot.with(apiCredits: credits)
        } catch {
            Self.setLastFailure(error.localizedDescription)
            return snapshot
        }
    }

    private static func fetchWithinDeadline(_ session: Session) async throws -> ProviderAPICredits {
        try await withThrowingTaskGroup(of: ProviderAPICredits.self) { group in
            group.addTask { try await self.fetch(session) }
            group.addTask {
                try await Task.sleep(for: .seconds(self.deadlineSeconds))
                throw Failure.unexpectedReply("no answer in \(self.deadlineSeconds)s")
            }
            defer { group.cancelAll() }
            guard let credits = try await group.next() else {
                throw Failure.unexpectedReply("no answer")
            }
            return credits
        }
    }

    /// Only a bearer token on one line goes into a header or the Keychain.
    private static func session(authorization: String, organization: String?) -> Session? {
        guard authorization.lowercased().hasPrefix("bearer "),
              !authorization.contains(where: \.isNewline),
              organization?.contains(where: \.isNewline) != true
        else { return nil }
        return Session(authorization: authorization, organization: organization)
    }

    private static func fetch(_ session: Session) async throws -> ProviderAPICredits {
        guard let url = URL(string: "\(apiPrefix)/credit_grants") else {
            throw Failure.unexpectedReply("bad address")
        }
        var request = URLRequest(url: url, timeoutInterval: TimeInterval(Self.deadlineSeconds))
        request.httpShouldHandleCookies = false
        request.setValue(session.authorization, forHTTPHeaderField: "Authorization")
        if let organization = session.organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        let (data, response) = try await URLSession.shared.data(for: request, delegate: NoRedirects())
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let failure = Self.failure(forStatus: status) { throw failure }
        return try Self.parse(data, fetchedAt: Date())
    }

    static func failure(forStatus status: Int) -> Failure? {
        switch status {
        case 200: nil
        case 401, 403: .signInExpired
        default: .unexpectedReply("status \(status)")
        }
    }

    /// A grant that's scheduled or used up has nothing to say about what's left.
    static func parse(_ data: Data, fetchedAt: Date) throws -> ProviderAPICredits {
        let reply: Reply
        do {
            reply = try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            throw Failure.unexpectedReply("unexpected shape")
        }
        let grants = reply.grants.data.compactMap { grant -> ProviderAPICredits.Grant? in
            let remaining = grant.grantAmount - grant.usedAmount
            guard grant.isScheduled != true, remaining > 0 else { return nil }
            return ProviderAPICredits.Grant(
                name: nil,
                remaining: remaining,
                granted: grant.grantAmount,
                expiresAt: grant.expiresAt.map(Date.init(timeIntervalSince1970:)))
        }
        return ProviderAPICredits(
            available: reply.totalAvailable,
            currencyCode: "USD",
            grants: grants,
            fetchedAt: fetchedAt)
    }

    /// The token must never follow a redirect to another host.
    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _: URLSession,
            task _: URLSessionTask,
            willPerformHTTPRedirection _: HTTPURLResponse,
            newRequest _: URLRequest) async -> URLRequest?
        {
            nil
        }
    }
}

extension UsageSnapshot {
    func with(apiCredits: ProviderAPICredits) -> UsageSnapshot {
        var cost = self.providerCost ?? ProviderCostSnapshot(
            used: 0,
            limit: 0,
            currencyCode: apiCredits.currencyCode,
            updatedAt: self.updatedAt)
        cost.apiCredits = apiCredits
        return UsageSnapshot(
            primary: self.primary,
            secondary: self.secondary,
            tertiary: self.tertiary,
            providerCost: cost,
            zaiUsage: self.zaiUsage,
            resetCredits: self.resetCredits,
            balance: self.balance,
            updatedAt: self.updatedAt,
            identity: self.identity)
    }
}
