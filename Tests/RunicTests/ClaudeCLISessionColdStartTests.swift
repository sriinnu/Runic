import Foundation
import Testing
@testable import RunicCore

/// A stand-in for the Claude TUI on a slow start. It throws away whatever was
/// typed before it's ready, as Claude Code 2.1 does, and shows the usage panel
/// only for a command that arrives afterwards.
@Suite(.serialized)
struct ClaudeCLISessionColdStartTests {
    private static let panel = "Current week (all models) 13% used"

    private func fakeTUI(_ startup: String, beforePanel: String = "pass") throws -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-fake-tui-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("fake-tui").path
        let script = """
        #!/usr/bin/env python3
        import os, sys, termios, time, tty
        tty.setraw(0)
        def say(text):
            os.write(1, text.encode())
        def ready():
            termios.tcflush(0, termios.TCIFLUSH)
        \(startup)
        typed = b""
        while True:
            typed += os.read(0, 256)
            if b"\\r" in typed:
                typed = b""
                \(beforePanel)
                say("\(Self.panel)\\r\\n")
        """
        try script.write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    private func capture(_ binary: String, stop: [String] = ["Current week"]) async throws -> String {
        await ClaudeCLISession.shared.reset()
        do {
            let text = try await ClaudeCLISession.shared.capture(
                subcommand: "/usage",
                binary: binary,
                timeout: 12,
                idleTimeout: 1,
                stopOnSubstrings: stop,
                settleAfterStop: 0.1,
                resendsWithoutStopText: 2)
            await ClaudeCLISession.shared.reset()
            return text
        } catch {
            await ClaudeCLISession.shared.reset()
            throw error
        }
    }

    @Test
    func `waits out A silent pause between banner and prompt`() async throws {
        let binary = try self.fakeTUI("""
        say("Claude Code\\r\\n")
        time.sleep(4)
        ready()
        say("❯ ")
        """)
        #expect(try await self.capture(binary, stop: []).contains(Self.panel))
    }

    @Test
    func `types the command again when the prompt swallowed it`() async throws {
        let binary = try self.fakeTUI("""
        say("❯ ")
        time.sleep(0.5)
        ready()
        """)
        #expect(try await self.capture(binary).contains(Self.panel))
    }

    @Test
    func `a panel with new wording still returns what it printed`() async throws {
        let binary = try self.fakeTUI("""
        say("❯ ")
        """)
        let text = try await self.capture(binary, stop: ["Words Claude no longer prints"])
        #expect(text.contains(Self.panel))
    }

    @Test
    func `a character split across reads does not lose the whole capture`() async throws {
        // The start of a ❯ with its tail cut off, as a read boundary leaves it.
        let binary = try self.fakeTUI(
            """
            say("❯ ")
            """,
            beforePanel: #"os.write(1, b"\xe2\x9d")"#)
        #expect(try await self.capture(binary).contains(Self.panel))
    }

    @Test
    func `the usage panel without A session row still counts as the answer`() throws {
        let snapshot = try ClaudeStatusProbe.parse(text: """
        Current week (all models)
        13% used
        Resets Nov 7 at 2:59am
        """)
        #expect(snapshot.sessionPercentLeft == nil)
        #expect(snapshot.weeklyPercentLeft == 87)
    }
}
