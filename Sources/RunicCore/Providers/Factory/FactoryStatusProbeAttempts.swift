import Foundation
import Silo

#if os(macOS)
extension FactoryStatusProbe {
    func attemptBrowserCookies(
        logger: @escaping (String) -> Void,
        sources: [Browser]) async -> FetchAttemptResult
    {
        do {
            var lastError: Error?
            for browserSource in sources {
                let sessions = try FactoryCookieImporter.importSessions(from: browserSource, logger: logger)
                for session in sessions {
                    logger("Using cookies from \(session.sourceLabel)")
                    do {
                        let snapshot = try await self.fetchWithCookies(session.cookies, logger: logger)
                        await FactorySessionStore.shared.setCookies(session.cookies)
                        return .success(snapshot)
                    } catch {
                        lastError = error
                        logger("Browser session fetch failed for \(session.sourceLabel): \(error.localizedDescription)")
                    }
                }
            }
            if let lastError { return .failure(lastError) }
            return .skipped
        } catch {
            logger("Browser cookie import failed: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    func attemptStoredCookies(logger: (String) -> Void) async -> FetchAttemptResult {
        let storedCookies = await FactorySessionStore.shared.getCookies()
        guard !storedCookies.isEmpty else { return .skipped }
        logger("Using stored session cookies")
        do {
            return try await .success(self.fetchWithCookies(storedCookies, logger: logger))
        } catch {
            if case FactoryStatusProbeError.notLoggedIn = error {
                await FactorySessionStore.shared.clearSession()
                logger("Stored session invalid, cleared")
            } else {
                logger("Stored session failed: \(error.localizedDescription)")
            }
            return .failure(error)
        }
    }

    func attemptStoredBearer(logger: (String) -> Void) async -> FetchAttemptResult {
        guard let bearerToken = await FactorySessionStore.shared.getBearerToken() else { return .skipped }
        logger("Using stored Factory bearer token")
        do {
            return try await .success(self.fetchWithBearerToken(bearerToken, logger: logger))
        } catch {
            return .failure(error)
        }
    }

    func attemptStoredRefreshToken(logger: (String) -> Void) async -> FetchAttemptResult {
        guard let refreshToken = await FactorySessionStore.shared.getRefreshToken(),
              !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .skipped
        }
        logger("Using stored WorkOS refresh token")
        do {
            return try await .success(self.fetchWithWorkOSRefreshToken(
                refreshToken,
                organizationID: nil,
                logger: logger))
        } catch {
            if self.isInvalidGrant(error) {
                await FactorySessionStore.shared.setRefreshToken(nil)
            } else if case FactoryStatusProbeError.noSessionCookie = error {
                await FactorySessionStore.shared.setRefreshToken(nil)
            }
            return .failure(error)
        }
    }

    func attemptLocalStorageTokens(logger: @escaping (String) -> Void) async -> FetchAttemptResult {
        let workosTokens = FactoryLocalStorageImporter.importWorkOSTokens(logger: logger)
        guard !workosTokens.isEmpty else { return .skipped }
        var lastError: Error?
        for token in workosTokens {
            guard !token.refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            logger("Using WorkOS refresh token from \(token.sourceLabel)")
            if let accessToken = token.accessToken {
                do {
                    await FactorySessionStore.shared.setBearerToken(accessToken)
                    return try await .success(self.fetchWithBearerToken(accessToken, logger: logger))
                } catch {
                    lastError = error
                }
            }
            do {
                return try await .success(self.fetchWithWorkOSRefreshToken(
                    token.refreshToken,
                    organizationID: token.organizationID,
                    logger: logger))
            } catch {
                if self.isInvalidGrant(error) {
                    await FactorySessionStore.shared.setRefreshToken(nil)
                }
                lastError = error
            }
        }
        if let lastError { return .failure(lastError) }
        return .skipped
    }

    func attemptWorkOSCookies(
        logger: @escaping (String) -> Void,
        sources: [Browser]) async -> FetchAttemptResult
    {
        let log: (String) -> Void = { msg in logger("[factory-workos] \(msg)") }
        var lastError: Error?

        for browserSource in sources {
            do {
                let query = BrowserCookieQuery(domains: ["workos.com"])
                let sources = try BrowserCookieClient().records(
                    matching: query,
                    in: browserSource)
                for source in sources where !source.records.isEmpty {
                    let cookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
                    guard !cookies.isEmpty else { continue }
                    log("Using WorkOS cookies from \(source.label)")
                    do {
                        let auth = try await self.fetchWorkOSAccessTokenWithCookies(
                            cookies: cookies,
                            logger: logger)
                        await FactorySessionStore.shared.setBearerToken(auth.accessToken)
                        if let refreshToken = auth.refreshToken {
                            await FactorySessionStore.shared.setRefreshToken(refreshToken)
                        }
                        return try await .success(self.fetchWithBearerToken(auth.accessToken, logger: logger))
                    } catch {
                        lastError = error
                        log("WorkOS cookie auth failed for \(source.label): \(error.localizedDescription)")
                    }
                }
            } catch {
                log("\(browserSource.displayName) WorkOS cookie import failed: \(error.localizedDescription)")
                lastError = error
            }
        }

        if let lastError { return .failure(lastError) }
        return .skipped
    }

    func fetchWithWorkOSRefreshToken(
        _ refreshToken: String,
        organizationID: String?,
        logger: (String) -> Void) async throws -> FactoryStatusSnapshot
    {
        let auth = try await self.fetchWorkOSAccessToken(
            refreshToken: refreshToken,
            organizationID: organizationID)
        await FactorySessionStore.shared.setBearerToken(auth.accessToken)
        if let newRefresh = auth.refreshToken {
            await FactorySessionStore.shared.setRefreshToken(newRefresh)
        }
        return try await self.fetchWithBearerToken(auth.accessToken, logger: logger)
    }
}
#endif
