#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

/// Executes an interactive CLI inside a pseudo-terminal and returns all captured text.
/// Keeps it minimal so we can reuse for Codex and Claude without tmux.
public struct TTYCommandRunner {
    public struct Result: Sendable {
        public let text: String
    }

    public struct Options: Sendable {
        public var rows: UInt16 = 50
        public var cols: UInt16 = 160
        public var timeout: TimeInterval = 20.0
        /// Stop early once output has been idle for this long (only for non-Codex flows).
        /// Useful for interactive TUIs that render once and then wait for input indefinitely.
        public var idleTimeout: TimeInterval?
        public var workingDirectory: URL?
        public var extraArgs: [String] = []
        public var initialDelay: TimeInterval = 0.4
        public var sendEnterEvery: TimeInterval?
        public var sendOnSubstrings: [String: String]
        public var stopOnURL: Bool
        public var stopOnSubstrings: [String]
        public var settleAfterStop: TimeInterval

        public init(
            rows: UInt16 = 50,
            cols: UInt16 = 160,
            timeout: TimeInterval = 20.0,
            idleTimeout: TimeInterval? = nil,
            workingDirectory: URL? = nil,
            extraArgs: [String] = [],
            initialDelay: TimeInterval = 0.4,
            sendEnterEvery: TimeInterval? = nil,
            sendOnSubstrings: [String: String] = [:],
            stopOnURL: Bool = false,
            stopOnSubstrings: [String] = [],
            settleAfterStop: TimeInterval = 0.25)
        {
            self.rows = rows
            self.cols = cols
            self.timeout = timeout
            self.idleTimeout = idleTimeout
            self.workingDirectory = workingDirectory
            self.extraArgs = extraArgs
            self.initialDelay = initialDelay
            self.sendEnterEvery = sendEnterEvery
            self.sendOnSubstrings = sendOnSubstrings
            self.stopOnURL = stopOnURL
            self.stopOnSubstrings = stopOnSubstrings
            self.settleAfterStop = settleAfterStop
        }
    }

    public enum Error: Swift.Error, LocalizedError, Sendable {
        case binaryNotFound(String)
        case launchFailed(String)
        case timedOut

        public var errorDescription: String? {
            switch self {
            case let .binaryNotFound(bin):
                "Missing CLI '\(bin)'. Install it (e.g. npm i -g @openai/codex) or add it to PATH."
            case let .launchFailed(msg): "Failed to launch process: \(msg)"
            case .timedOut: "PTY command timed out."
            }
        }
    }

    public init() {}

    struct RollingBuffer {
        private let maxNeedle: Int
        private var tail = Data()

        init(maxNeedle: Int) {
            self.maxNeedle = max(0, maxNeedle)
        }

        mutating func append(_ data: Data) -> Data {
            guard !data.isEmpty else { return Data() }

            var combined = Data()
            combined.reserveCapacity(self.tail.count + data.count)
            combined.append(self.tail)
            combined.append(data)

            if self.maxNeedle > 1 {
                if combined.count >= self.maxNeedle - 1 {
                    self.tail = combined.suffix(self.maxNeedle - 1)
                } else {
                    self.tail = combined
                }
            } else {
                self.tail.removeAll(keepingCapacity: true)
            }

            return combined
        }

        mutating func reset() {
            self.tail.removeAll(keepingCapacity: true)
        }
    }

    static func lowercasedASCII(_ data: Data) -> Data {
        guard !data.isEmpty else { return data }
        var out = Data(count: data.count)
        out.withUnsafeMutableBytes { dest in
            data.withUnsafeBytes { source in
                let src = source.bindMemory(to: UInt8.self)
                let dst = dest.bindMemory(to: UInt8.self)
                for idx in 0..<src.count {
                    var byte = src[idx]
                    if byte >= 65, byte <= 90 { byte += 32 }
                    dst[idx] = byte
                }
            }
        }
        return out
    }

