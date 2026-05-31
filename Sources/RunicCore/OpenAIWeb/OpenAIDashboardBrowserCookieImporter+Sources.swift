#if os(macOS)
import Foundation
import Silo

extension OpenAIDashboardBrowserCookieImporter {
    func trySafari(
        targetEmail: String?,
        allowAnyAccount: Bool,
        log: @escaping (String) -> Void,
        diagnostics: inout ImportDiagnostics) async -> ImportResult?
    {
        // Safari first: avoids touching Keychain ("Chrome Safe Storage") when Safari already matches.
        do {
            let query = BrowserCookieQuery(domains: Self.cookieDomains)
            let sources = try Self.cookieClient.records(
                matching: query,
                in: .safari)
            guard !sources.isEmpty else {
                log("Safari contained 0 matching records.")
                return nil
            }
            for source in sources {
                let cookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
                guard !cookies.isEmpty else {
                    log("\(source.label) produced 0 HTTPCookies.")
                    continue
                }

                diagnostics.foundAnyCookies = true
                log("Loaded \(cookies.count) cookies from \(source.label) (\(self.cookieSummary(cookies)))")
                let candidate = Candidate(label: source.label, cookies: cookies)
                if let match = await self.applyCandidate(
                    candidate,
                    targetEmail: targetEmail,
                    allowAnyAccount: allowAnyAccount,
                    log: log,
                    diagnostics: &diagnostics)
                {
                    return match
                }
            }
            return nil
        } catch let error as BrowserCookieError {
            let hint = error.accessDeniedHint
            if !hint.isEmpty {
                diagnostics.accessDeniedHints.append(hint)
            }
            log("Safari cookie load failed: \(error.localizedDescription)")
            return nil
        } catch {
            log("Safari cookie load failed: \(error.localizedDescription)")
            return nil
        }
    }

    func tryChrome(
        targetEmail: String?,
        allowAnyAccount: Bool,
        log: @escaping (String) -> Void,
        diagnostics: inout ImportDiagnostics) async -> ImportResult?
    {
        // Chrome fallback: may trigger Keychain prompt. Only do this if Safari didn't match.
        do {
            let query = BrowserCookieQuery(domains: Self.cookieDomains)
            let chromeSources = try Self.cookieClient.records(
                matching: query,
                in: .chrome)
            for source in chromeSources {
                let cookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
                if cookies.isEmpty {
                    log("\(source.label) produced 0 HTTPCookies.")
                    continue
                }
                diagnostics.foundAnyCookies = true
                log("Loaded \(cookies.count) cookies from \(source.label) (\(self.cookieSummary(cookies)))")
                let candidate = Candidate(label: source.label, cookies: cookies)
                if let match = await self.applyCandidate(
                    candidate,
                    targetEmail: targetEmail,
                    allowAnyAccount: allowAnyAccount,
                    log: log,
                    diagnostics: &diagnostics)
                {
                    return match
                }
            }
            return nil
        } catch let error as BrowserCookieError {
            let hint = error.accessDeniedHint
            if !hint.isEmpty {
                diagnostics.accessDeniedHints.append(hint)
            }
            log("Chrome cookie load failed: \(error.localizedDescription)")
            return nil
        } catch {
            log("Chrome cookie load failed: \(error.localizedDescription)")
            return nil
        }
    }

    func tryFirefox(
        targetEmail: String?,
        allowAnyAccount: Bool,
        log: @escaping (String) -> Void,
        diagnostics: inout ImportDiagnostics) async -> ImportResult?
    {
        // Firefox fallback: no Keychain, but still only after Safari/Chrome.
        do {
            let query = BrowserCookieQuery(domains: Self.cookieDomains)
            let firefoxSources = try Self.cookieClient.records(
                matching: query,
                in: .firefox)
            for source in firefoxSources {
                let cookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
                if cookies.isEmpty {
                    log("\(source.label) produced 0 HTTPCookies.")
                    continue
                }
                diagnostics.foundAnyCookies = true
                log("Loaded \(cookies.count) cookies from \(source.label) (\(self.cookieSummary(cookies)))")
                let candidate = Candidate(label: source.label, cookies: cookies)
                if let match = await self.applyCandidate(
                    candidate,
                    targetEmail: targetEmail,
                    allowAnyAccount: allowAnyAccount,
                    log: log,
                    diagnostics: &diagnostics)
                {
                    return match
                }
            }
            return nil
        } catch let error as BrowserCookieError {
            let hint = error.accessDeniedHint
            if !hint.isEmpty {
                diagnostics.accessDeniedHints.append(hint)
            }
            log("Firefox cookie load failed: \(error.localizedDescription)")
            return nil
        } catch {
            log("Firefox cookie load failed: \(error.localizedDescription)")
            return nil
        }
    }

    func trySource(
        _ source: Browser,
        targetEmail: String?,
        allowAnyAccount: Bool,
        log: @escaping (String) -> Void,
        diagnostics: inout ImportDiagnostics) async -> ImportResult?
    {
        switch source {
        case .safari:
            await self.trySafari(
                targetEmail: targetEmail,
                allowAnyAccount: allowAnyAccount,
                log: log,
                diagnostics: &diagnostics)
        case .chrome:
            await self.tryChrome(
                targetEmail: targetEmail,
                allowAnyAccount: allowAnyAccount,
                log: log,
                diagnostics: &diagnostics)
        case .firefox:
            await self.tryFirefox(
                targetEmail: targetEmail,
                allowAnyAccount: allowAnyAccount,
                log: log,
                diagnostics: &diagnostics)
        default:
            nil
        }
    }

    private func cookieSummary(_ cookies: [HTTPCookie]) -> String {
        let nameCounts = Dictionary(grouping: cookies, by: \.name).mapValues { $0.count }
        let important = [
            "__Secure-next-auth.session-token",
            "__Secure-next-auth.session-token.0",
            "__Secure-next-auth.session-token.1",
            "_account",
            "oai-did",
            "cf_clearance",
        ]
        let parts: [String] = important.compactMap { name -> String? in
            guard let c = nameCounts[name], c > 0 else { return nil }
            return "\(name)=\(c)"
        }
        if parts.isEmpty { return "no key cookies detected" }
        return parts.joined(separator: ", ")
    }
}
#endif
