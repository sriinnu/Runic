import Darwin
import Foundation
import RunicCore

struct CodexLoginRunner {
    struct Result {
        enum Outcome {
            case success
            case timedOut
            case failed(status: Int32)
            case missingBinary
            case launchFailed(String)
        }

        let outcome: Outcome
        let output: String
    }

    static func run(timeout: TimeInterval = 120) async -> Result {
        await Task(priority: .userInitiated) {
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = PathBuilder.effectivePATH(
                purposes: [.rpc, .tty, .nodeTooling],
                env: env,
                loginPATH: LoginShellPathCache.shared.current)

            guard let executable = BinaryLocator.resolveCodexBinary(
                env: env,
                loginPATH: LoginShellPathCache.shared.current)
            else {
                return Result(outcome: .missingBinary, output: "")
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable, "login"]
            process.environment = env

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            // Drain both pipes as data arrives: a blocking read-to-end can
            // outlive the process when a helper it spawned keeps the pipe open.
            let stdoutCollector = PipeCollector(stdout)
            let stderrCollector = PipeCollector(stderr)

            var processGroup: pid_t?
            do {
                try process.run()
                processGroup = self.attachProcessGroup(process)
            } catch {
                return Result(outcome: .launchFailed(error.localizedDescription), output: "")
            }

            let timedOut = await self.wait(for: process, timeout: timeout)
            if timedOut {
                self.terminate(process, processGroup: processGroup)
            }

            let output = await self.combinedOutput(stdout: stdoutCollector, stderr: stderrCollector)
            if timedOut {
                return Result(outcome: .timedOut, output: output)
            }

            let status = process.terminationStatus
            if status == 0 {
                return Result(outcome: .success, output: output)
            }
            return Result(outcome: .failed(status: status), output: output)
        }.value
    }

    /// True when the deadline passed (or the caller cancelled) with the
    /// process still running. Polls instead of parking a task in
    /// `waitUntilExit()`: a task group can't return while a child is blocked
    /// there, so the timeout never fired and an abandoned browser login spun
    /// the menu forever.
    static func wait(for process: Process, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(max(0, timeout))
        while process.isRunning {
            if Date() >= deadline || Task.isCancelled { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return false
    }

    private static func terminate(_ process: Process, processGroup: pid_t?) {
        if let pgid = processGroup {
            kill(-pgid, SIGTERM)
        }
        if process.isRunning {
            process.terminate()
        }

        let deadline = Date().addingTimeInterval(2.0)
        while process.isRunning, Date() < deadline {
            usleep(100_000)
        }

        if process.isRunning {
            if let pgid = processGroup {
                kill(-pgid, SIGKILL)
            }
            kill(process.processIdentifier, SIGKILL)
        }
    }

    private static func attachProcessGroup(_ process: Process) -> pid_t? {
        let pid = process.processIdentifier
        return setpgid(pid, pid) == 0 ? pid : nil
    }

    private static func combinedOutput(stdout: PipeCollector, stderr: PipeCollector) async -> String {
        let stdoutText = await stdout.finish(timeout: 3.0)
        let stderrText = await stderr.finish(timeout: 3.0)

        let merged: String = if !stdoutText.isEmpty, !stderrText.isEmpty {
            [stdoutText, stderrText].joined(separator: "\n")
        } else {
            stdoutText + stderrText
        }
        let trimmed = merged.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = trimmed.prefix(4000)
        return limited.isEmpty ? "No output captured." : String(limited)
    }

    private static func decode(_ data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}

/// Accumulates a pipe's output on the file handle's own queue and hands back
/// whatever arrived once the writer closes it or the deadline passes, without
/// ever blocking a Swift task.
final class PipeCollector: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private var data = Data()
    private var reachedEOF = false

    init(_ pipe: Pipe) {
        self.handle = pipe.fileHandleForReading
        self.handle.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            self?.append(chunk)
        }
    }

    private func append(_ chunk: Data) {
        self.lock.withLock {
            if chunk.isEmpty {
                self.reachedEOF = true
            } else {
                self.data.append(chunk)
            }
        }
        if chunk.isEmpty { self.handle.readabilityHandler = nil }
    }

    private var snapshot: (Data, Bool) {
        self.lock.withLock { (self.data, self.reachedEOF) }
    }

    func finish(timeout: TimeInterval) async -> String {
        let deadline = Date().addingTimeInterval(max(0, timeout))
        while !self.snapshot.1, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        self.handle.readabilityHandler = nil
        return String(data: self.snapshot.0, encoding: .utf8) ?? ""
    }
}
