#if os(macOS)
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
    }

    public init() {}

    public func importBestCookies(
        intoAccountEmail targetEmail: String?,
        allowAnyAccount: Bool = false,
        logger: ((String) -> Void)? = nil) async throws -> ImportResult
    {
        let log: (String) -> Void = { message in
            logger?("[web] \(message)")
        }

        let targetEmail = targetEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTarget = targetEmail?.isEmpty == false ? targetEmail : nil

        if let normalizedTarget {
            log("Codex email: \(normalizedTarget)")
        } else {
            guard allowAnyAccount else {
                throw ImportError.noCookiesFound
            }
            log("Codex email unknown; importing any signed-in session.")
        }

        var diagnostics = ImportDiagnostics()

        for browserSource in Self.cookieImportOrder {
            if let match = await self.trySource(
                browserSource,
                targetEmail: normalizedTarget,
                allowAnyAccount: allowAnyAccount,
                log: log,
                diagnostics: &diagnostics)
            {
                return match
            }
        }

        if !diagnostics.mismatches.isEmpty {
            let found = Array(Set(diagnostics.mismatches)).sorted { lhs, rhs in
                if lhs.sourceLabel == rhs.sourceLabel { return lhs.email < rhs.email }
                return lhs.sourceLabel < rhs.sourceLabel
            }
            let emails = Array(Set(found.map(\.email))).sorted()
            log("No matching browser session found. Candidates signed in as: \(emails.joined(separator: ", "))")
            throw ImportError.noMatchingAccount(found: found)
        }

        if diagnostics.foundUnknownEmail || diagnostics.foundAnyCookies {
            log("No matching browser session found (email unknown).")
            throw ImportError.noMatchingAccount(found: [])
        }

        if !diagnostics.accessDeniedHints.isEmpty {
            let details = diagnostics.accessDeniedHints.joined(separator: " ")
            log("Cookie access denied: \(details)")
            throw ImportError.browserAccessDenied(details: details)
        }

        throw ImportError.noCookiesFound
    }
}
#endif
