import Foundation

#if os(macOS)
struct WorkOSAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let organizationID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case organizationID = "organization_id"
    }
}

extension FactoryStatusProbe {
    func fetchWorkOSAccessToken(
        refreshToken: String,
        organizationID: String?) async throws -> WorkOSAuthResponse
    {
        var lastError: Error?
        for clientID in Self.workosClientIDs {
            do {
                return try await self.fetchWorkOSAccessToken(
                    refreshToken: refreshToken,
                    organizationID: organizationID,
                    clientID: clientID)
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        throw FactoryStatusProbeError.networkError("WorkOS auth failed")
    }

    func fetchWorkOSAccessToken(
        refreshToken: String,
        organizationID: String?,
        clientID: String) async throws -> WorkOSAuthResponse
    {
        guard let url = URL(string: "https://api.workos.com/user_management/authenticate") else {
            throw FactoryStatusProbeError.networkError("WorkOS auth URL unavailable")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = self.timeout
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ]
        if let organizationID {
            body["organization_id"] = organizationID
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FactoryStatusProbeError.networkError("Invalid WorkOS response")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 400, Self.isMissingWorkOSRefreshToken(data) {
                throw FactoryStatusProbeError.noSessionCookie
            }
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "<binary>"
            let snippet = body.isEmpty ? "" : ": \(body.prefix(200))"
            throw FactoryStatusProbeError.networkError("WorkOS HTTP \(httpResponse.statusCode)\(snippet)")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(WorkOSAuthResponse.self, from: data)
    }

    func fetchWorkOSAccessTokenWithCookies(
        cookies: [HTTPCookie],
        logger: (String) -> Void) async throws -> WorkOSAuthResponse
    {
        let cookieHeader = Self.cookieHeader(from: cookies)
        guard !cookieHeader.isEmpty else {
            throw FactoryStatusProbeError.networkError("Missing WorkOS cookies")
        }

        var lastError: Error?
        for clientID in Self.workosClientIDs {
            do {
                return try await self.fetchWorkOSAccessTokenWithCookies(
                    cookieHeader: cookieHeader,
                    organizationID: nil,
                    clientID: clientID)
            } catch {
                lastError = error
                logger("WorkOS cookie auth failed for client \(clientID): \(error.localizedDescription)")
            }
        }
        if let lastError { throw lastError }
        throw FactoryStatusProbeError.networkError("WorkOS cookie auth failed")
    }

    func fetchWorkOSAccessTokenWithCookies(
        cookieHeader: String,
        organizationID: String?,
        clientID: String) async throws -> WorkOSAuthResponse
    {
        guard let url = URL(string: "https://api.workos.com/user_management/authenticate") else {
            throw FactoryStatusProbeError.networkError("WorkOS auth URL unavailable")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = self.timeout
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        var body: [String: Any] = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "useCookie": true,
        ]
        if let organizationID {
            body["organization_id"] = organizationID
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FactoryStatusProbeError.networkError("Invalid WorkOS response")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 400, Self.isMissingWorkOSRefreshToken(data) {
                throw FactoryStatusProbeError.noSessionCookie
            }
            let bodyText = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "<binary>"
            let snippet = bodyText.isEmpty ? "" : ": \(bodyText.prefix(200))"
            throw FactoryStatusProbeError.networkError("WorkOS HTTP \(httpResponse.statusCode)\(snippet)")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(WorkOSAuthResponse.self, from: data)
    }

    func isInvalidGrant(_ error: Error) -> Bool {
        guard case let FactoryStatusProbeError.networkError(message) = error else {
            return false
        }
        return message.localizedCaseInsensitiveContains("invalid_grant")
    }

    static func isMissingWorkOSRefreshToken(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return false
        }
        guard let description = json["error_description"] as? String else { return false }
        return description.localizedCaseInsensitiveContains("missing refresh token")
    }
}
#endif
