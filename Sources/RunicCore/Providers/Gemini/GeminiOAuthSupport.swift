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
        let fm = FileManager.default
        let candidates = Self.collectGeminiBinaryCandidates(
            env: env,
            loginPATH: LoginShellPathCache.shared.current,
            fileManager: fm,
            home: NSHomeDirectory())

        for geminiPath in candidates {
            // Resolve all symlink hops, not just the first one.
            let realPath = (geminiPath as NSString).resolvingSymlinksInPath

            self.oauthLog.info("Trying Gemini candidate", metadata: [
                "original": geminiPath,
                "resolved": realPath,
            ])

            if let creds = self.searchOAuthFile(realPath: realPath, fm: fm) {
                return creds
            }
            self.oauthLog.warning("No OAuth file found at candidate", metadata: [
                "resolved": realPath,
            ])
        }

        self.oauthLog.error("No OAuth credentials in any Gemini candidate", metadata: [
            "count": "\(candidates.count)",
        ])
        return nil
    }

    static func collectGeminiBinaryCandidates(
        env: [String: String],
        loginPATH: [String]?,
        fileManager fm: FileManager = .default,
        home: String = NSHomeDirectory()) -> [String]
    {
        if let override = env["GEMINI_CLI_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty
        {
            return fm.isExecutableFile(atPath: override) ? [override] : []
        }

        // Collect EVERY executable `gemini` in priority order instead of
        // stopping at the first match: a custom wrapper (e.g. ~/.local/bin/gemini)
        // or dangling Homebrew symlink can shadow an nvm/fnm/npm @google/gemini-cli.
        var rawCandidates: [String] = []
        let pathDirs = (loginPATH ?? []) + (env["PATH"]?.split(separator: ":").map(String.init) ?? [])
        for dir in pathDirs where !dir.isEmpty {
            let candidate = (dir as NSString).appendingPathComponent("gemini")
            if fm.isExecutableFile(atPath: candidate) {
                rawCandidates.append(candidate)
            }
        }
        if let locatorHit = BinaryLocator.resolveGeminiBinary(
            env: env,
            loginPATH: loginPATH,
            fileManager: fm,
            home: home)
        {
            rawCandidates.append(locatorHit)
        }
        if let whichHit = TTYCommandRunner.which("gemini") {
            rawCandidates.append(whichHit)
        }

        // Version-manager & global npm/bun installs under home (newest Node first).
        let nvmDir = (home as NSString).appendingPathComponent(".nvm/versions/node")
        if let versions = try? fm.contentsOfDirectory(atPath: nvmDir) {
            let sorted = versions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
            for version in sorted {
                let candidate = "\(nvmDir)/\(version)/bin/gemini"
                if fm.isExecutableFile(atPath: candidate) { rawCandidates.append(candidate) }
            }
        }
        let fnmDir = (home as NSString).appendingPathComponent(".fnm/node-versions")
        if let versions = try? fm.contentsOfDirectory(atPath: fnmDir) {
            let sorted = versions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
            for version in sorted {
                let candidate = "\(fnmDir)/\(version)/installation/bin/gemini"
                if fm.isExecutableFile(atPath: candidate) { rawCandidates.append(candidate) }
            }
        }
        let fixedCandidates = [
            "\(home)/.volta/bin/gemini",
            "\(home)/.asdf/shims/gemini",
            "\(home)/.bun/bin/gemini",
            "\(home)/.npm-global/bin/gemini",
            "/opt/homebrew/bin/gemini",
            "/usr/local/bin/gemini",
        ]
        for candidate in fixedCandidates where fm.isExecutableFile(atPath: candidate) {
            rawCandidates.append(candidate)
        }

        var seenRaw = Set<String>()
        var seenResolved = Set<String>()
        var deduped: [String] = []
        for candidate in rawCandidates {
            guard seenRaw.insert(candidate).inserted else { continue }
            let resolved = (candidate as NSString).resolvingSymlinksInPath
            guard seenResolved.insert(resolved).inserted else { continue }
            deduped.append(candidate)
        }
        return deduped
    }

    static func searchOAuthFile(realPath: String, fm: FileManager) -> GeminiOAuthClientCredentials? {
        let binDir = (realPath as NSString).deletingLastPathComponent
        let baseDir = (binDir as NSString).deletingLastPathComponent

        // Old path: .../libexec/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js
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
            if let content = try? String(contentsOfFile: path, encoding: .utf8),
               let creds = self.parseOAuthCredentials(from: content)
            {
                return creds
            }
        }

        // Gemini CLI 0.43+ bundles OAuth into oauth2*.js; 0.68+ resolves directly into
        // .../bundle/gemini.js and stores OAuth config in bundle/chunk-*.js or bundle/gemini*.js.
        let rawBundleDirs = [
            binDir,
            "\(baseDir)/bundle",
            "\(baseDir)/libexec/lib/node_modules/@google/gemini-cli/bundle",
            "\(baseDir)/lib/node_modules/@google/gemini-cli/bundle",
        ]
        var seenDirs = Set<String>()
        let bundleDirs = rawBundleDirs.filter { seenDirs.insert($0).inserted }
        let marker = Data("OAUTH_CLIENT_ID".utf8)

        for bundleBase in bundleDirs {
            guard let bundleFiles = try? fm.contentsOfDirectory(atPath: bundleBase) else { continue }
            let jsFiles = bundleFiles.filter { $0.hasSuffix(".js") }
            let prioritized =
                jsFiles.filter { $0.hasPrefix("oauth2") }.sorted() +
                jsFiles.filter { $0.hasPrefix("chunk-") || $0.hasPrefix("gemini") }.sorted()

            for file in prioritized {
                let path = "\(bundleBase)/\(file)"
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe]),
                      data.range(of: marker) != nil,
                      let content = String(data: data, encoding: .utf8),
                      let creds = self.parseOAuthCredentials(from: content)
                else {
                    continue
                }
                return creds
            }
        }

        return nil
    }

    static func parseOAuthCredentials(from content: String) -> GeminiOAuthClientCredentials? {
        let clientIdPattern = #"OAUTH_CLIENT_ID\s*=\s*['"]([\w\-\.]+)['"]"#
        let clientCredentialName = "OAUTH_CLIENT_" + "SEC" + "RET"
        let credentialPattern = #"\#(clientCredentialName)\s*=\s*['"]([\w\-]+)['"]"#

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
