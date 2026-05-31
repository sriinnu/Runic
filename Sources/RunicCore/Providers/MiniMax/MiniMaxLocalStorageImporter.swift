import Foundation

#if os(macOS)
struct MiniMaxLocalStorageToken {
    let accessToken: String
    let groupID: String?
    let sourceLabel: String
}

enum MiniMaxLocalStorageImporter {
    static func importTokens(logger: ((String) -> Void)? = nil) -> [MiniMaxLocalStorageToken] {
        let log: (String) -> Void = { msg in logger?("[minimax-storage] \(msg)") }
        var tokens: [MiniMaxLocalStorageToken] = []

        let candidates = self.chromeLocalStorageCandidates()
        if !candidates.isEmpty {
            log("Chromium local storage candidates: \(candidates.count)")
        }

        for candidate in candidates {
            guard let match = self.readToken(from: candidate.levelDBURL) else { continue }
            log("Found MiniMax access_token in \(candidate.label)")
            tokens.append(MiniMaxLocalStorageToken(
                accessToken: match.accessToken,
                groupID: match.groupID,
                sourceLabel: candidate.label))
        }

        if tokens.isEmpty {
            log("No MiniMax access_token found in Chromium local storage")
        }

        return tokens
    }

    private struct LocalStorageCandidate {
        let label: String
        let levelDBURL: URL
    }

    private struct TokenMatch {
        let accessToken: String
        let groupID: String?
    }

    private static func chromeLocalStorageCandidates() -> [LocalStorageCandidate] {
        let roots: [(url: URL, labelPrefix: String)] = self.candidateHomes().flatMap { home in
            let appSupport = home
                .appendingPathComponent("Library")
                .appendingPathComponent("Application Support")
            return [
                (appSupport.appendingPathComponent("Google").appendingPathComponent("Chrome"), "Chrome"),
                (appSupport.appendingPathComponent("Google").appendingPathComponent("Chrome Beta"), "Chrome Beta"),
                (appSupport.appendingPathComponent("Google").appendingPathComponent("Chrome Canary"), "Chrome Canary"),
                (appSupport.appendingPathComponent("Arc").appendingPathComponent("User Data"), "Arc"),
                (appSupport.appendingPathComponent("Arc Beta").appendingPathComponent("User Data"), "Arc Beta"),
                (appSupport.appendingPathComponent("Arc Canary").appendingPathComponent("User Data"), "Arc Canary"),
                (
                    appSupport
                        .appendingPathComponent("com.openai.atlas")
                        .appendingPathComponent("browser-data")
                        .appendingPathComponent("host"),
                    "ChatGPT Atlas"),
                (appSupport.appendingPathComponent("Chromium"), "Chromium"),
                (appSupport.appendingPathComponent("BraveSoftware").appendingPathComponent("Brave-Browser"), "Brave"),
                (appSupport.appendingPathComponent("Microsoft Edge"), "Edge"),
            ]
        }

        var candidates: [LocalStorageCandidate] = []
        for root in roots {
            candidates.append(contentsOf: self.chromeProfileLocalStorageDirs(
                root: root.url,
                labelPrefix: root.labelPrefix))
        }
        return candidates
    }

