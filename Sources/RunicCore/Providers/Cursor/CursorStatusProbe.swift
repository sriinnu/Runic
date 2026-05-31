import Foundation

#if os(macOS)

// MARK: - Cursor Status Probe Error

public enum CursorStatusProbeError: LocalizedError, Sendable {
    case notLoggedIn
    case networkError(String)
    case parseFailed(String)
    case noSessionCookie

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            "Not logged in to Cursor. Please log in via the Runic menu."
        case let .networkError(msg):
            "Cursor API error: \(msg)"
        case let .parseFailed(msg):
            "Could not parse Cursor usage: \(msg)"
        case .noSessionCookie:
            "No Cursor session found. Please log in to cursor.com in \(cursorCookieImportOrder.loginHint)."
        }
    }
}

// MARK: - Cursor Status Probe

public struct CursorStatusProbe: Sendable {
    public let baseURL: URL
    public var timeout: TimeInterval = 15.0

    public init(baseURL: URL = URL(string: "https://cursor.com")!, timeout: TimeInterval = 15.0) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    /// Fetch Cursor usage using browser cookies with fallback to stored session.
    public func fetch(logger: ((String) -> Void)? = nil) async throws -> CursorStatusSnapshot {
        let log: (String) -> Void = { msg in logger?("[cursor] \(msg)") }

        // Try importing cookies from the configured browser order first.
        do {
            let session = try CursorCookieImporter.importSession(logger: log)
            log("Using cookies from \(session.sourceLabel)")
            return try await self.fetchWithCookieHeader(session.cookieHeader)
        } catch {
            log("Browser cookie import failed: \(error.localizedDescription)")
        }

        // Fall back to stored session cookies (from "Add Account" login flow)
        let storedCookies = await CursorSessionStore.shared.getCookies()
        if !storedCookies.isEmpty {
            log("Using stored session cookies")
            let cookieHeader = storedCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            do {
                return try await self.fetchWithCookieHeader(cookieHeader)
            } catch {
                if case CursorStatusProbeError.notLoggedIn = error {
                    // Clear only when auth is invalid; keep for transient failures.
                    await CursorSessionStore.shared.clearCookies()
                    log("Stored session invalid, cleared")
                } else {
                    log("Stored session failed: \(error.localizedDescription)")
                }
            }
        }

        throw CursorStatusProbeError.noSessionCookie
    }
}

#else

// MARK: - Cursor (Unsupported)

public enum CursorStatusProbeError: LocalizedError, Sendable {
    case notSupported

    public var errorDescription: String? {
        "Cursor is only supported on macOS."
    }
}

public struct CursorStatusSnapshot: Sendable {
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

public struct CursorStatusProbe: Sendable {
    public init(baseURL: URL = URL(string: "https://cursor.com")!, timeout: TimeInterval = 15.0) {
        _ = baseURL
        _ = timeout
    }

    public func fetch(logger: ((String) -> Void)? = nil) async throws -> CursorStatusSnapshot {
        _ = logger
        throw CursorStatusProbeError.notSupported
    }
}

#endif