    static func locateBundledHelper(_ name: String) -> String? {
        let fm = FileManager.default

        func isExecutable(_ path: String) -> Bool {
            fm.isExecutableFile(atPath: path)
        }

        if let override = ProcessInfo.processInfo.environment["RUNIC_HELPER_\(name.uppercased())"],
           isExecutable(override)
        {
            return override
        }

        func candidate(inAppBundleURL appURL: URL) -> String? {
            let path = appURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Helpers", isDirectory: true)
                .appendingPathComponent(name, isDirectory: false)
                .path
            return isExecutable(path) ? path : nil
        }

        let mainURL = Bundle.main.bundleURL
        if mainURL.pathExtension == "app", let found = candidate(inAppBundleURL: mainURL) { return found }

        if let argv0 = CommandLine.arguments.first {
            var url = URL(fileURLWithPath: argv0)
            if !argv0.hasPrefix("/") {
                url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(argv0)
            }
            var probe = url
            for _ in 0..<6 {
                let parent = probe.deletingLastPathComponent()
                if parent.pathExtension == "app", let found = candidate(inAppBundleURL: parent) { return found }
                if parent.path == probe.path { break }
                probe = parent
            }
        }

        return nil
    }

    public func run(
        binary: String,
        send script: String,
        options: Options = Options(),
        onURLDetected: (@Sendable () -> Void)? = nil) throws -> Result
    {
        let resolved = try Self.resolveExecutable(binary)
        let context = try PTYRunContext(resolved: resolved, options: options)
        defer { context.cleanup() }

        try context.launch()

        let deadline = Date().addingTimeInterval(options.timeout)
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        usleep(UInt32(options.initialDelay * 1_000_000))

        if binary != "codex" {
            return try Self.captureGeneric(
                GenericCaptureRequest(
                    context: context,
                    trimmedScript: trimmed,
                    options: options,
                    deadline: deadline),
                onURLDetected: onURLDetected)
        }

        return try Self.captureCodex(CodexCaptureRequest(
            context: context,
            script: script,
            deadline: deadline,
            delayInitialSend: trimmed == "/status"))
    }

    private static func resolveExecutable(_ binary: String) throws -> String {
        if FileManager.default.isExecutableFile(atPath: binary) {
            return binary
        }
        if let hit = which(binary) {
            return hit
        }
        throw Error.binaryNotFound(binary)
    }

    public static func which(_ tool: String) -> String? {
        if tool == "codex", let located = BinaryLocator.resolveCodexBinary() { return located }
        if tool == "claude", let located = BinaryLocator.resolveClaudeBinary() { return located }
        return self.runWhich(tool)
    }

    private static func runWhich(_ tool: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [tool]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = PathBuilder.effectivePATH(purposes: [.tty, .nodeTooling], env: env)
        proc.environment = env
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !path.isEmpty else { return nil }
        return path
    }

    /// Uses login-shell PATH when available so TTY probes match the user's shell configuration.
    public static func enrichedPath() -> String {
        PathBuilder.effectivePATH(
            purposes: [.tty, .nodeTooling],
            env: ProcessInfo.processInfo.environment)
    }

    static func enrichedEnvironment(
        baseEnv: [String: String] = ProcessInfo.processInfo.environment,
        loginPATH: [String]? = LoginShellPathCache.shared.current,
        home: String = NSHomeDirectory()) -> [String: String]
    {
        var env = baseEnv
        env["PATH"] = PathBuilder.effectivePATH(
            purposes: [.tty, .nodeTooling],
            env: baseEnv,
            loginPATH: loginPATH,
            home: home)
        if env["HOME"]?.isEmpty ?? true {
            env["HOME"] = home
        }
        if env["TERM"]?.isEmpty ?? true {
            env["TERM"] = "xterm-256color"
        }
        if env["COLORTERM"]?.isEmpty ?? true {
            env["COLORTERM"] = "truecolor"
        }
        if env["LANG"]?.isEmpty ?? true {
            env["LANG"] = "en_US.UTF-8"
        }
        if env["CI"] == nil {
            env["CI"] = "0"
        }
        return env
    }
}
