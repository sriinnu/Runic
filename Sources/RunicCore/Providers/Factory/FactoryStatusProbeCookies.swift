import Foundation

#if os(macOS)
extension FactoryStatusProbe {
    func fetchWithCookies(
        _ cookies: [HTTPCookie],
        logger: (String) -> Void) async throws -> FactoryStatusSnapshot
    {
        let candidates = Self.baseURLCandidates(default: self.baseURL, cookies: cookies)
        var lastError: Error?

        for baseURL in candidates {
            if baseURL != self.baseURL {
                logger("Trying Factory base URL: \(baseURL.host ?? baseURL.absoluteString)")
            }
            do {
                return try await self.fetchWithCookies(cookies, baseURL: baseURL, logger: logger)
            } catch {
                lastError = error
            }
        }

        if let lastError { throw lastError }
        throw FactoryStatusProbeError.noSessionCookie
    }

    func fetchWithCookies(
        _ cookies: [HTTPCookie],
        baseURL: URL,
        logger: (String) -> Void) async throws -> FactoryStatusSnapshot
    {
        let header = Self.cookieHeader(from: cookies)
        let bearerToken = Self.bearerToken(from: cookies)
        do {
            return try await self.fetchWithCookieHeader(header, bearerToken: bearerToken, baseURL: baseURL)
        } catch let error as FactoryStatusProbeError {
            if case .notLoggedIn = error, bearerToken != nil {
                logger("Retrying without Authorization header")
                return try await self.fetchWithCookieHeader(header, bearerToken: nil, baseURL: baseURL)
            }
            guard case let .networkError(message) = error,
                  message.contains("HTTP 409")
            else {
                throw error
            }

            var lastError: Error? = error
            if bearerToken != nil {
                logger("Retrying without Authorization header (HTTP 409)")
                do {
                    return try await self.fetchWithCookieHeader(header, bearerToken: nil, baseURL: baseURL)
                } catch {
                    lastError = error
                }
            }

            let retries: [(String, (HTTPCookie) -> Bool)] = [
                ("Retrying without access-token cookies", { !Self.staleTokenCookieNames.contains($0.name) }),
                ("Retrying without session cookies", { !Self.sessionCookieNames.contains($0.name) }),
                ("Retrying without access-token/session cookies", {
                    !Self.staleTokenCookieNames.contains($0.name) && !Self.sessionCookieNames.contains($0.name)
                }),
            ]

            for (label, predicate) in retries {
                let filtered = cookies.filter(predicate)
                guard filtered.count < cookies.count else { continue }
                logger(label)
                do {
                    let filteredBearer = Self.bearerToken(from: filtered)
                    return try await self.fetchWithCookieHeader(
                        Self.cookieHeader(from: filtered),
                        bearerToken: filteredBearer,
                        baseURL: baseURL)
                } catch let retryError as FactoryStatusProbeError {
                    switch retryError {
                    case let .networkError(retryMessage)
                        where retryMessage.contains("HTTP 409") &&
                        retryMessage.localizedCaseInsensitiveContains("stale token"):
                        lastError = retryError
                        continue
                    case .notLoggedIn:
                        lastError = retryError
                        continue
                    default:
                        throw retryError
                    }
                }
            }

            let authOnly = cookies.filter {
                Self.authSessionCookieNames.contains($0.name) || $0.name == "__Host-authjs.csrf-token"
            }
            if !authOnly.isEmpty, authOnly.count < cookies.count {
                logger("Retrying with auth session cookies only")
                do {
                    return try await self.fetchWithCookieHeader(
                        Self.cookieHeader(from: authOnly),
                        bearerToken: Self.bearerToken(from: authOnly),
                        baseURL: baseURL)
                } catch let retryError as FactoryStatusProbeError {
                    lastError = retryError
                }
            }

            if let lastError { throw lastError }
            throw error
        } catch {
            throw error
        }
    }

