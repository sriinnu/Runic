#if os(macOS)
import Foundation
import WebKit

extension OpenAIDashboardBrowserCookieImporter {
    func applyCandidate(
        _ candidate: Candidate,
        targetEmail: String?,
        allowAnyAccount: Bool,
        log: @escaping (String) -> Void,
        diagnostics: inout ImportDiagnostics) async -> ImportResult?
    {
        switch await self.evaluateCandidate(
            candidate,
            targetEmail: targetEmail,
            allowAnyAccount: allowAnyAccount,
            log: log)
        {
        case let .match(candidate, signedInEmail):
            log("Selected \(candidate.label) (matches Codex: \(signedInEmail))")
            guard let targetEmail else { return nil }
            return try? await self.persist(candidate: candidate, targetEmail: targetEmail, logger: log)
        case let .mismatch(candidate, signedInEmail):
            await self.handleMismatch(
                candidate: candidate,
                signedInEmail: signedInEmail,
                log: log,
                diagnostics: &diagnostics)
            return nil
        case let .loggedIn(candidate, signedInEmail):
            log("Selected \(candidate.label) (signed in: \(signedInEmail))")
            return try? await self.persist(candidate: candidate, targetEmail: signedInEmail, logger: log)
        case .unknown:
            if allowAnyAccount {
                log("Selected \(candidate.label) (signed in: unknown)")
                return try? await self.persistToDefaultStore(candidate: candidate, logger: log)
            }
            diagnostics.foundUnknownEmail = true
            return nil
        case .loginRequired:
            return nil
        }
    }

    func evaluateCandidate(
        _ candidate: Candidate,
        targetEmail: String?,
        allowAnyAccount: Bool,
        log: @escaping (String) -> Void) async -> CandidateEvaluation
    {
        log("Trying candidate \(candidate.label) (\(candidate.cookies.count) cookies)")

        let apiEmail = await self.fetchSignedInEmailFromAPI(cookies: candidate.cookies, logger: log)
        if let apiEmail {
            log("Candidate \(candidate.label) API email: \(apiEmail)")
        }

        // Prefer the API email when available (fast; avoids WebKit hydration/timeout risks).
        if let apiEmail, !apiEmail.isEmpty {
            if let targetEmail {
                if apiEmail.lowercased() == targetEmail.lowercased() {
                    return .match(candidate: candidate, signedInEmail: apiEmail)
                }
                return .mismatch(candidate: candidate, signedInEmail: apiEmail)
            }
            if allowAnyAccount { return .loggedIn(candidate: candidate, signedInEmail: apiEmail) }
        }

        if !self.hasSessionCookies(candidate.cookies) {
            log("Candidate \(candidate.label) missing session cookies; skipping")
            return .loginRequired(candidate: candidate)
        }

        let scratch = WKWebsiteDataStore.nonPersistent()
        await self.setCookies(candidate.cookies, into: scratch)

        do {
            let probe = try await OpenAIDashboardFetcher().probeUsagePage(
                websiteDataStore: scratch,
                logger: log,
                timeout: 25)
            let signedInEmail = probe.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
            log("Candidate \(candidate.label) DOM email: \(signedInEmail ?? "unknown")")

            let resolvedEmail = signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let resolvedEmail, !resolvedEmail.isEmpty {
                if let targetEmail {
                    if resolvedEmail.lowercased() == targetEmail.lowercased() {
                        return .match(candidate: candidate, signedInEmail: resolvedEmail)
                    }
                    return .mismatch(candidate: candidate, signedInEmail: resolvedEmail)
                }
                if allowAnyAccount { return .loggedIn(candidate: candidate, signedInEmail: resolvedEmail) }
            }

            return .unknown(candidate: candidate)
        } catch OpenAIDashboardFetcher.FetchError.loginRequired {
            log("Candidate \(candidate.label) requires login.")
            return .loginRequired(candidate: candidate)
        } catch {
            log("Candidate \(candidate.label) probe error: \(error.localizedDescription)")
            return .unknown(candidate: candidate)
        }
    }

    func hasSessionCookies(_ cookies: [HTTPCookie]) -> Bool {
        for cookie in cookies {
            let name = cookie.name.lowercased()
            if name.contains("session-token") || name.contains("authjs") || name.contains("next-auth") {
                return true
            }
            if name == "_account" { return true }
        }
        return false
    }

    func handleMismatch(
        candidate: Candidate,
        signedInEmail: String,
        log: @escaping (String) -> Void,
        diagnostics: inout ImportDiagnostics) async
    {
        log("Candidate \(candidate.label) mismatch (\(signedInEmail)); continuing browser search")
        diagnostics.mismatches.append(FoundAccount(sourceLabel: candidate.label, email: signedInEmail))
        // Mismatch still means we found a valid signed-in session. Persist it keyed by its email so if
        // the user switches Codex accounts later, we can reuse this session immediately without another
        // Keychain prompt.
        await self.persistCookies(candidate: candidate, accountEmail: signedInEmail, logger: log)
    }
}
#endif
