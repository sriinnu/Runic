import Foundation
import RunicCore

extension UsageStore {
    func detectVersions() {
        Task.detached { [claudeFetcher] in
            let codexVer = Self.readCLI("codex", args: ["-s", "read-only", "-a", "untrusted", "--version"])
            let claudeVer = claudeFetcher.detectVersion()
            let geminiVer = Self.readCLI("gemini", args: ["--version"])
            let antigravityVer = await AntigravityStatusProbe.detectVersion()
            await MainActor.run {
                self.codexVersion = codexVer
                self.claudeVersion = claudeVer
                self.geminiVersion = geminiVer
                self.zaiVersion = nil
                self.antigravityVersion = antigravityVer
            }
        }
    }

    private nonisolated static func readCLI(_ cmd: String, args: [String]) -> String? {
        let env = ProcessInfo.processInfo.environment
        var pathEnv = env
        pathEnv["PATH"] = PathBuilder.effectivePATH(purposes: [.rpc, .tty, .nodeTooling], env: env)
        let loginPATH = LoginShellPathCache.shared.current

        let resolved: String = switch cmd {
        case "codex":
            BinaryLocator.resolveCodexBinary(env: env, loginPATH: loginPATH) ?? cmd
        case "gemini":
            BinaryLocator.resolveGeminiBinary(env: env, loginPATH: loginPATH) ?? cmd
        default:
            cmd
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [resolved] + args
        process.environment = pathEnv
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty else { return nil }
        return text
    }
}
