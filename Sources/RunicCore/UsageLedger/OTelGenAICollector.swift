import Foundation

public struct OTelGenAICollectorConfiguration: Sendable, Equatable {
    public var host: String
    public var port: UInt16
    public var outputFile: URL
    public var defaultProvider: UsageProvider?
    public var maxBodyBytes: Int

    public init(
        host: String = "127.0.0.1",
        port: UInt16 = 4318,
        outputFile: URL = OTelGenAICollectorConfiguration.defaultOutputFile(),
        defaultProvider: UsageProvider? = nil,
        maxBodyBytes: Int = 2 * 1024 * 1024)
    {
        self.host = host
        self.port = port
        self.outputFile = outputFile
        self.defaultProvider = defaultProvider
        self.maxBodyBytes = maxBodyBytes
    }

    public static func defaultOutputFile() -> URL {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let filename = String(
            format: "ingest-%04d-%02d-%02d.jsonl",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1)
        return self.defaultOutputDirectory().appendingPathComponent(filename, isDirectory: false)
    }

    public static func defaultOutputDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return appSupport
            .appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("otel-genai", isDirectory: true)
    }
}

public struct OTelGenAICollectorResult: Sendable, Equatable {
    public let acceptedEntries: Int
    public let outputFile: URL

    public init(acceptedEntries: Int, outputFile: URL) {
        self.acceptedEntries = acceptedEntries
        self.outputFile = outputFile
    }
}

public enum OTelGenAICollectorError: LocalizedError, Sendable, Equatable {
    case bodyTooLarge(Int)
    case noGenAIEntries
    case unsupportedMethod(String)
    case unsupportedPath(String)
    case unsupportedContentType(String?)
    case malformedHTTPRequest
    case invalidContentLength

    public var errorDescription: String? {
        switch self {
        case let .bodyTooLarge(limit):
            "OTel payload exceeds Runic's \(limit) byte ingest limit."
        case .noGenAIEntries:
            "OTel payload did not contain GenAI usage entries that Runic can track."
        case let .unsupportedMethod(method):
            "Runic OTLP JSON ingest only supports POST, not \(method)."
        case let .unsupportedPath(path):
            "Runic OTLP JSON ingest does not handle \(path). Use /v1/traces or /v1/logs."
        case let .unsupportedContentType(contentType):
            "Runic OTLP ingest currently accepts JSON only, not \(contentType ?? "missing content type")."
        case .malformedHTTPRequest:
            "Malformed HTTP request."
        case .invalidContentLength:
            "Invalid HTTP Content-Length."
        }
    }
}

public actor OTelGenAIIngestionSink {
    private let outputFile: URL
    private let rollsDefaultOutputDaily: Bool
    private let options: OTelGenAIIngestionOptions
    private let maxBodyBytes: Int

    public init(configuration: OTelGenAICollectorConfiguration = OTelGenAICollectorConfiguration()) {
        self.outputFile = configuration.outputFile
        self.rollsDefaultOutputDaily = configuration.outputFile.standardizedFileURL.path
            == OTelGenAICollectorConfiguration.defaultOutputFile().standardizedFileURL.path
        self.maxBodyBytes = configuration.maxBodyBytes
        self.options = OTelGenAIIngestionOptions(
            enabled: true,
            allowExperimentalSemanticConventions: true,
            defaultProvider: configuration.defaultProvider,
            source: .openTelemetry)
    }

    public func ingest(_ data: Data) throws -> OTelGenAICollectorResult {
        guard data.count <= self.maxBodyBytes else {
            throw OTelGenAICollectorError.bodyTooLarge(self.maxBodyBytes)
        }

        let entries = try OTelGenAILedgerAdapter.parseData(data, options: self.options)
        guard !entries.isEmpty else {
            throw OTelGenAICollectorError.noGenAIEntries
        }

        let lines = try entries.map(Self.sanitizedJSONLine)
        let outputFile = self.currentOutputFile()
        let directory = outputFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let payload = (lines.joined(separator: "\n") + "\n").data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: outputFile.path) {
            let handle = try FileHandle(forWritingTo: outputFile)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: payload)
        } else {
            try payload.write(to: outputFile, options: .atomic)
        }

        return OTelGenAICollectorResult(acceptedEntries: entries.count, outputFile: outputFile)
    }

    private func currentOutputFile() -> URL {
        self.rollsDefaultOutputDaily ? OTelGenAICollectorConfiguration.defaultOutputFile() : self.outputFile
    }

    private static func sanitizedJSONLine(for entry: UsageLedgerEntry) throws -> String {
        var record: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
            "provider": entry.provider.rawValue,
            "input_tokens": entry.inputTokens,
            "output_tokens": entry.outputTokens,
            "cache_creation_tokens": entry.cacheCreationTokens,
            "cache_read_tokens": entry.cacheReadTokens,
        ]

        if let sessionID = entry.sessionID { record["session_id"] = sessionID }
        if let projectID = entry.projectID { record["project_id"] = projectID }
        if let projectName = entry.projectName { record["project_name"] = projectName }
        if let model = entry.model { record["model"] = model }
        if let costUSD = entry.costUSD { record["cost_usd"] = costUSD }
        if let requestID = entry.requestID { record["request_id"] = requestID }
        if let messageID = entry.messageID { record["message_id"] = messageID }
        if let version = entry.version { record["sdk.version"] = version }
        if let operationKind = entry.operationKind { record["operation.name"] = operationKind.rawValue }

        let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

