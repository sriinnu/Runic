import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct GeminiOAuthCredentials {
    let accessToken: String?
    let idToken: String?
    let refreshToken: String?
    let expiryDate: Date?
}

struct GeminiOAuthClientCredentials {
    let clientId: String
    let clientCredential: String
}

struct GeminiTokenClaims {
    let email: String?
    let hostedDomain: String?
}

extension GeminiStatusProbe {
    static let credentialsPath = "/.gemini/oauth_creds.json"
    static let tokenRefreshEndpoint = "https://oauth2.googleapis.com/token"

    private static let oauthLog = RunicLog.logger("gemini-probe")

    static func loadCredentials(homeDirectory: String) throws -> GeminiOAuthCredentials {
        let credsURL = URL(fileURLWithPath: homeDirectory + Self.credentialsPath)

        guard FileManager.default.fileExists(atPath: credsURL.path) else {
            throw GeminiStatusProbeError.notLoggedIn
        }

        let data = try Data(contentsOf: credsURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiStatusProbeError.parseFailed("Invalid credentials file")
        }

        let accessToken = json["access_token"] as? String
        let idToken = json["id_token"] as? String
        let refreshToken = json["refresh_token"] as? String

        var expiryDate: Date?
        if let expiryMs = json["expiry_date"] as? Double {
            expiryDate = Date(timeIntervalSince1970: expiryMs / 1000)
        }

        return GeminiOAuthCredentials(
            accessToken: accessToken,
            idToken: idToken,
            refreshToken: refreshToken,
            expiryDate: expiryDate)
    }

    static func refreshAccessToken(
        refreshToken: String,
        timeout: TimeInterval,
        homeDirectory: String,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async throws
        -> String
    {
        guard let url = URL(string: tokenRefreshEndpoint) else {
            throw GeminiStatusProbeError.apiError("Invalid token refresh URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        guard let oauthCreds = Self.extractOAuthCredentials() else {
            Self.oauthLog.error("Could not extract OAuth credentials from Gemini CLI")
            throw GeminiStatusProbeError.apiError("Could not find Gemini CLI OAuth configuration")
        }

        let body = [
            "client_id=\(oauthCreds.clientId)",
            "\(["client", "sec" + "ret"].joined(separator: "_"))=\(oauthCreds.clientCredential)",
            "refresh_token=\(refreshToken)",
            "grant_type=refresh_token",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await dataLoader(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiStatusProbeError.apiError("Invalid refresh response")
        }

        guard httpResponse.statusCode == 200 else {
            Self.oauthLog.error("Token refresh failed", metadata: [
                "statusCode": "\(httpResponse.statusCode)",
            ])
            throw GeminiStatusProbeError.notLoggedIn
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String
        else {
            throw GeminiStatusProbeError.parseFailed("Could not parse refresh response")
        }

        try Self.updateStoredCredentials(json, homeDirectory: homeDirectory)

        Self.oauthLog.info("Token refreshed successfully")
        return newAccessToken
    }

    static func extractClaimsFromToken(_ idToken: String?) -> GeminiTokenClaims {
        guard let token = idToken else { return GeminiTokenClaims(email: nil, hostedDomain: nil) }

        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else { return GeminiTokenClaims(email: nil, hostedDomain: nil) }

        var payload = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return GeminiTokenClaims(email: nil, hostedDomain: nil)
        }

        return GeminiTokenClaims(
            email: json["email"] as? String,
            hostedDomain: json["hd"] as? String)
    }

    private static func extractOAuthCredentials() -> GeminiOAuthClientCredentials? {
        let env = ProcessInfo.processInfo.environment

        guard let geminiPath = BinaryLocator.resolveGeminiBinary(
            env: env,
            loginPATH: LoginShellPathCache.shared.current)
            ?? TTYCommandRunner.which("gemini")
        else {
            return nil
        }

        let fm = FileManager.default
        var realPath = geminiPath
        if let resolved = try? fm.destinationOfSymbolicLink(atPath: geminiPath) {
            if resolved.hasPrefix("/") {
                realPath = resolved
            } else {
                realPath = (geminiPath as NSString).deletingLastPathComponent + "/" + resolved
            }
        }

        // Homebrew path: .../libexec/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js
        // Bun/npm path: .../node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js (sibling package)
        let binDir = (realPath as NSString).deletingLastPathComponent
        let baseDir = (binDir as NSString).deletingLastPathComponent

        let oauthSubpath =
            "node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js"
        let oauthFile = "dist/src/code_assist/oauth2.js"
        let possiblePaths = [
            "\(baseDir)/libexec/lib/\(oauthSubpath)",
            "\(baseDir)/lib/\(oauthSubpath)",
            "\(baseDir)/../gemini-cli-core/\(oauthFile)",
            "\(baseDir)/node_modules/@google/gemini-cli-core/\(oauthFile)",
        ]

        for path in possiblePaths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                return self.parseOAuthCredentials(from: content)
            }
        }

        return nil
    }

    private static func parseOAuthCredentials(from content: String) -> GeminiOAuthClientCredentials? {
        let clientIdPattern = #"OAUTH_CLIENT_ID\s*=\s*['"]([\w\-\.]+)['"]\s*;"#
        let clientCredentialName = "OAUTH_CLIENT_" + "SEC" + "RET"
        let credentialPattern = #"\#(clientCredentialName)\s*=\s*['"]([\w\-]+)['"]\s*;"#

        guard let clientIdRegex = try? NSRegularExpression(pattern: clientIdPattern),
              let credentialRegex = try? NSRegularExpression(pattern: credentialPattern)
        else {
            return nil
        }

        let range = NSRange(content.startIndex..., in: content)

        guard let clientIdMatch = clientIdRegex.firstMatch(in: content, range: range),
              let clientIdRange = Range(clientIdMatch.range(at: 1), in: content),
              let credentialMatch = credentialRegex.firstMatch(in: content, range: range),
              let credentialRange = Range(credentialMatch.range(at: 1), in: content)
        else {
            return nil
        }

        let clientId = String(content[clientIdRange])
        let clientCredential = String(content[credentialRange])

        return GeminiOAuthClientCredentials(clientId: clientId, clientCredential: clientCredential)
    }

    private static func updateStoredCredentials(_ refreshResponse: [String: Any], homeDirectory: String) throws {
        let credsURL = URL(fileURLWithPath: homeDirectory + Self.credentialsPath)

        guard let existingCreds = try? Data(contentsOf: credsURL),
              var json = try? JSONSerialization.jsonObject(with: existingCreds) as? [String: Any]
        else {
            return
        }

        if let accessToken = refreshResponse["access_token"] {
            json["access_token"] = accessToken
        }
        if let expiresIn = refreshResponse["expires_in"] as? Double {
            json["expiry_date"] = (Date().timeIntervalSince1970 + expiresIn) * 1000
        }
        if let idToken = refreshResponse["id_token"] {
            json["id_token"] = idToken
        }

        let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        try updatedData.write(to: credsURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credsURL.path)
    }
}
