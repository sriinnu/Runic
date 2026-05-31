import Foundation
import Silo

#if os(macOS)
struct MiniMaxCookieSession {
    let cookieHeader: String
    let sourceLabel: String
}

enum MiniMaxCookieImporter {
    private static let cookieClient = BrowserCookieClient()
    private static let cookieDomains = ["platform.minimax.io", "minimax.io"]

    static func importSessions(logger: ((String) -> Void)? = nil) -> [MiniMaxCookieSession] {
        let log: (String) -> Void = { msg in logger?("[minimax-cookie] \(msg)") }
        let order = ProviderDefaults.metadata[.minimax]?.browserCookieOrder ?? Browser.defaultImportOrder
        var sessions: [MiniMaxCookieSession] = []

        for browserSource in order {
            do {
                let query = BrowserCookieQuery(domains: self.cookieDomains)
                let sources = try Self.cookieClient.records(matching: query, in: browserSource)
                if sources.isEmpty { continue }

                let grouped = Dictionary(grouping: sources, by: { $0.store.profile })
                for (profile, records) in grouped {
                    let mergedRecords = records.flatMap(\.records)
                    guard !mergedRecords.isEmpty else { continue }
                    let cookies = BrowserCookieClient.makeHTTPCookies(mergedRecords, origin: query.origin)
                    guard !cookies.isEmpty else { continue }
                    let label = self.label(for: browserSource, profile: profile, sources: records)
                    log("Found \(cookies.count) cookies in \(label)")
                    sessions.append(MiniMaxCookieSession(
                        cookieHeader: cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "),
                        sourceLabel: label))
                }
            } catch {
                log("\(browserSource.displayName) cookie import failed: \(error.localizedDescription)")
            }
        }

        return sessions
    }

    private static func label(
        for browser: Browser,
        profile: BrowserProfile,
        sources: [BrowserCookieStoreRecords]) -> String
    {
        if sources.count == 1 {
            return sources[0].label
        }
        let suffix = profile.name.isEmpty ? "" : " \(profile.name)"
        return "\(browser.displayName)\(suffix) (merged)"
    }
}
#endif
