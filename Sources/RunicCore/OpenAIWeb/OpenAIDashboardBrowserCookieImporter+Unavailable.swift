#if !os(macOS)
import Foundation

@MainActor
public struct OpenAIDashboardBrowserCookieImporter {
    public struct FoundAccount: Sendable, Hashable {
        public let sourceLabel: String
        public let email: String

        public init(sourceLabel: String, email: String) {
            self.sourceLabel = sourceLabel
            self.email = email
        }
    }

    public enum ImportError: LocalizedError {
        case noCookiesFound
        case browserAccessDenied(details: String)
        case dashboardStillRequiresLogin
        case noMatchingAccount(found: [FoundAccount])

        public var errorDescription: String? {
            switch self {
            case .noCookiesFound:
                return "No browser cookies found."
            case let .browserAccessDenied(details):
                return "Browser cookie access denied. \(details)"
            case .dashboardStillRequiresLogin:
                return "Browser cookies imported, but dashboard still requires login."
            case let .noMatchingAccount(found):
                if found.isEmpty { return "No matching OpenAI web session found in browsers." }
                let display = found
                    .sorted { lhs, rhs in
                        if lhs.sourceLabel == rhs.sourceLabel { return lhs.email < rhs.email }
                        return lhs.sourceLabel < rhs.sourceLabel
                    }
                    .map { "\($0.sourceLabel)=\($0.email)" }
                    .joined(separator: ", ")
                return "OpenAI web session does not match Codex account. Found: \(display)."
            }
        }
    }

    public struct ImportResult: Sendable {
        public let sourceLabel: String
        public let cookieCount: Int
        public let signedInEmail: String?
        public let matchesCodexEmail: Bool

        public init(sourceLabel: String, cookieCount: Int, signedInEmail: String?, matchesCodexEmail: Bool) {
            self.sourceLabel = sourceLabel
            self.cookieCount = cookieCount
            self.signedInEmail = signedInEmail
            self.matchesCodexEmail = matchesCodexEmail
        }
    }

    public init() {}

    public func importBestCookies(
        intoAccountEmail _: String?,
        allowAnyAccount _: Bool = false,
        logger _: ((String) -> Void)? = nil) async throws -> ImportResult
    {
        throw ImportError.browserAccessDenied(details: "OpenAI web cookie import is only supported on macOS.")
    }
}
#endif
