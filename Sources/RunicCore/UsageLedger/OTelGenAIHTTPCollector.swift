import Foundation
import Security

#if canImport(Network)
import Network

public final class OTelGenAIHTTPCollector: @unchecked Sendable {
    private static let maxEventStreamClients = 16
    private static let eventStreamHeartbeatInterval: Duration = .seconds(15)

    private struct RequestConfiguration {
        let maxRequestBytes: Int
        let host: String
        let port: UInt16
        let authorizationToken: String
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "runic.otel-genai.collector")
    private let sink: OTelGenAIIngestionSink
    private let eventHub: RunicLocalEventHub
    private let requestConfiguration: RequestConfiguration
    public let authorizationToken: String

    public init(
        configuration: OTelGenAICollectorConfiguration = OTelGenAICollectorConfiguration(),
        eventHub: RunicLocalEventHub = .shared) throws
    {
        guard OTelGenAIHTTPCollectorRequestPolicy.isLoopbackHost(configuration.host) else {
            throw OTelGenAICollectorError.nonLoopbackHost(configuration.host)
        }
        guard let port = NWEndpoint.Port(rawValue: configuration.port) else {
            throw OTelGenAICollectorError.invalidContentLength
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host(configuration.host),
            port: port)
        self.listener = try NWListener(using: parameters)
        self.sink = OTelGenAIIngestionSink(configuration: configuration)
        self.eventHub = eventHub
        var tokenBytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, tokenBytes.count, &tokenBytes) == errSecSuccess else {
            throw OTelGenAICollectorError.invalidAuthorizationToken
        }
        self.authorizationToken = tokenBytes.map { String(format: "%02x", $0) }.joined()
        self.requestConfiguration = RequestConfiguration(
            maxRequestBytes: configuration.maxBodyBytes + 16384,
            host: configuration.host,
            port: configuration.port,
            authorizationToken: self.authorizationToken)
    }

    public func start() {
        self.listener.newConnectionHandler = { [sink, eventHub, requestConfiguration] connection in
            connection.start(queue: DispatchQueue(label: "runic.otel-genai.connection"))
            Self.receive(
                connection: connection,
                sink: sink,
                eventHub: eventHub,
                configuration: requestConfiguration,
                buffer: Data())
        }
        self.listener.start(queue: self.queue)
    }

    public func cancel() {
        self.listener.cancel()
    }

    private static func receive(
        connection: NWConnection,
        sink: OTelGenAIIngestionSink,
        eventHub: RunicLocalEventHub,
        configuration: RequestConfiguration,
        buffer: Data)
    {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            var nextBuffer = buffer
            if let data { nextBuffer.append(data) }

            guard nextBuffer.count > configuration.maxRequestBytes || Self
                .hasCompleteHTTPRequest(nextBuffer) || isComplete || error != nil
            else {
                Self.receive(
                    connection: connection,
                    sink: sink,
                    eventHub: eventHub,
                    configuration: configuration,
                    buffer: nextBuffer)
                return
            }

            guard nextBuffer.count <= configuration.maxRequestBytes else {
                let response = Data("HTTP/1.1 413 Content Too Large\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    .utf8)
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
                return
            }

            guard OTelGenAIHTTPCollectorRequestPolicy.permits(
                nextBuffer,
                boundHost: configuration.host,
                port: configuration.port,
                authorizationToken: configuration.authorizationToken)
            else {
                let response = Data("HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
                return
            }

            if let route = Self.streamRoute(for: nextBuffer) {
                Self.startEventStream(route: route, connection: connection, eventHub: eventHub)
                return
            }

            Task {
                let response = await OTelGenAIHTTPIngestHandler.handle(nextBuffer, sink: sink, eventHub: eventHub)
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }

    private static func startEventStream(
        route: EventStreamRoute,
        connection: NWConnection,
        eventHub: RunicLocalEventHub)
    {
        let task = Task {
            do {
                guard await eventHub.subscriberCount < Self.maxEventStreamClients else {
                    try await Self.send(Self.streamUnavailableResponse(), on: connection)
                    connection.cancel()
                    return
                }
                try await Self.send(Self.streamHeaders(for: route.format), on: connection)
                try await Self.send(Self.chunk(Self.readyFrame(for: route.format)), on: connection)
                for await frame in Self.frames(for: route.format, eventHub: eventHub) {
                    try Task.checkCancellation()
                    try await Self.send(Self.chunk(frame), on: connection)
                }
            } catch {}
            connection.cancel()
        }

        Self.monitorClientClose(connection: connection) {
            task.cancel()
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .cancelled, .failed:
                task.cancel()
            default:
                break
            }
        }
    }

    private static func frames(for format: EventStreamFormat, eventHub: RunicLocalEventHub) -> AsyncStream<Data> {
        AsyncStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
            let eventTask = Task {
                do {
                    for await event in await eventHub.stream(replayLatest: false, bufferingNewest: 32) {
                        try Task.checkCancellation()
                        try continuation.yield(Self.frame(for: event, format: format))
                    }
                } catch {}
                continuation.finish()
            }
            let heartbeatTask = Task {
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: Self.eventStreamHeartbeatInterval)
                        continuation.yield(Self.heartbeatFrame(for: format))
                    } catch {
                        break
                    }
                }
            }
            continuation.onTermination = { _ in
                eventTask.cancel()
                heartbeatTask.cancel()
            }
        }
    }

    private static func monitorClientClose(connection: NWConnection, onClose: @escaping @Sendable () -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { data, _, isComplete, error in
            if isComplete || error != nil || data?.isEmpty == false {
                onClose()
                return
            }
            Self.monitorClientClose(connection: connection, onClose: onClose)
        }
    }

    private static func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private static func streamRoute(for data: Data) -> EventStreamRoute? {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)),
              let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8)
        else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2, parts[0].uppercased() == "GET" else { return nil }
        let path = parts[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? parts[1]
        guard path == "/events" || path == "/v1/events" else { return nil }

        let accepts = lines
            .dropFirst()
            .first { $0.lowercased().hasPrefix("accept:") }?
            .lowercased() ?? ""
        let format: EventStreamFormat = accepts.contains("x-ndjson") ? .ndjson : .sse
        return EventStreamRoute(format: format)
    }

    private static func streamHeaders(for format: EventStreamFormat) -> Data {
        let contentType = switch format {
        case .sse: "text/event-stream"
        case .ndjson: "application/x-ndjson"
        }
        let header = [
            "HTTP/1.1 200 OK",
            "Content-Type: \(contentType)",
            "Cache-Control: no-cache",
            "Connection: keep-alive",
            "Transfer-Encoding: chunked",
        ].joined(separator: "\r\n") + "\r\n\r\n"
        return Data(header.utf8)
    }

    private static func streamUnavailableResponse() -> Data {
        let payload = Data(#"{"error":"too many local event stream clients"}"#.utf8)
        let header = [
            "HTTP/1.1 503 Service Unavailable",
            "Content-Type: application/json",
            "Content-Length: \(payload.count)",
            "Connection: close",
        ].joined(separator: "\r\n") + "\r\n\r\n"
        return Data(header.utf8) + payload
    }

    private static func readyFrame(for format: EventStreamFormat) -> Data {
        switch format {
        case .sse:
            Data(": runic stream ready\n\n".utf8)
        case .ndjson:
            Data(#"{"type":"ready"}"#.utf8) + Data("\n".utf8)
        }
    }

    private static func heartbeatFrame(for format: EventStreamFormat) -> Data {
        switch format {
        case .sse:
            Data(": ping\n\n".utf8)
        case .ndjson:
            Data(#"{"type":"heartbeat"}"#.utf8) + Data("\n".utf8)
        }
    }

    static func frame(for event: RunicLocalEvent, format: EventStreamFormat) throws -> Data {
        let payload = try JSONEncoder.runicEventStream.encode(event)
        switch format {
        case .sse:
            let json = String(data: payload, encoding: .utf8) ?? "{}"
            return Data("id: \(event.id)\nevent: \(event.type)\ndata: \(json)\n\n".utf8)
        case .ndjson:
            return payload + Data("\n".utf8)
        }
    }

    private static func chunk(_ data: Data) -> Data {
        Data(String(data.count, radix: 16).utf8) + Data("\r\n".utf8) + data + Data("\r\n".utf8)
    }

    private static func hasCompleteHTTPRequest(_ data: Data) -> Bool {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else { return false }
        guard let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else { return false }
        let contentLength = headerText.components(separatedBy: "\r\n")
            .dropFirst()
            .first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { line -> Int? in
                let value = line.split(separator: ":", maxSplits: 1).dropFirst().first
                return value.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            }
        guard let contentLength else { return true }
        return data.count - headerRange.upperBound >= contentLength
    }
}

enum OTelGenAIHTTPCollectorRequestPolicy {
    static func isLoopbackHost(_ host: String) -> Bool {
        ["127.0.0.1", "localhost", "::1"].contains(host.lowercased())
    }

    static func permits(_ request: Data, boundHost: String, port: UInt16, authorizationToken: String) -> Bool {
        guard let headerEnd = request.range(of: Data("\r\n\r\n".utf8)),
              let header = String(data: request[..<headerEnd.lowerBound], encoding: .utf8)
        else { return false }

        let lines = header.components(separatedBy: "\r\n").dropFirst()
        let hosts = lines.filter { $0.lowercased().hasPrefix("host:") }
        let authorization = lines.filter { $0.lowercased().hasPrefix("authorization:") }
        guard hosts.count == 1,
              authorization.count == 1,
              !lines.contains(where: { $0.lowercased().hasPrefix("origin:") })
        else { return false }

        let supplied = authorization[0].dropFirst("authorization:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard supplied.hasPrefix("Bearer ") else { return false }
        let suppliedToken = supplied.dropFirst("Bearer ".count).utf8
        let expectedToken = authorizationToken.utf8
        guard suppliedToken.count == expectedToken.count else { return false }
        var difference: UInt8 = 0
        for (actual, expected) in zip(suppliedToken, expectedToken) {
            difference |= actual ^ expected
        }
        guard difference == 0 else { return false }

        let requestedHost = hosts[0].dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard self.isLoopbackHost(boundHost) else { return false }
        let bound = boundHost == "::1" ? "[::1]" : boundHost.lowercased()
        let allowedHosts = [bound, "\(bound):\(port)"]
        return allowedHosts.contains(requestedHost)
    }
}

enum EventStreamFormat {
    case sse
    case ndjson
}

private struct EventStreamRoute {
    let format: EventStreamFormat
}

extension JSONEncoder {
    fileprivate static var runicEventStream: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
#endif
