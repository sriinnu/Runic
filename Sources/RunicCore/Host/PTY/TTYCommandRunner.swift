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
        if let hit = Self.which(binary) {
            return hit
        }
        throw Error.binaryNotFound(binary)
    }

    private final class PTYRunContext {
        let primaryFD: Int32
        let secondaryFD: Int32
        let primaryHandle: FileHandle
        let secondaryHandle: FileHandle
        let proc: Process
        var buffer = Data()

        private var cleanedUp = false
        private var didLaunch = false
        private var processGroup: pid_t?

        init(resolved: String, options: Options) throws {
            var primaryFD: Int32 = -1
            var secondaryFD: Int32 = -1
            var win = winsize(ws_row: options.rows, ws_col: options.cols, ws_xpixel: 0, ws_ypixel: 0)
            guard openpty(&primaryFD, &secondaryFD, nil, nil, &win) == 0 else {
                throw Error.launchFailed("openpty failed")
            }
            _ = fcntl(primaryFD, F_SETFL, O_NONBLOCK)

            self.primaryFD = primaryFD
            self.secondaryFD = secondaryFD
            self.primaryHandle = FileHandle(fileDescriptor: primaryFD, closeOnDealloc: true)
            self.secondaryHandle = FileHandle(fileDescriptor: secondaryFD, closeOnDealloc: true)
            self.proc = Process()

            self.configureProcess(resolved: resolved, options: options)
        }

        func launch() throws {
            try self.proc.run()
            self.didLaunch = true

            let pid = self.proc.processIdentifier
            if setpgid(pid, pid) == 0 {
                self.processGroup = pid
            }
        }

        func cleanup() {
            guard !self.cleanedUp else { return }
            self.cleanedUp = true

            if self.didLaunch, self.proc.isRunning {
                try? self.writeAllToPrimary(Data("/exit\n".utf8))
            }

            try? self.primaryHandle.close()
            try? self.secondaryHandle.close()
            guard self.didLaunch else { return }

            if self.proc.isRunning {
                self.proc.terminate()
            }
            if let pgid = self.processGroup {
                kill(-pgid, SIGTERM)
            }

            let waitDeadline = Date().addingTimeInterval(2.0)
            while self.proc.isRunning, Date() < waitDeadline {
                usleep(100_000)
            }
            if self.proc.isRunning {
                if let pgid = self.processGroup {
                    kill(-pgid, SIGKILL)
                }
                kill(self.proc.processIdentifier, SIGKILL)
            }
            self.proc.waitUntilExit()
        }

        func send(_ text: String) throws {
            guard let data = text.data(using: .utf8) else { return }
            try self.writeAllToPrimary(data)
        }

        func readChunk() -> Data {
            var appended = Data()
            while true {
                var tmp = [UInt8](repeating: 0, count: 8192)
                let n = read(self.primaryFD, &tmp, tmp.count)
                if n > 0 {
                    let slice = tmp.prefix(n)
                    self.buffer.append(contentsOf: slice)
                    appended.append(contentsOf: slice)
                    continue
                }
                break
            }
            return appended
        }

        func writeAllToPrimary(_ data: Data) throws {
            try data.withUnsafeBytes { rawBytes in
                guard let baseAddress = rawBytes.baseAddress else { return }
                var offset = 0
                var retries = 0
                while offset < rawBytes.count {
                    let written = write(self.primaryFD, baseAddress.advanced(by: offset), rawBytes.count - offset)
                    if written > 0 {
                        offset += written
                        retries = 0
                        continue
                    }
                    if written == 0 { break }

                    let err = errno
                    if err == EAGAIN || err == EWOULDBLOCK {
                        retries += 1
                        if retries > 200 {
                            throw Error.launchFailed("write to PTY would block")
                        }
                        usleep(5000)
                        continue
                    }
                    throw Error.launchFailed("write to PTY failed: \(String(cString: strerror(err)))")
                }
            }
        }

        private func configureProcess(resolved: String, options: Options) {
            let resolvedURL = URL(fileURLWithPath: resolved)
            if resolvedURL.lastPathComponent == "claude",
               let watchdog = TTYCommandRunner.locateBundledHelper("RunicClaudeWatchdog")
            {
                self.proc.executableURL = URL(fileURLWithPath: watchdog)
                self.proc.arguments = ["--", resolved] + options.extraArgs
            } else {
                self.proc.executableURL = resolvedURL
                self.proc.arguments = options.extraArgs
            }
            self.proc.standardInput = self.secondaryHandle
            self.proc.standardOutput = self.secondaryHandle
            self.proc.standardError = self.secondaryHandle

            var env = TTYCommandRunner.enrichedEnvironment()
            if let workingDirectory = options.workingDirectory {
                self.proc.currentDirectoryURL = workingDirectory
                env["PWD"] = workingDirectory.path
            }
            self.proc.environment = env
        }
    }

    private struct GenericCaptureRequest {
        let context: PTYRunContext
        let trimmedScript: String
        let options: Options
        let deadline: Date
    }

    private struct GenericSendNeedle {
        let needle: Data
        let needleString: String
        let keys: Data
    }

    private struct GenericCaptureState {
        var scanBuffer: RollingBuffer
        var nextCursorCheckAt = Date(timeIntervalSince1970: 0)
        var lastEnter = Date()
        var stoppedEarly = false
        var urlSeen = false
        var triggeredSends = Set<Data>()
        var recentText = ""
        var lastOutputAt = Date()

        init(maxNeedle: Int) {
            self.scanBuffer = RollingBuffer(maxNeedle: maxNeedle)
        }
    }

    private static let cursorQuery = Data([0x1B, 0x5B, 0x36, 0x6E])

    private static func captureGeneric(
        _ request: GenericCaptureRequest,
        onURLDetected: (@Sendable () -> Void)?) throws -> Result
    {
        let context = request.context
        if !request.trimmedScript.isEmpty {
            try context.send(request.trimmedScript)
            try context.send("\r")
        }

        let stopNeedles = request.options.stopOnSubstrings.map { Data($0.utf8) }
        let sendNeedles = request.options.sendOnSubstrings.map {
            GenericSendNeedle(needle: Data($0.key.utf8), needleString: $0.key, keys: Data($0.value.utf8))
        }
        let urlNeedles = [Data("https://".utf8), Data("http://".utf8)]
        var state = GenericCaptureState(maxNeedle: Self.genericMaxNeedle(
            stopNeedles: stopNeedles,
            sendNeedles: sendNeedles,
            urlNeedles: urlNeedles))

        while Date() < request.deadline {
            let newData = context.readChunk()
            Self.updateRecentText(newData, state: &state)
            let scanData = state.scanBuffer.append(newData)
            Self.respondToCursorQuery(context: context, scanData: scanData, nextCheckAt: &state.nextCursorCheckAt)
            Self.triggerConfiguredSends(context: context, sendNeedles: sendNeedles, scanData: scanData, state: &state)

            if Self.updateURLState(
                scanData: scanData,
                urlNeedles: urlNeedles,
                stopOnURL: request.options.stopOnURL,
                state: &state,
                onURLDetected: onURLDetected)
            {
                break
            }
            if Self.shouldStopGeneric(
                scanData: scanData,
                stopNeedles: stopNeedles,
                idleTimeout: request.options.idleTimeout,
                context: context,
                state: &state)
            {
                break
            }
            Self.sendEnterIfNeeded(context: context, options: request.options, state: &state)
            if !context.proc.isRunning { break }
            usleep(60000)
        }

        _ = context.readChunk()
        if state.stoppedEarly {
            Self.settleGenericCapture(context: context, state: &state, request: request)
        }

        let text = String(data: context.buffer, encoding: .utf8) ?? ""
        guard !text.isEmpty else { throw Error.timedOut }
        return Result(text: text)
    }

    private static func genericMaxNeedle(
        stopNeedles: [Data],
        sendNeedles: [GenericSendNeedle],
        urlNeedles: [Data]) -> Int
    {
        let needleLengths =
            stopNeedles.map(\.count) +
            sendNeedles.map(\.needle.count) +
            urlNeedles.map(\.count) +
            [Self.cursorQuery.count]
        return needleLengths.max() ?? Self.cursorQuery.count
    }

    private static func updateRecentText(_ newData: Data, state: inout GenericCaptureState) {
        guard !newData.isEmpty else { return }
        state.lastOutputAt = Date()
        if let chunkText = String(bytes: newData, encoding: .utf8) {
            state.recentText += chunkText
            if state.recentText.count > 8192 {
                state.recentText.removeFirst(state.recentText.count - 8192)
            }
        }
    }

    private static func respondToCursorQuery(
        context: PTYRunContext,
        scanData: Data,
        nextCheckAt: inout Date,
        interval: TimeInterval = 1.0)
    {
        guard Date() >= nextCheckAt,
              !scanData.isEmpty,
              scanData.range(of: Self.cursorQuery) != nil else { return }
        try? context.send("\u{1b}[1;1R")
        nextCheckAt = Date().addingTimeInterval(interval)
    }

    private static func triggerConfiguredSends(
        context: PTYRunContext,
        sendNeedles: [GenericSendNeedle],
        scanData: Data,
        state: inout GenericCaptureState)
    {
        guard !sendNeedles.isEmpty else { return }
        let recentTextCollapsed = state.recentText.replacingOccurrences(of: "\r", with: "")
        for item in sendNeedles where !state.triggeredSends.contains(item.needle) {
            let matched = scanData.range(of: item.needle) != nil ||
                state.recentText.contains(item.needleString) ||
                recentTextCollapsed.contains(item.needleString)
            guard matched else { continue }
            if let keysString = String(data: item.keys, encoding: .utf8) {
                try? context.send(keysString)
            } else {
                try? context.writeAllToPrimary(item.keys)
            }
            state.triggeredSends.insert(item.needle)
        }
    }

    private static func updateURLState(
        scanData: Data,
        urlNeedles: [Data],
        stopOnURL: Bool,
        state: inout GenericCaptureState,
        onURLDetected: (@Sendable () -> Void)?) -> Bool
    {
        guard urlNeedles.contains(where: { scanData.range(of: $0) != nil }) else { return false }
        state.urlSeen = true
        onURLDetected?()
        guard stopOnURL else { return false }
        state.stoppedEarly = true
        return true
    }

    private static func shouldStopGeneric(
        scanData: Data,
        stopNeedles: [Data],
        idleTimeout: TimeInterval?,
        context: PTYRunContext,
        state: inout GenericCaptureState) -> Bool
    {
        if !stopNeedles.isEmpty, stopNeedles.contains(where: { scanData.range(of: $0) != nil }) {
            state.stoppedEarly = true
            return true
        }
        if let idleTimeout,
           !context.buffer.isEmpty,
           Date().timeIntervalSince(state.lastOutputAt) >= idleTimeout
        {
            state.stoppedEarly = true
            return true
        }
        return false
    }

    private static func sendEnterIfNeeded(context: PTYRunContext, options: Options, state: inout GenericCaptureState) {
        guard !state.urlSeen,
              let every = options.sendEnterEvery,
              Date().timeIntervalSince(state.lastEnter) >= every else { return }
        try? context.send("\r")
        state.lastEnter = Date()
    }

    private static func settleGenericCapture(
        context: PTYRunContext,
        state: inout GenericCaptureState,
        request: GenericCaptureRequest)
    {
        let settle = max(0, min(request.options.settleAfterStop, request.deadline.timeIntervalSinceNow))
        guard settle > 0 else { return }
        let settleDeadline = Date().addingTimeInterval(settle)
        while Date() < settleDeadline {
            let scanData = state.scanBuffer.append(context.readChunk())
            Self.respondToCursorQuery(context: context, scanData: scanData, nextCheckAt: &state.nextCursorCheckAt)
            usleep(50000)
        }
    }

    private struct CodexCaptureRequest {
        let context: PTYRunContext
        let script: String
        let deadline: Date
        let delayInitialSend: Bool
    }

    private struct CodexCaptureState {
        var skippedUpdate = false
        var sentScript: Bool
        var updateSkipAttempts = 0
        var lastEnter = Date(timeIntervalSince1970: 0)
        var scriptSentAt: Date?
        var resendStatusRetries = 0
        var enterRetries = 0
        var sawStatus = false
        var sawUpdatePrompt = false
        var statusScanBuffer: RollingBuffer
        var updateScanBuffer: RollingBuffer
        var nextCursorCheckAt = Date(timeIntervalSince1970: 0)

        init(sentScript: Bool, statusMaxNeedle: Int, updateMaxNeedle: Int) {
            self.sentScript = sentScript
            self.scriptSentAt = sentScript ? Date() : nil
            self.statusScanBuffer = RollingBuffer(maxNeedle: statusMaxNeedle)
            self.updateScanBuffer = RollingBuffer(maxNeedle: updateMaxNeedle)
        }
    }

    private static func captureCodex(_ request: CodexCaptureRequest) throws -> Result {
        let context = request.context
        if !request.delayInitialSend {
            try Self.sendInitialCodexScript(context: context, script: request.script)
        }

        let statusMarkers = Self.codexStatusMarkers()
        let updateNeedlesLower = Self.codexUpdateNeedles()
        var state = CodexCaptureState(
            sentScript: !request.delayInitialSend,
            statusMaxNeedle: Self.statusMaxNeedle(statusMarkers),
            updateMaxNeedle: Self.updateMaxNeedle(updateNeedlesLower))

        while Date() < request.deadline {
            let newData = context.readChunk()
            let scanData = state.statusScanBuffer.append(newData)
            Self.respondToCursorQuery(context: context, scanData: scanData, nextCheckAt: &state.nextCursorCheckAt)
            Self.detectCodexStatus(scanData: scanData, statusMarkers: statusMarkers, state: &state)
            Self.detectCodexUpdatePrompt(newData: newData, needles: updateNeedlesLower, state: &state)
            Self.skipCodexUpdatePromptIfNeeded(context: context, state: &state)

            if Self.sendCodexScriptIfNeeded(context: context, request: request, state: &state) { continue }
            if Self.nudgeCodexStatusIfNeeded(context: context, request: request, state: &state) { continue }
            if state.sawStatus { break }
            usleep(120_000)
        }

        if state.sawStatus {
            Self.settleCodexStatus(context: context, state: &state)
        }

        guard let text = String(data: context.buffer, encoding: .utf8), !text.isEmpty else {
            throw Error.timedOut
        }
        return Result(text: text)
    }

    private static func sendInitialCodexScript(context: PTYRunContext, script: String) throws {
        try context.send(script)
        try context.send("\r")
        usleep(150_000)
        try context.send("\r")
        try context.send("\u{1b}")
    }

    private static func codexStatusMarkers() -> [Data] {
        [
            "Credits:",
            "5h limit",
            "5-hour limit",
            "Weekly limit",
        ].map { Data($0.utf8) }
    }

    private static func codexUpdateNeedles() -> [Data] {
        ["Update available!", "Run bun install -g @openai/codex", "0.60.1 ->"]
            .map { Data($0.lowercased().utf8) }
    }

    private static func statusMaxNeedle(_ markers: [Data]) -> Int {
        ([Self.cursorQuery.count] + markers.map(\.count)).max() ?? Self.cursorQuery.count
    }

    private static func updateMaxNeedle(_ needles: [Data]) -> Int {
        needles.map(\.count).max() ?? 0
    }

    private static func detectCodexStatus(
        scanData: Data,
        statusMarkers: [Data],
        state: inout CodexCaptureState)
    {
        guard !scanData.isEmpty, !state.sawStatus else { return }
        if statusMarkers.contains(where: { scanData.range(of: $0) != nil }) {
            state.sawStatus = true
        }
    }

    private static func detectCodexUpdatePrompt(
        newData: Data,
        needles: [Data],
        state: inout CodexCaptureState)
    {
        guard !state.skippedUpdate, !state.sawUpdatePrompt, !newData.isEmpty else { return }
        let lowerScan = state.updateScanBuffer.append(Self.lowercasedASCII(newData))
        if needles.contains(where: { lowerScan.range(of: $0) != nil }) {
            state.sawUpdatePrompt = true
        }
    }

    private static func skipCodexUpdatePromptIfNeeded(context: PTYRunContext, state: inout CodexCaptureState) {
        guard !state.skippedUpdate, state.sawUpdatePrompt else { return }
        try? context.send("\u{1b}[B")
        usleep(120_000)
        try? context.send("\r")
        usleep(150_000)
        try? context.send("\r")
        try? context.send("/status")
        try? context.send("\r")
        state.updateSkipAttempts += 1

        guard state.updateSkipAttempts >= 1 else { return }
        state.skippedUpdate = true
        state.sentScript = false
        state.scriptSentAt = nil
        context.buffer.removeAll()
        state.statusScanBuffer.reset()
        state.updateScanBuffer.reset()
        state.sawStatus = false
        usleep(300_000)
    }

    private static func sendCodexScriptIfNeeded(
        context: PTYRunContext,
        request: CodexCaptureRequest,
        state: inout CodexCaptureState) -> Bool
    {
        guard !state.sentScript, !state.sawUpdatePrompt || state.skippedUpdate else { return false }
        try? context.send(request.script)
        try? context.send("\r")
        state.sentScript = true
        state.scriptSentAt = Date()
        state.lastEnter = Date()
        usleep(200_000)
        return true
    }

    private static func nudgeCodexStatusIfNeeded(
        context: PTYRunContext,
        request: CodexCaptureRequest,
        state: inout CodexCaptureState) -> Bool
    {
        guard state.sentScript, !state.sawStatus else { return false }
        if Date().timeIntervalSince(state.lastEnter) >= 1.2, state.enterRetries < 6 {
            try? context.send("\r")
            state.enterRetries += 1
            state.lastEnter = Date()
            usleep(120_000)
            return true
        }
        if Self.resendCodexStatusIfNeeded(context: context, state: &state) {
            return true
        }
        return false
    }

    private static func resendCodexStatusIfNeeded(
        context: PTYRunContext,
        state: inout CodexCaptureState) -> Bool
    {
        guard let sentAt = state.scriptSentAt,
              Date().timeIntervalSince(sentAt) >= 3.0,
              state.resendStatusRetries < 2 else { return false }
        try? context.send("/status")
        try? context.send("\r")
        state.resendStatusRetries += 1
        context.buffer.removeAll()
        state.statusScanBuffer.reset()
        state.updateScanBuffer.reset()
        state.sawStatus = false
        state.scriptSentAt = Date()
        state.lastEnter = Date()
        usleep(220_000)
        return true
    }

    private static func settleCodexStatus(context: PTYRunContext, state: inout CodexCaptureState) {
        let settleDeadline = Date().addingTimeInterval(2.0)
        while Date() < settleDeadline {
            let scanData = state.statusScanBuffer.append(context.readChunk())
            Self.respondToCursorQuery(context: context, scanData: scanData, nextCheckAt: &state.nextCursorCheckAt)
            usleep(100_000)
        }
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
