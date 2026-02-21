import Foundation

public struct GitCommit: Codable, Sendable, Hashable {
    public let sha: String
    public let shortSha: String
    public let message: String
    public let author: String
    public let timestamp: Date

    public init(sha: String, shortSha: String, message: String, author: String, timestamp: Date) {
        self.sha = sha
        self.shortSha = shortSha
        self.message = message
        self.author = author
        self.timestamp = timestamp
    }
}

public struct UsageWithCommit: Codable, Sendable, Hashable {
    public let entry: UsageLedgerEntry
    public let commit: GitCommit?

    public init(entry: UsageLedgerEntry, commit: GitCommit?) {
        self.entry = entry
        self.commit = commit
    }
}

public enum GitHubIntegration {
    private static let logger = RunicLog.logger("github-integration")
    private static let commitMatchWindow: TimeInterval = 300 // 5 minutes

    public static func linkCommitsToUsage(
        entries: [UsageLedgerEntry],
        gitDirectory: URL? = nil) -> [UsageWithCommit]
    {
        guard !entries.isEmpty else { return [] }

        let gitDir = gitDirectory ?? defaultGitDirectory()
        let commits = loadCommits(from: gitDir)

        guard !commits.isEmpty else {
            self.logger.debug("No git commits found, returning entries without commit info")
            return entries.map { UsageWithCommit(entry: $0, commit: nil) }
        }

        self.logger.debug("Linking \(entries.count) usage entries with \(commits.count) commits")

        return entries.map { entry in
            let matchedCommit = findClosestCommit(for: entry, in: commits)
            return UsageWithCommit(entry: entry, commit: matchedCommit)
        }
    }

    private static func defaultGitDirectory() -> URL {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        return URL(fileURLWithPath: currentDirectory).appendingPathComponent(".git")
    }

    private static func loadCommits(from gitDirectory: URL) -> [GitCommit] {
        let headLogPath = gitDirectory.appendingPathComponent("logs/HEAD")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: headLogPath.path) else {
            self.logger.warning("Git HEAD log not found at \(headLogPath.path)")
            return []
        }

        guard let contents = try? String(contentsOf: headLogPath, encoding: .utf8) else {
            self.logger.error("Failed to read git HEAD log at \(headLogPath.path)")
            return []
        }

        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var commits: [GitCommit] = []

        for line in lines {
            if let commit = parseCommitLine(line) {
                commits.append(commit)
            }
        }

        self.logger.debug("Parsed \(commits.count) commits from git log")
        return commits
    }

    private static func parseCommitLine(_ line: String) -> GitCommit? {
        // Format: old_sha new_sha Author Name <email> timestamp timezone\tcommit: message
        // Example: 0000000000000000000000000000000000000000 538b8f7ef4110664c161b13326a2ebe65b6a1fb0 Sriinnu <hello@srinivas.dev> 1767822510 +0100\tcommit (initial): Add Runic sources

        let parts = line.components(separatedBy: "\t")
        guard parts.count >= 2 else {
            self.logger.trace("Skipping malformed git log line (no tab separator)")
            return nil
        }

        let headerPart = parts[0]
        let messagePart = parts[1]

        // Parse header: old_sha new_sha author timestamp timezone
        let headerComponents = headerPart.components(separatedBy: " ")
        guard headerComponents.count >= 5 else {
            self.logger.trace("Skipping malformed git log header")
            return nil
        }

        let newSha = headerComponents[1]
        guard newSha != "0000000000000000000000000000000000000000" else {
            self.logger.trace("Skipping null SHA")
            return nil
        }

        // Extract timestamp (Unix epoch)
        let timestampIndex = headerComponents.count - 2
        guard let timestampValue = Double(headerComponents[timestampIndex]) else {
            self.logger.trace("Failed to parse timestamp from git log")
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: timestampValue)

        // Extract author (everything between sha and timestamp)
        let authorEndIndex = timestampIndex
        let authorComponents = Array(headerComponents[2..<authorEndIndex])
        let author = authorComponents.joined(separator: " ")

        // Extract message (remove "commit: " or "commit (initial): " prefix if present)
        var message = messagePart
        if message.hasPrefix("commit: ") {
            message = String(message.dropFirst(8))
        } else if message.hasPrefix("commit (initial): ") {
            message = String(message.dropFirst(18))
        } else if message.contains(": ") {
            // Handle other prefixes like "pull", "merge", "rebase", etc.
            if let colonIndex = message.firstIndex(of: ":") {
                message = String(message[message.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        let shortSha = String(newSha.prefix(7))

        return GitCommit(
            sha: newSha,
            shortSha: shortSha,
            message: message,
            author: author,
            timestamp: timestamp)
    }

    private static func findClosestCommit(
        for entry: UsageLedgerEntry,
        in commits: [GitCommit]) -> GitCommit?
    {
        // Find commits within the 5-minute window
        let entryTime = entry.timestamp
        let matchingCommits = commits.filter { commit in
            let timeDiff = abs(commit.timestamp.timeIntervalSince(entryTime))
            return timeDiff <= self.commitMatchWindow
        }

        guard !matchingCommits.isEmpty else {
            return nil
        }

        // Return the commit with the smallest time difference
        return matchingCommits.min { commit1, commit2 in
            let diff1 = abs(commit1.timestamp.timeIntervalSince(entryTime))
            let diff2 = abs(commit2.timestamp.timeIntervalSince(entryTime))
            return diff1 < diff2
        }
    }
}
