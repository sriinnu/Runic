#if os(macOS)
import Foundation
import Silo

extension OpenAIDashboardBrowserCookieImporter {
    struct ImportDiagnostics {
        var mismatches: [FoundAccount] = []
        var foundAnyCookies: Bool = false
        var foundUnknownEmail: Bool = false
        var accessDeniedHints: [String] = []
    }

    struct Candidate {
        let label: String
        let cookies: [HTTPCookie]
    }

    enum CandidateEvaluation {
        case match(candidate: Candidate, signedInEmail: String)
        case mismatch(candidate: Candidate, signedInEmail: String)
        case loggedIn(candidate: Candidate, signedInEmail: String)
        case unknown(candidate: Candidate)
        case loginRequired(candidate: Candidate)
    }

    static let cookieDomains = ["chatgpt.com", "openai.com"]
    static let cookieClient = BrowserCookieClient()
    static let cookieImportOrder: BrowserCookieImportOrder =
        ProviderDefaults.metadata[.codex]?.browserCookieOrder ?? Browser.defaultImportOrder
}
#endif
