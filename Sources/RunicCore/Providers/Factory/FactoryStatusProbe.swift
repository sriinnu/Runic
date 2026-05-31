import Foundation
import Silo

#if os(macOS)

// MARK: - Factory Status Probe

public struct FactoryStatusProbe: Sendable {
    public let baseURL: URL
    public var timeout: TimeInterval = 15.0

    static let staleTokenCookieNames: Set<String> = [
        "access-token",
        "__recent_auth",
    ]
    static let sessionCookieNames: Set<String> = [
        "session",
        "wos-session",
    ]
    static let authSessionCookieNames: Set<String> = [
        "__Secure-next-auth.session-token",
        "next-auth.session-token",
        "__Secure-authjs.session-token",
        "authjs.session-token",
    ]
    static let appBaseURL = URL(string: "https://app.factory.ai")!
    static let authBaseURL = URL(string: "https://auth.factory.ai")!
    static let apiBaseURL = URL(string: "https://api.factory.ai")!
    static let workosClientIDs = [
        "client_01HXRMBQ9BJ3E7QSTQ9X2PHVB7",
        "client_01HNM792M5G5G1A2THWPXKFMXB",
    ]

    public init(baseURL: URL = URL(string: "https://app.factory.ai")!, timeout: TimeInterval = 15.0) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    /// Fetch Factory usage using browser cookies with fallback to stored session.
    public func fetch(logger: ((String) -> Void)? = nil) async throws -> FactoryStatusSnapshot {
        let log: (String) -> Void = { msg in logger?("[factory] \(msg)") }
        var lastError: Error?

        let attempts: [FetchAttemptResult] = await [
            self.attemptBrowserCookies(logger: log, sources: [.safari]),
            self.attemptStoredCookies(logger: log),
            self.attemptStoredBearer(logger: log),
            self.attemptStoredRefreshToken(logger: log),
            self.attemptLocalStorageTokens(logger: log),
            self.attemptWorkOSCookies(logger: log, sources: [.safari]),
            self.attemptBrowserCookies(logger: log, sources: [.chrome, .firefox]),
            self.attemptWorkOSCookies(logger: log, sources: [.chrome, .firefox]),
        ]

        for result in attempts {
            switch result {
            case let .success(snapshot):
                return snapshot
            case let .failure(error):
                lastError = error
            case .skipped:
                continue
            }
        }

        if let lastError { throw lastError }
        throw FactoryStatusProbeError.noSessionCookie
    }

    enum FetchAttemptResult {
        case success(FactoryStatusSnapshot)
        case failure(Error)
        case skipped
    }
}

#else

// MARK: - Factory (Unsupported)

public enum FactoryStatusProbeError: LocalizedError, Sendable {
    case notSupported

    public var errorDescription: String? {
        "Factory is only supported on macOS."
    }
}

public struct FactoryStatusSnapshot: Sendable {
    public init() {}

    public func toUsageSnapshot() -> UsageSnapshot {
        UsageSnapshot(
            primary: RateWindow(usedPercent: 0, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            providerCost: nil,
            updatedAt: Date(),
            identity: nil)
    }
}

public struct FactoryStatusProbe: Sendable {
    public init(baseURL: URL = URL(string: "https://app.factory.ai")!, timeout: TimeInterval = 15.0) {
        _ = baseURL
        _ = timeout
    }

    public func fetch(logger: ((String) -> Void)? = nil) async throws -> FactoryStatusSnapshot {
        _ = logger
        throw FactoryStatusProbeError.notSupported
    }
}

#endif