public enum OTelGenAIHTTPIngestHandler {
    public static func handle(
        _ requestData: Data,
        sink: OTelGenAIIngestionSink,
        eventHub: RunicLocalEventHub? = nil) async -> Data
    {
        do {
            let request = try Self.parseRequest(requestData)
            let result = try await sink.ingest(request.body)
            await eventHub?.publish(.otelIngest(acceptedEntries: result.acceptedEntries, outputFile: result.outputFile))
            return Self.response(
                status: 200,
                body: #"{"accepted":\#(result.acceptedEntries)}"#)
        } catch {
            let status = Self.statusCode(for: error)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return Self.response(status: status, body: #"{"error":"\#(Self.escapeJSON(message))"}"#)
        }
    }

    private static func parseRequest(_ data: Data) throws -> HTTPRequest {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            throw OTelGenAICollectorError.malformedHTTPRequest
        }
        let headerData = data[..<headerRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw OTelGenAILedgerAdapterError.invalidUTF8
        }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw OTelGenAICollectorError.malformedHTTPRequest
        }
        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else {
            throw OTelGenAICollectorError.malformedHTTPRequest
        }
        guard parts[0].uppercased() == "POST" else {
            throw OTelGenAICollectorError.unsupportedMethod(parts[0])
        }
        guard ["/", "/v1/traces", "/v1/logs"].contains(parts[1]) else {
            throw OTelGenAICollectorError.unsupportedPath(parts[1])
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            headers[pair[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] =
                pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let contentType = headers["content-type"]
        if let contentType,
           !contentType.lowercased().contains("json")
        {
            throw OTelGenAICollectorError.unsupportedContentType(contentType)
        }

        let bodyStart = headerRange.upperBound
        let body = data[bodyStart...]
        if let lengthText = headers["content-length"] {
            guard let expected = Int(lengthText), expected >= 0 else {
                throw OTelGenAICollectorError.invalidContentLength
            }
            guard body.count >= expected else {
                throw OTelGenAICollectorError.malformedHTTPRequest
            }
            return HTTPRequest(body: Data(body.prefix(expected)))
        }
        return HTTPRequest(body: Data(body))
    }

    private static func response(status: Int, body: String) -> Data {
        let reason = switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 413: "Payload Too Large"
        case 415: "Unsupported Media Type"
        case 422: "Unprocessable Content"
        default: "Internal Server Error"
        }
        let payload = Data(body.utf8)
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: application/json\r\n"
        header += "Content-Length: \(payload.count)\r\n"
        header += "Connection: close\r\n\r\n"
        return Data(header.utf8) + payload
    }

    private static func statusCode(for error: Error) -> Int {
        switch error {
        case OTelGenAICollectorError.bodyTooLarge:
            413
        case OTelGenAICollectorError.unsupportedMethod:
            405
        case OTelGenAICollectorError.unsupportedPath:
            404
        case OTelGenAICollectorError.unsupportedContentType:
            415
        case OTelGenAICollectorError.noGenAIEntries:
            422
        default:
            400
        }
    }

    private static func escapeJSON(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private struct HTTPRequest {
        let body: Data
    }
}
