import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AntigravityStatusProbe: Sendable {
    public var timeout: TimeInterval = 8.0

    private static let processName = "language_server"
    private static let getUserStatusPath = "/exa.language_server_pb.LanguageServerService/GetUserStatus"
    private static let commandModelConfigPath =
        "/exa.language_server_pb.LanguageServerService/GetCommandModelConfigs"
    private static let unleashPath = "/exa.language_server_pb.LanguageServerService/GetUnleashData"
    private static let log = RunicLog.logger("antigravity")

    public init(timeout: TimeInterval = 8.0) {
        self.timeout = timeout
    }

    public func fetch() async throws -> AntigravityStatusSnapshot {
        let deadline = Date().addingTimeInterval(self.timeout)
        let processes = try await Self.detectAllProcessInfos(timeout: self.timeout)
        var lastError: Error = AntigravityStatusProbeError.notRunning

        for processInfo in processes {
            guard Date() < deadline else { break }

            let ports: [Int]
            do {
                let lsofTimeout = min(self.timeout, 3.0)
                ports = try await Self.listeningPorts(pid: processInfo.pid, timeout: lsofTimeout)
            } catch {
                lastError = error
                continue
            }

            guard let connectPort = await Self.findFirstWorkingPort(
                ports: ports, csrfToken: processInfo.csrfToken)
            else {
                lastError = AntigravityStatusProbeError.portDetectionFailed(
                    "no working API port found for pid \(processInfo.pid)")
                continue
            }

            guard Date() < deadline else { break }

            let context = RequestContext(
                httpsPort: connectPort,
                httpPort: processInfo.extensionPort,
                csrfToken: processInfo.csrfToken,
                timeout: min(self.timeout, deadline.timeIntervalSinceNow))

            do {
                let response = try await Self.makeRequest(
                    payload: RequestPayload(
                        path: Self.getUserStatusPath,
                        body: Self.defaultRequestBody()),
                    context: context)
                return try Self.parseUserStatusResponse(response)
            } catch {
                // On 401/403 the CSRF token may have rotated — try the next
                // process instead of falling through to the command-config
                // fallback which uses the same stale token.
                if Self.isAuthError(error) { continue }
                // Try command-config fallback with the same context.
                do {
                    let response = try await Self.makeRequest(
                        payload: RequestPayload(
                            path: Self.commandModelConfigPath,
                            body: Self.defaultRequestBody()),
                        context: context)
                    return try Self.parseCommandModelResponse(response)
                } catch {
                    lastError = error
                    continue
                }
            }
        }

        throw lastError
    }

    private static func isAuthError(_ error: Error) -> Bool {
        if let apiErr = error as? AntigravityStatusProbeError,
           case let .apiError(message) = apiErr,
           message.contains("HTTP 401") || message.contains("HTTP 403") {
            return true
        }
        return false
    }

    public func fetchPlanInfoSummary() async throws -> AntigravityPlanInfoSummary? {
        let deadline = Date().addingTimeInterval(self.timeout)
        let processes = try await Self.detectAllProcessInfos(timeout: self.timeout)
        var lastError: Error = AntigravityStatusProbeError.notRunning

        for processInfo in processes {
            guard Date() < deadline else { break }

            let ports: [Int]
            do {
                ports = try await Self.listeningPorts(pid: processInfo.pid, timeout: min(self.timeout, 3.0))
            } catch { lastError = error; continue }

            guard let connectPort = await Self.findFirstWorkingPort(
                ports: ports, csrfToken: processInfo.csrfToken)
            else {
                lastError = AntigravityStatusProbeError.portDetectionFailed(
                    "no working API port found for pid \(processInfo.pid)")
                continue
            }

            guard Date() < deadline else { break }

            do {
                let response = try await Self.makeRequest(
                    payload: RequestPayload(
                        path: Self.getUserStatusPath,
                        body: Self.defaultRequestBody()),
                    context: RequestContext(
                        httpsPort: connectPort,
                        httpPort: processInfo.extensionPort,
                        csrfToken: processInfo.csrfToken,
                        timeout: min(self.timeout, deadline.timeIntervalSinceNow)))
                return try Self.parsePlanInfoSummary(response)
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError
    }

    public static func isRunning(timeout: TimeInterval = 4.0) async -> Bool {
        await (try? self.detectProcessInfo(timeout: timeout)) != nil
    }

    public static func detectVersion(timeout: TimeInterval = 4.0) async -> String? {
        let running = await Self.isRunning(timeout: timeout)
        return running ? "running" : nil
    }

    // MARK: - Port detection

    private struct ProcessInfoResult {
        let pid: Int
        let extensionPort: Int?
        let csrfToken: String
        let commandLine: String
    }

    /// Returns every matching Antigravity process so that if one instance has
    /// stale ports or an expired CSRF token, the probe can try the next.
    private static func detectAllProcessInfos(timeout: TimeInterval) async throws -> [ProcessInfoResult] {
        let env = ProcessInfo.processInfo.environment
        let result = try await SubprocessRunner.run(
            binary: "/bin/ps",
            arguments: ["-ax", "-o", "pid=,command="],
            environment: env,
            timeout: timeout,
            label: "antigravity-ps")

        var matches: [ProcessInfoResult] = []
        var sawAntigravity = false
        for line in result.stdout.split(separator: "\n") {
            let text = String(line)
            guard let match = Self.matchProcessLine(text) else { continue }
            let lower = match.command.lowercased()
            guard lower.contains(Self.processName) else { continue }
            guard Self.isAntigravityCommandLine(lower) else { continue }
            sawAntigravity = true
            guard let token = Self.extractFlag("--csrf_token", from: match.command) else { continue }
            let port = Self.extractPort("--extension_server_port", from: match.command)
                ?? Self.extractPort("--https_server_port", from: match.command)
            let effectivePort = port.flatMap { $0 > 0 ? $0 : nil }
            let info = ProcessInfoResult(pid: match.pid, extensionPort: effectivePort, csrfToken: token, commandLine: match.command)
            self.log.info("Antigravity process detected", metadata: [
                "pid": "\(info.pid)",
                "httpPort": info.extensionPort.map(String.init) ?? "none",
            ])
            matches.append(info)
        }

        if matches.isEmpty && sawAntigravity {
            throw AntigravityStatusProbeError.missingCSRFToken
        }
        if matches.isEmpty {
            throw AntigravityStatusProbeError.notRunning
        }
        return matches
    }

    /// Single-process lookup used by `isRunning` / `detectVersion`. Returns the
    /// first match only.
    private static func detectProcessInfo(timeout: TimeInterval) async throws -> ProcessInfoResult {
        let all = try await self.detectAllProcessInfos(timeout: timeout)
        guard let first = all.first else {
            throw AntigravityStatusProbeError.notRunning
        }
        return first
    }

    private struct ProcessLineMatch {
        let pid: Int
        let command: String
    }

    private static func matchProcessLine(_ line: String) -> ProcessLineMatch? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, let pid = Int(parts[0]) else { return nil }
        return ProcessLineMatch(pid: pid, command: String(parts[1]))
    }

    private static func isAntigravityCommandLine(_ command: String) -> Bool {
        if command.contains("--app_data_dir") && command.contains("antigravity") { return true }
        if command.contains("/antigravity/") || command.contains("\\antigravity\\") { return true }
        return false
    }

    private static func extractFlag(_ flag: String, from command: String) -> String? {
        let pattern = "\(NSRegularExpression.escapedPattern(for: flag))[=\\s]+([^\\s]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(command.startIndex..<command.endIndex, in: command)
        guard let match = regex.firstMatch(in: command, options: [], range: range),
              let tokenRange = Range(match.range(at: 1), in: command) else { return nil }
        return String(command[tokenRange])
    }

    private static func extractPort(_ flag: String, from command: String) -> Int? {
        guard let raw = extractFlag(flag, from: command) else { return nil }
        return Int(raw)
    }

    private static func listeningPorts(pid: Int, timeout: TimeInterval) async throws -> [Int] {
        let lsof = ["/usr/sbin/lsof", "/usr/bin/lsof"].first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        })

        guard let lsof else {
            throw AntigravityStatusProbeError.portDetectionFailed("lsof not available")
        }

        let env = ProcessInfo.processInfo.environment
        let result = try await SubprocessRunner.run(
            binary: lsof,
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-a", "-p", String(pid)],
            environment: env,
            timeout: timeout,
            label: "antigravity-lsof")

        let ports = Self.parseListeningPorts(result.stdout)
        if ports.isEmpty {
            // The process may have exited between ps and lsof.
            if !Self.isPIDAlive(pid) {
                throw AntigravityStatusProbeError.portDetectionFailed(
                    "Antigravity (pid \(pid)) exited; restart Antigravity and retry.")
            }
            throw AntigravityStatusProbeError.portDetectionFailed("no listening ports found")
        }
        return ports
    }

    private static func isPIDAlive(_ pid: Int) -> Bool {
        Darwin.kill(Int32(pid), 0) == 0
    }

    private static func parseListeningPorts(_ output: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: #":(\d+)\s+\(LISTEN\)"#) else { return [] }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        var ports: Set<Int> = []
        regex.enumerateMatches(in: output, options: [], range: range) { match, _, _ in
            guard let match,
                  let range = Range(match.range(at: 1), in: output),
                  let value = Int(output[range]) else { return }
            ports.insert(value)
        }
        return ports.sorted()
    }

    /// Maximum number of ports probed before giving up.
    private static let maxPortProbeCount = 5
    /// Per-port timeout (seconds) — much shorter than the overall fetch timeout
    /// so that a non-HTTPS port doesn't stall the probe for 8 seconds.
    private static let portProbeTimeout: TimeInterval = 2.0

    private static func findFirstWorkingPort(
        ports: [Int],
        csrfToken: String) async -> Int?
    {
        let budget = min(ports.count, Self.maxPortProbeCount)
        Self.log.info("Probing Antigravity ports", metadata: ["ports": "\(ports.prefix(budget))"])
        for port in ports.prefix(budget) {
            let ok = await Self.testPortConnectivity(port: port, csrfToken: csrfToken)
            if ok {
                Self.log.info("Antigravity port connected", metadata: ["port": "\(port)"])
                return port
            }
        }
        return nil
    }

    private static func testPortConnectivity(
        port: Int,
        csrfToken: String) async -> Bool
    {
        do {
            _ = try await self.makeRequest(
                payload: RequestPayload(
                    path: self.unleashPath,
                    body: self.unleashRequestBody()),
                context: RequestContext(
                    httpsPort: port,
                    httpPort: nil,
                    csrfToken: csrfToken,
                    timeout: Self.portProbeTimeout))
            return true
        } catch {
            self.log.debug("Antigravity port probe failed", metadata: [
                "port": "\(port)",
                "error": "\(error)",
            ])
            return false
        }
    }

    // MARK: - HTTP

    private struct RequestPayload {
        let path: String
        let body: [String: Any]
    }

    private struct RequestContext {
        let httpsPort: Int
        let httpPort: Int?
        let csrfToken: String
        let timeout: TimeInterval
    }

    private static func defaultRequestBody() -> [String: Any] {
        [
            "metadata": [
                "ideName": "antigravity",
                "extensionName": "antigravity",
                "ideVersion": "unknown",
                "locale": "en",
            ],
        ]
    }

    private static func unleashRequestBody() -> [String: Any] {
        [
            "context": [
                "properties": [
                    "devMode": "false",
                    "extensionVersion": "unknown",
                    "hasAnthropicModelAccess": "true",
                    "ide": "antigravity",
                    "ideVersion": "unknown",
                    "installationId": "runic",
                    "language": "UNSPECIFIED",
                    "os": "macos",
                    "requestedModelId": "MODEL_UNSPECIFIED",
                ],
            ],
        ]
    }

    private static func makeRequest(
        payload: RequestPayload,
        context: RequestContext) async throws -> Data
    {
        do {
            return try await self.sendRequest(
                scheme: "https",
                port: context.httpsPort,
                payload: payload,
                context: context)
        } catch {
            guard let httpPort = context.httpPort, httpPort != context.httpsPort else { throw error }
            return try await Self.sendRequest(
                scheme: "http",
                port: httpPort,
                payload: payload,
                context: context)
        }
    }

    private static func sendRequest(
        scheme: String,
        port: Int,
        payload: RequestPayload,
        context: RequestContext) async throws -> Data
    {
        guard let url = URL(string: "\(scheme)://127.0.0.1:\(port)\(payload.path)") else {
            throw AntigravityStatusProbeError.apiError("Invalid URL")
        }

        let body = try JSONSerialization.data(withJSONObject: payload.body, options: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = context.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(context.csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = context.timeout
        config.timeoutIntervalForResource = context.timeout
        let session = URLSession(configuration: config, delegate: InsecureSessionDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AntigravityStatusProbeError.apiError("Invalid response")
        }
        guard http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw AntigravityStatusProbeError.apiError("HTTP \(http.statusCode): \(message)")
        }
        return data
    }
}

private final class InsecureSessionDelegate: NSObject {}

extension InsecureSessionDelegate: URLSessionDelegate, URLSessionTaskDelegate {}

extension InsecureSessionDelegate {
    // macOS 26+ delivers SSL challenges at the session level.
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        let result = Self.resolveChallenge(challenge)
        completionHandler(result.disposition, result.credential)
    }

    // Older macOS / task-level fallback.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @MainActor @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        let result = Self.resolveChallenge(challenge)
        Task { @MainActor in
            completionHandler(result.disposition, result.credential)
        }
    }

    private static func resolveChallenge(_ challenge: URLAuthenticationChallenge) -> (
        disposition: URLSession.AuthChallengeDisposition,
        credential: URLCredential?)
    {
        #if canImport(FoundationNetworking)
        return (.performDefaultHandling, nil)
        #else
        // Only trust self-signed certs on localhost — never on any other host.
        let host = challenge.protectionSpace.host
        guard host == "127.0.0.1" || host == "localhost" else {
            return (.performDefaultHandling, nil)
        }
        if let trust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: trust))
        }
        return (.performDefaultHandling, nil)
        #endif
    }
}
