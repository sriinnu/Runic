import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

struct RPCAccountResponse: Decodable {
    let account: RPCAccountDetails?
    let requiresOpenaiAuth: Bool?
}

enum RPCAccountDetails: Decodable {
    case apiKey
    case chatgpt(email: String, planType: String)

    enum CodingKeys: String, CodingKey {
        case type
        case email
        case planType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type.lowercased() {
        case "apikey":
            self = .apiKey
        case "chatgpt":
            let email = try container.decodeIfPresent(String.self, forKey: .email) ?? "unknown"
            let plan = try container.decodeIfPresent(String.self, forKey: .planType) ?? "unknown"
            self = .chatgpt(email: email, planType: plan)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown account type \(type)")
        }
    }
}

struct RPCRateLimitsResponse: Decodable, Encodable {
    let rateLimits: RPCRateLimitSnapshot
}

struct RPCRateLimitSnapshot: Decodable, Encodable {
    let primary: RPCRateLimitWindow?
    let secondary: RPCRateLimitWindow?
    let credits: RPCCreditsSnapshot?
}

struct RPCRateLimitWindow: Decodable, Encodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Int?
}

struct RPCCreditsSnapshot: Decodable, Encodable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String?
}

enum RPCWireError: Error, CustomStringConvertible, Equatable {
    case startFailed(String)
    case requestFailed(String)
    case malformed(String)
    case timedOut(String)

    var description: String {
        switch self {
        case let .startFailed(message):
            "Failed to start codex app-server: \(message)"
        case let .requestFailed(message):
            "RPC request failed: \(message)"
        case let .malformed(message):
            "Malformed response: \(message)"
        case let .timedOut(method):
            "Codex RPC request '\(method)' timed out"
        }
    }
}

/// RPC helper used on background tasks; safe because we confine it to the owning task.
final class CodexRPCClient: @unchecked Sendable {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let lineQueue = LineQueue()
    private let requestTimeout: TimeInterval
    private var nextID = 1
    private var processGroup: pid_t?

    private final class LineQueue: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()
        private var pendingLines: [Data] = []
        private var waiters: [(id: UInt64, continuation: CheckedContinuation<Data?, Never>)] = []
        private var nextWaiterID: UInt64 = 1
        private var finished = false

        func append(_ data: Data) {
            var toResume: [(CheckedContinuation<Data?, Never>, Data?)] = []
            self.lock.lock()
            if !self.finished {
                self.buffer.append(data)
                while let newline = self.buffer.firstIndex(of: 0x0A) {
                    let lineData = Data(self.buffer[..<newline])
                    self.buffer.removeSubrange(...newline)
                    guard !lineData.isEmpty else { continue }
                    if !self.waiters.isEmpty {
                        let waiter = self.waiters.removeFirst()
                        toResume.append((waiter.continuation, lineData))
                    } else {
                        self.pendingLines.append(lineData)
                    }
                }
            }
            self.lock.unlock()

            for (continuation, line) in toResume {
                continuation.resume(returning: line)
            }
        }

        func finish() {
            var waitersToResume: [(id: UInt64, continuation: CheckedContinuation<Data?, Never>)] = []
            self.lock.lock()
            if !self.finished {
                self.finished = true
                waitersToResume = self.waiters
                self.waiters.removeAll()
            }
            self.lock.unlock()

            for waiter in waitersToResume {
                waiter.continuation.resume(returning: nil)
            }
        }

