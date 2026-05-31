import Foundation

public struct ClaudeStatusSnapshot: Sendable {
    public let sessionPercentLeft: Int?
    public let weeklyPercentLeft: Int?
    public let opusPercentLeft: Int?
    public let accountEmail: String?
    public let accountOrganization: String?
    public let loginMethod: String?
    public let primaryResetDescription: String?
    public let secondaryResetDescription: String?
    public let opusResetDescription: String?
    public let rawText: String
}

public struct ClaudeAccountIdentity: Sendable {
    public let accountEmail: String?
    public let accountOrganization: String?
    public let loginMethod: String?

    public init(accountEmail: String?, accountOrganization: String?, loginMethod: String?) {
        self.accountEmail = accountEmail
        self.accountOrganization = accountOrganization
        self.loginMethod = loginMethod
    }
}

public enum ClaudeStatusProbeError: LocalizedError, Sendable {
    case claudeNotInstalled
    case parseFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .claudeNotInstalled:
            "Claude CLI is not installed or not on PATH."
        case let .parseFailed(msg):
            "Could not parse Claude usage: \(msg)"
        case .timedOut:
            "Claude usage probe timed out."
        }
    }
}

/// Runs `claude` inside a PTY, sends `/usage`, and parses the rendered text panel.
public struct ClaudeStatusProbe: Sendable {
    public var claudeBinary: String = "claude"
    public var timeout: TimeInterval = 20.0
    private static let log = RunicLog.logger("claude-probe")

    public init(claudeBinary: String = "claude", timeout: TimeInterval = 20.0) {
        self.claudeBinary = claudeBinary
        self.timeout = timeout
    }

    public func fetch() async throws -> ClaudeStatusSnapshot {
        let env = ProcessInfo.processInfo.environment
        let resolved = BinaryLocator.resolveClaudeBinary(env: env, loginPATH: LoginShellPathCache.shared.current)
            ?? TTYCommandRunner.which(self.claudeBinary)
            ?? self.claudeBinary
        guard FileManager.default.isExecutableFile(atPath: resolved) || TTYCommandRunner.which(resolved) != nil else {
            throw ClaudeStatusProbeError.claudeNotInstalled
        }

        // Run commands sequentially through a shared Claude session to avoid warm-up churn.
        let timeout = self.timeout
        let usage = try await Self.capture(subcommand: "/usage", binary: resolved, timeout: timeout)
        let status = try? await Self.capture(subcommand: "/status", binary: resolved, timeout: min(timeout, 12))
        let snap = try Self.parse(text: usage, statusText: status)

        Self.log.info("Claude CLI scrape ok", metadata: [
            "sessionPercentLeft": "\(snap.sessionPercentLeft ?? -1)",
            "weeklyPercentLeft": "\(snap.weeklyPercentLeft ?? -1)",
            "opusPercentLeft": "\(snap.opusPercentLeft ?? -1)",
        ])
        return snap
    }

    public static func fetchIdentity(timeout: TimeInterval = 12.0) async throws -> ClaudeAccountIdentity {
        let env = ProcessInfo.processInfo.environment
        let resolved = BinaryLocator.resolveClaudeBinary(env: env, loginPATH: LoginShellPathCache.shared.current)
            ?? TTYCommandRunner.which("claude")
            ?? "claude"
        guard FileManager.default.isExecutableFile(atPath: resolved) || TTYCommandRunner.which(resolved) != nil else {
            throw ClaudeStatusProbeError.claudeNotInstalled
        }
        let statusText = try await Self.capture(subcommand: "/status", binary: resolved, timeout: timeout)
        return Self.parseIdentity(usageText: nil, statusText: statusText)
    }

    // MARK: - Dump storage (in-memory ring buffer)

    @MainActor private static var recentDumps: [String] = []

    @MainActor static func recordDump(_ text: String) {
        if self.recentDumps.count >= 5 { self.recentDumps.removeFirst() }
        self.recentDumps.append(text)
    }

    public static func latestDumps() async -> String {
        await MainActor.run {
            let result = Self.recentDumps.joined(separator: "\n\n---\n\n")
            return result.isEmpty ? "No Claude parse dumps captured yet." : result
        }
    }

    // MARK: - Process helpers

    static func probeWorkingDirectoryURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base
            .appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("ClaudeProbe", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return fm.temporaryDirectory
        }
    }

    /// Run claude CLI inside a PTY so we can respond to interactive permission prompts.
    private static func capture(subcommand: String, binary: String, timeout: TimeInterval) async throws -> String {
        let stopOnSubstrings = subcommand == "/usage" ? ["Current session"] : []
        do {
            return try await ClaudeCLISession.shared.capture(
                subcommand: subcommand,
                binary: binary,
                timeout: timeout,
                idleTimeout: 3.0,
                stopOnSubstrings: stopOnSubstrings,
                settleAfterStop: subcommand == "/usage" ? 2.0 : 0.25,
                sendEnterEvery: nil)
        } catch ClaudeCLISession.SessionError.processExited {
            await ClaudeCLISession.shared.reset()
            throw ClaudeStatusProbeError.timedOut
        } catch ClaudeCLISession.SessionError.timedOut {
            throw ClaudeStatusProbeError.timedOut
        } catch ClaudeCLISession.SessionError.launchFailed(_) {
            throw ClaudeStatusProbeError.claudeNotInstalled
        } catch {
            await ClaudeCLISession.shared.reset()
            throw error
        }
    }
}