    static func cookieHeader(from cookies: [HTTPCookie]) -> String {
        cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    func fetchWithCookieHeader(
        _ cookieHeader: String,
        bearerToken: String?,
        baseURL: URL) async throws -> FactoryStatusSnapshot
    {
        let authInfo = try await self.fetchAuthInfo(
            cookieHeader: cookieHeader,
            bearerToken: bearerToken,
            baseURL: baseURL)
        let userId = self.extractUserIdFromAuth(authInfo)
        let usageData = try await self.fetchUsage(
            cookieHeader: cookieHeader,
            bearerToken: bearerToken,
            userId: userId,
            baseURL: baseURL)
        return self.buildSnapshot(authInfo: authInfo, usageData: usageData, userId: userId)
    }

    func fetchAuthInfo(
        cookieHeader: String,
        bearerToken: String?,
        baseURL: URL) async throws -> FactoryAuthResponse
    {
        let url = baseURL.appendingPathComponent("/api/app/auth/me")
        var request = URLRequest(url: url)
        request.timeoutInterval = self.timeout
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://app.factory.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://app.factory.ai/", forHTTPHeaderField: "Referer")
        if !cookieHeader.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        request.setValue("web-app", forHTTPHeaderField: "x-factory-client")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FactoryStatusProbeError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw FactoryStatusProbeError.notLoggedIn
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "<binary>"
            let snippet = body.isEmpty ? "" : ": \(body.prefix(200))"
            throw FactoryStatusProbeError.networkError("HTTP \(httpResponse.statusCode)\(snippet)")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(FactoryAuthResponse.self, from: data)
        } catch {
            let rawJSON = String(data: data, encoding: .utf8) ?? "<binary>"
            throw FactoryStatusProbeError
                .parseFailed("Auth decode failed: \(error.localizedDescription). Raw: \(rawJSON.prefix(200))")
        }
    }

    func fetchUsage(
        cookieHeader: String,
        bearerToken: String?,
        userId: String?,
        baseURL: URL) async throws -> FactoryUsageResponse
    {
        let url = baseURL.appendingPathComponent("/api/organization/subscription/usage")
        var request = URLRequest(url: url)
        request.timeoutInterval = self.timeout
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://app.factory.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://app.factory.ai/", forHTTPHeaderField: "Referer")
        if !cookieHeader.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        request.setValue("web-app", forHTTPHeaderField: "x-factory-client")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = ["useCache": true]
        if let userId {
            body["userId"] = userId
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FactoryStatusProbeError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw FactoryStatusProbeError.notLoggedIn
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "<binary>"
            let snippet = body.isEmpty ? "" : ": \(body.prefix(200))"
            throw FactoryStatusProbeError.networkError("HTTP \(httpResponse.statusCode)\(snippet)")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(FactoryUsageResponse.self, from: data)
        } catch {
            let rawJSON = String(data: data, encoding: .utf8) ?? "<binary>"
            throw FactoryStatusProbeError
                .parseFailed("Usage decode failed: \(error.localizedDescription). Raw: \(rawJSON.prefix(200))")
        }
    }

    static func baseURLCandidates(default baseURL: URL, cookies: [HTTPCookie]) -> [URL] {
        let cookieDomains = Set(
            cookies.map {
                $0.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            })

        var candidates: [URL] = []
        if cookieDomains.contains("auth.factory.ai") {
            candidates.append(Self.authBaseURL)
        }
        candidates.append(Self.apiBaseURL)
        candidates.append(Self.appBaseURL)
        candidates.append(baseURL)

        var seen = Set<String>()
        return candidates.filter { url in
            let key = url.absoluteString
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    static func bearerToken(from cookies: [HTTPCookie]) -> String? {
        let accessToken = cookies.first(where: { $0.name == "access-token" })?.value
        let sessionToken = cookies.first(where: { Self.authSessionCookieNames.contains($0.name) })?.value
        let legacySession = cookies.first(where: { $0.name == "session" })?.value

        if let accessToken, accessToken.contains(".") {
            return accessToken
        }
        if let sessionToken, sessionToken.contains(".") {
            return sessionToken
        }
        if let legacySession, legacySession.contains(".") {
            return legacySession
        }
        return accessToken ?? sessionToken
    }

    func fetchWithBearerToken(
        _ bearerToken: String,
        logger: (String) -> Void) async throws -> FactoryStatusSnapshot
    {
        let candidates = [Self.apiBaseURL, self.baseURL]
        var lastError: Error?
        for baseURL in candidates {
            if baseURL != Self.apiBaseURL {
                logger("Trying Factory bearer base URL: \(baseURL.host ?? baseURL.absoluteString)")
            }
            do {
                return try await self.fetchWithCookieHeader(
                    "",
                    bearerToken: bearerToken,
                    baseURL: baseURL)
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        throw FactoryStatusProbeError.notLoggedIn
    }
}
#endif