        func nextLine() async -> Data? {
            let waiterID = self.allocateWaiterID()
            return await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    enum Action {
                        case resume(Data?)
                        case wait
                    }

                    let action: Action
                    self.lock.lock()
                    if !self.pendingLines.isEmpty {
                        action = .resume(self.pendingLines.removeFirst())
                    } else if self.finished || Task.isCancelled {
                        action = .resume(nil)
                    } else {
                        self.waiters.append((id: waiterID, continuation: continuation))
                        action = .wait
                    }
                    self.lock.unlock()

                    if case let .resume(line) = action {
                        continuation.resume(returning: line)
                    }
                }
            } onCancel: {
                self.cancelWaiter(id: waiterID)
            }
        }

        private func allocateWaiterID() -> UInt64 {
            self.lock.lock()
            defer { self.lock.unlock() }
            let id = self.nextWaiterID
            self.nextWaiterID &+= 1
            return id
        }

        private func cancelWaiter(id: UInt64) {
            var cancelled: CheckedContinuation<Data?, Never>?
            self.lock.lock()
            if let index = self.waiters.firstIndex(where: { $0.id == id }) {
                cancelled = self.waiters.remove(at: index).continuation
            }
            self.lock.unlock()
            cancelled?.resume(returning: nil)
        }
    }

    private static func debugWriteStderr(_ message: String) {
        #if !os(Linux)
        fputs(message, stderr)
        #endif
    }

    init(
        executable: String = "codex",
        arguments: [String] = ["-s", "read-only", "-a", "never", "app-server"],
        requestTimeout: TimeInterval = 15.0) throws
    {
        self.requestTimeout = max(0.05, requestTimeout)

        let resolvedExec: String? = if executable == "codex" {
            BinaryLocator.resolveCodexBinary() ?? TTYCommandRunner.which(executable)
        } else if FileManager.default.isExecutableFile(atPath: executable) {
            executable
        } else {
            TTYCommandRunner.which(executable)
        }

        guard let resolvedExec else {
            throw RPCWireError.startFailed(
                "Codex CLI not found. Install with `npm i -g @openai/codex` (or bun) then relaunch Runic.")
        }
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = PathBuilder.effectivePATH(
            purposes: [.rpc, .nodeTooling],
            env: env)

        self.process.environment = env
        self.process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        self.process.arguments = [resolvedExec] + arguments
        self.process.standardInput = self.stdinPipe
        self.process.standardOutput = self.stdoutPipe
        self.process.standardError = self.stderrPipe

        do {
            try self.process.run()
        } catch {
            throw RPCWireError.startFailed(error.localizedDescription)
        }

        let pid = self.process.processIdentifier
        if setpgid(pid, pid) == 0 {
            self.processGroup = pid
        }

        let stdoutHandle = self.stdoutPipe.fileHandleForReading
        let lineQueue = self.lineQueue
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                lineQueue.finish()
                return
            }

            lineQueue.append(data)
        }

        let stderrHandle = self.stderrPipe.fileHandleForReading
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            // When the child closes stderr, availableData returns empty and will keep re-firing; clear the handler
            // to avoid a busy read loop on the file-descriptor monitoring queue.
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            for line in text.split(whereSeparator: \.isNewline) {
                Self.debugWriteStderr("[codex stderr] \(line)\n")
            }
        }
    }

    func initialize(clientName: String, clientVersion: String) async throws {
        _ = try await self.request(
            method: "initialize",
            params: ["clientInfo": ["name": clientName, "version": clientVersion]])
        try self.sendNotification(method: "initialized")
    }

    func fetchAccount() async throws -> RPCAccountResponse {
        let message = try await self.request(method: "account/read")
        return try self.decodeResult(from: message)
    }

    func fetchRateLimits() async throws -> RPCRateLimitsResponse {
        let message = try await self.request(method: "account/rateLimits/read")
        return try self.decodeResult(from: message)
    }

    func shutdown() {
        self.stdoutPipe.fileHandleForReading.readabilityHandler = nil
        self.stderrPipe.fileHandleForReading.readabilityHandler = nil
        self.lineQueue.finish()
        if self.process.isRunning {
            self.process.terminate()
        }
        if let pgid = self.processGroup {
            kill(-pgid, SIGTERM)
        }
        let waitDeadline = Date().addingTimeInterval(2.0)
        while self.process.isRunning, Date() < waitDeadline {
            usleep(100_000)
        }
        if self.process.isRunning {
            if let pgid = self.processGroup {
                kill(-pgid, SIGKILL)
            }
            kill(self.process.processIdentifier, SIGKILL)
        }
        try? self.stdinPipe.fileHandleForWriting.close()
        try? self.stdoutPipe.fileHandleForReading.close()
        try? self.stderrPipe.fileHandleForReading.close()
    }

    private func request(method: String, params: [String: Any]? = nil) async throws -> [String: Any] {
        let id = self.nextID
        self.nextID += 1
        try self.sendRequest(id: id, method: method, params: params)

        let deadline = Date().addingTimeInterval(self.requestTimeout)
        while true {
            let message = try await self.readNextMessage(deadline: deadline, method: method)

            if message["id"] == nil, let methodName = message["method"] as? String {
                Self.debugWriteStderr("[codex notify] \(methodName)\n")
                continue
            }

            guard let messageID = self.jsonID(message["id"]), messageID == id else { continue }

            if let error = message["error"] as? [String: Any], let messageText = error["message"] as? String {
                throw RPCWireError.requestFailed(messageText)
            }

            return message
        }
    }

    private func sendNotification(method: String, params: [String: Any]? = nil) throws {
        let paramsValue: Any = params ?? [:]
        try self.sendPayload(["method": method, "params": paramsValue])
    }

    private func sendRequest(id: Int, method: String, params: [String: Any]?) throws {
        let paramsValue: Any = params ?? [:]
        let payload: [String: Any] = ["id": id, "method": method, "params": paramsValue]
        try self.sendPayload(payload)
    }

    private func sendPayload(_ payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload)
        self.stdinPipe.fileHandleForWriting.write(data)
        self.stdinPipe.fileHandleForWriting.write(Data([0x0A]))
    }

    private func readNextMessage(deadline: Date, method: String) async throws -> [String: Any] {
        while true {
            let lineData = try await self.readNextLine(deadline: deadline, method: method)
            if lineData.isEmpty { continue }
            if let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                return json
            }
        }
    }

    private func readNextLine(deadline: Date, method: String) async throws -> Data {
        let lineQueue = self.lineQueue
        do {
            return try await withThrowingTaskGroup(of: Data.self) { group in
                group.addTask {
                    guard let line = await lineQueue.nextLine() else {
                        throw RPCWireError.malformed("codex app-server closed stdout")
                    }
                    return line
                }
                group.addTask {
                    let remaining = deadline.timeIntervalSinceNow
                    if remaining > 0 {
                        try await Task.sleep(for: .seconds(remaining))
                    }
                    throw RPCWireError.timedOut(method)
                }
                guard let line = try await group.next() else {
                    throw RPCWireError.timedOut(method)
                }
                group.cancelAll()
                return line
            }
        } catch let error as RPCWireError {
            if case .timedOut = error {
                self.shutdown()
            }
            throw error
        }
    }

    private func decodeResult<T: Decodable>(from message: [String: Any]) throws -> T {
        guard let result = message["result"] else {
            throw RPCWireError.malformed("missing result field")
        }
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func jsonID(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            int
        case let number as NSNumber:
            number.intValue
        default:
            nil
        }
    }
}