    private static func chromeProfileLocalStorageDirs(
        root: URL,
        labelPrefix: String) -> [LocalStorageCandidate]
    {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])
        else { return [] }

        let profileDirs = entries.filter { url in
            guard let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory), isDir else {
                return false
            }
            let name = url.lastPathComponent
            return name == "Default" || name.hasPrefix("Profile ") || name.hasPrefix("user-")
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return profileDirs.compactMap { dir in
            let levelDBURL = dir.appendingPathComponent("Local Storage").appendingPathComponent("leveldb")
            guard FileManager.default.fileExists(atPath: levelDBURL.path) else { return nil }
            let label = "\(labelPrefix) \(dir.lastPathComponent)"
            return LocalStorageCandidate(label: label, levelDBURL: levelDBURL)
        }
    }

    private static func candidateHomes() -> [URL] {
        var homes: [URL] = []
        homes.append(FileManager.default.homeDirectoryForCurrentUser)
        if let userHome = NSHomeDirectoryForUser(NSUserName()) {
            homes.append(URL(fileURLWithPath: userHome))
        }
        if let envHome = ProcessInfo.processInfo.environment["HOME"], !envHome.isEmpty {
            homes.append(URL(fileURLWithPath: envHome))
        }
        var seen = Set<String>()
        return homes.filter { home in
            let path = home.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }

    private static func readToken(from levelDBURL: URL) -> TokenMatch? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: levelDBURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])
        else { return nil }

        let files = entries.filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "ldb" || ext == "log"
        }
        .sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            return (left ?? .distantPast) > (right ?? .distantPast)
        }

        for file in files {
            guard let data = try? Data(contentsOf: file, options: [.mappedIfSafe]) else { continue }
            if let match = self.extractToken(from: data) {
                return match
            }
        }
        return nil
    }

    private static func extractToken(from data: Data) -> TokenMatch? {
        guard let contents = String(data: data, encoding: .utf8) ??
            String(data: data, encoding: .isoLatin1)
        else { return nil }

        if let match = self.matchToken(in: contents) {
            return match
        }

        let jwtCandidates = self.extractJWTs(from: contents)
        for token in jwtCandidates where self.isMiniMaxJWT(token) {
            let groupID = self.extractGroupID(from: contents) ?? self.groupID(from: token)
            return TokenMatch(accessToken: token, groupID: groupID)
        }

        return nil
    }

    private static func matchToken(in contents: String) -> TokenMatch? {
        guard contents.contains("minimax") || contents.contains("platform.minimax") else { return nil }

        let tokenPattern = "(?i)access_token[^A-Za-z0-9._-]*([A-Za-z0-9._-]{20,})"
        guard let token = MiniMaxWebParsing.firstCapture(in: contents, pattern: tokenPattern) else { return nil }
        guard self.isMiniMaxJWT(token) || contents.contains("minimax.io") else { return nil }

        let groupID = self.extractGroupID(from: contents) ?? self.groupID(from: token)
        return TokenMatch(accessToken: token, groupID: groupID)
    }

    private static func extractJWTs(from contents: String) -> [String] {
        let pattern = "[A-Za-z0-9_-]{20,}\\.[A-Za-z0-9_-]{20,}\\.[A-Za-z0-9_-]{20,}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
        return regex.matches(in: contents, options: [], range: range).compactMap { match in
            guard let range = Range(match.range(at: 0), in: contents) else { return nil }
            return String(contents[range])
        }
    }

    private static func isMiniMaxJWT(_ token: String) -> Bool {
        guard let payload = self.decodeJWTPayload(token) else { return false }
        return payload.values.contains { value in
            guard let string = value as? String else { return false }
            let lower = string.lowercased()
            return lower.contains("minimax") || lower.contains("platform.minimax.io")
        }
    }

    private static func groupID(from token: String) -> String? {
        guard let payload = self.decodeJWTPayload(token) else { return nil }
        if let groupID = payload["group_id"] as? String { return groupID }
        if let groupID = payload["groupId"] as? String { return groupID }
        return nil
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        let payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = payload + String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json
    }

    private static func extractGroupID(from contents: String) -> String? {
        if let match = MiniMaxWebParsing.firstCapture(
            in: contents,
            pattern: "(?i)group_id[^A-Za-z0-9_-]*([A-Za-z0-9_-]+)")
        {
            return match
        }
        if let match = MiniMaxWebParsing.firstCapture(
            in: contents,
            pattern: "(?i)groupId[^A-Za-z0-9_-]*([A-Za-z0-9_-]+)")
        {
            return match
        }
        return nil
    }
}
#endif
