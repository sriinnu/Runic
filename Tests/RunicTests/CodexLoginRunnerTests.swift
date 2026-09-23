import Foundation
import Testing
@testable import Runic

/// The Codex login runner must give up on an abandoned login instead of
/// spinning forever.
struct CodexLoginRunnerTests {
    @Test
    func `wait gives up on a process that never exits`() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        defer { process.terminate() }

        let started = Date()
        let timedOut = await CodexLoginRunner.wait(for: process, timeout: 0.5)
        #expect(timedOut)
        #expect(Date().timeIntervalSince(started) < 3)
    }

    @Test
    func `wait returns when the process exits`() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        #expect(await CodexLoginRunner.wait(for: process, timeout: 10) == false)
    }

    @Test
    func `output collection survives a helper that keeps the pipe open`() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // The shell exits at once; the background sleep inherits stdout and
        // holds it open, which is what hung a blocking read-to-end.
        process.arguments = ["-c", "echo signed-in; /bin/sleep 30 &"]
        let pipe = Pipe()
        process.standardOutput = pipe
        let collector = PipeCollector(pipe)
        try process.run()
        process.waitUntilExit()

        let started = Date()
        let text = await collector.finish(timeout: 0.5)
        #expect(text.contains("signed-in"))
        #expect(Date().timeIntervalSince(started) < 3)
    }
}
