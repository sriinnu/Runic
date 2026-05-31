import Foundation
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

#if os(macOS)
struct MiniMaxWebSession {
    let cookieHeader: String
    let accessToken: String?
    let groupID: String?
    let sourceLabel: String
    let isManual: Bool
}
#endif
