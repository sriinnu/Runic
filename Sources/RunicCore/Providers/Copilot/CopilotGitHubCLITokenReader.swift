import Foundation

public enum CopilotGitHubCLITokenReader {
    private static let tokenPrefixes = [
        "gho_",
        "ghp_",
        "ghu_",
        "ghs_",
        "ghr_",
        "github_pat_",
        "v1.",
    ]

    public static func token(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        for path in self.candidateHostConfigPaths(environment: environment) {
            guard let raw = try? String(contentsOf: path, encoding: .utf8) else { continue }
            if let token = self.token(fromHostsYAML: raw) {
                return token
            }
        }
        return nil
    }

    public static func token(fromHostsYAML yamlText: String) -> String? {
        var insideGithubHost = false

        for rawLine in yamlText.components(separatedBy: .newlines) {
            let line = rawLine
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            let firstCharacter = line.first
            let hasIndent = firstCharacter?.isWhitespace == true
            if !hasIndent {
                insideGithubHost = self.isGithubHostLine(trimmedLine)
                continue
            }

            guard insideGithubHost else { continue }
            if let token = self.extractOAuthToken(from: trimmedLine) {
                return token
            }
        }
        return nil
    }

    private static func isGithubHostLine(_ line: String) -> Bool {
        guard line.hasSuffix(":") else { return false }
        let host = String(line.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        return host == "github.com"
    }

    private static func extractOAuthToken(from trimmedLine: String) -> String? {
        guard let separator = trimmedLine.firstIndex(of: ":") else { return nil }
        let key = trimmedLine[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
        guard key == "oauth_token" else { return nil }

        let value = String(trimmedLine[trimmedLine.index(after: separator)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))

        guard self.isLikelyGitHubToken(value) else { return nil }
        return value
    }

    private static func isLikelyGitHubToken(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        return tokenPrefixes.contains { token.hasPrefix($0) }
    }

    private static func candidateHostConfigPaths(environment: [String: String]) -> [URL] {
        var candidates: [URL] = []
        var seen: Set<String> = []

        func addCandidate(_ url: URL) {
            let normalized = url.standardizedFileURL.path
            if seen.insert(normalized).inserted {
                candidates.append(url)
            }
        }

        if let ghConfigDir = self.trimmed(environment["GH_CONFIG_DIR"]) {
            let resolvedGHConfig = URL(fileURLWithPath: ghConfigDir)
            if resolvedGHConfig.pathExtension == "yml" || resolvedGHConfig.lastPathComponent == "hosts.yml" {
                addCandidate(resolvedGHConfig)
            } else {
                addCandidate(resolvedGHConfig.appendingPathComponent("hosts.yml"))
            }
        }

        var homes = [FileManager.default.homeDirectoryForCurrentUser.path]
        if let home = self.trimmed(environment["HOME"]), home != FileManager.default.homeDirectoryForCurrentUser.path {
            homes.append(home)
        }

        for home in homes {
            let homeURL = URL(fileURLWithPath: home)
            addCandidate(homeURL.appendingPathComponent(".config").appendingPathComponent("gh").appendingPathComponent("hosts.yml"))
            addCandidate(homeURL.appendingPathComponent("Library").appendingPathComponent("Application Support").appendingPathComponent("gh").appendingPathComponent("hosts.yml"))
            addCandidate(homeURL.appendingPathComponent(".local").appendingPathComponent("share").appendingPathComponent("gh").appendingPathComponent("hosts.yml"))
        }

        return candidates
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
