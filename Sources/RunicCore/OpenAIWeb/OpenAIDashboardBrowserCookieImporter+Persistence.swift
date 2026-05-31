#if os(macOS)
import Foundation
import WebKit

extension OpenAIDashboardBrowserCookieImporter {
    func persist(
        candidate: Candidate,
        targetEmail: String,
        logger: @escaping (String) -> Void) async throws -> ImportResult
    {
        let persistent = OpenAIDashboardWebsiteDataStore.store(forAccountEmail: targetEmail)
        await self.clearChatGPTCookies(in: persistent)
        await self.setCookies(candidate.cookies, into: persistent)

        // Validate against the persistent store (login + email sync).
        do {
            let probe = try await OpenAIDashboardFetcher().probeUsagePage(
                websiteDataStore: persistent,
                logger: logger,
                timeout: 20)
            let signed = probe.signedInEmail?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let matches = signed?.lowercased() == targetEmail.lowercased()
            logger("Persistent session signed in as: \(signed ?? "unknown")")
            if signed != nil, matches == false {
                let found = signed?.isEmpty == false
                    ? [FoundAccount(sourceLabel: candidate.label, email: signed!)]
                    : []
                throw ImportError.noMatchingAccount(found: found)
            }
            return ImportResult(
                sourceLabel: candidate.label,
                cookieCount: candidate.cookies.count,
                signedInEmail: signed,
                matchesCodexEmail: matches)
        } catch OpenAIDashboardFetcher.FetchError.loginRequired {
            logger("Selected \(candidate.label) but dashboard still requires login.")
            throw ImportError.dashboardStillRequiresLogin
        }
    }

    func persistToDefaultStore(
        candidate: Candidate,
        logger: @escaping (String) -> Void) async throws -> ImportResult
    {
        let persistent = OpenAIDashboardWebsiteDataStore.store(forAccountEmail: nil)
        await self.clearChatGPTCookies(in: persistent)
        await self.setCookies(candidate.cookies, into: persistent)

        do {
            let probe = try await OpenAIDashboardFetcher().probeUsagePage(
                websiteDataStore: persistent,
                logger: logger,
                timeout: 20)
            let signed = probe.signedInEmail?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            logger("Persistent session signed in as: \(signed ?? "unknown")")
            return ImportResult(
                sourceLabel: candidate.label,
                cookieCount: candidate.cookies.count,
                signedInEmail: signed,
                matchesCodexEmail: false)
        } catch OpenAIDashboardFetcher.FetchError.loginRequired {
            logger("Selected \(candidate.label) but dashboard still requires login.")
            throw ImportError.dashboardStillRequiresLogin
        }
    }

    func persistCookies(candidate: Candidate, accountEmail: String, logger: (String) -> Void) async {
        let store = OpenAIDashboardWebsiteDataStore.store(forAccountEmail: accountEmail)
        await self.clearChatGPTCookies(in: store)
        await self.setCookies(candidate.cookies, into: store)
        logger("Persisted cookies for \(accountEmail) (source=\(candidate.label))")
    }

    func clearChatGPTCookies(in store: WKWebsiteDataStore) async {
        await withCheckedContinuation { cont in
            store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                let filtered = records.filter { record in
                    let name = record.displayName.lowercased()
                    return name.contains("chatgpt.com") || name.contains("openai.com")
                }
                store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: filtered) {
                    cont.resume()
                }
            }
        }
    }

    func setCookies(_ cookies: [HTTPCookie], into store: WKWebsiteDataStore) async {
        for cookie in cookies {
            await withCheckedContinuation { cont in
                store.httpCookieStore.setCookie(cookie) { cont.resume() }
            }
        }
    }
}
#endif
