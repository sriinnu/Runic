#if os(Linux)
import Dispatch
import Foundation

enum LinuxSecretService {
    private static let defaultTimeoutSeconds: TimeInterval = 2.0

    static func lookupPassword(applications: [String]) -> String? {
        guard let tool = secretToolPath() else { return nil }
        let timeout = secretToolTimeout()
        for app in applications {
            if let value = runSecretTool(tool: tool, args: ["lookup", "application", app], timeout: timeout) {
                return value
            }
        }
        return nil
    }

    private static func secretToolPath() -> String? {
        if let override = envValue("SILO_SECRET_TOOL_PATH") {
            if override.contains("/") {
                return FileManager.default.isExecutableFile(atPath: override) ? override : nil
            }
            if let resolved = resolveToolFromPath(override) {
                return resolved
            }
            return nil
        }

        let candidates = [
            "/usr/bin/secret-tool",
            "/usr/local/bin/secret-tool",
            "/opt/homebrew/bin/secret-tool",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        return resolveToolFromPath("secret-tool")
    }

    private static func resolveToolFromPath(_ tool: String) -> String? {
        guard let pathValue = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for segment in pathValue.split(separator: ":") where !segment.isEmpty {
            let candidate = URL(fileURLWithPath: String(segment))
                .appendingPathComponent(tool)
                .path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func secretToolTimeout() -> TimeInterval {
        if let value = envValue("SILO_SECRET_TOOL_TIMEOUT_MS"), let ms = Double(value) {
            return max(0, ms) / 1000.0
        }
        return defaultTimeoutSeconds
    }

    private static func envValue(_ key: String) -> String? {
        guard let raw = ProcessInfo.processInfo.environment[key] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func runSecretTool(tool: String, args: [String], timeout: TimeInterval) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        process.environment = ProcessInfo.processInfo.environment

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        if timeout > 0 {
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
                _ = semaphore.wait(timeout: .now() + 0.2)
                return nil
            }
        } else {
            semaphore.wait()
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
#endif
