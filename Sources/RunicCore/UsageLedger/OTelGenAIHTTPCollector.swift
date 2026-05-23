import Foundation

#if canImport(Network)
import Network

public final class OTelGenAIHTTPCollector: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "runic.otel-genai.collector")
    private let sink: OTelGenAIIngestionSink
    private let eventHub: RunicLocalEventHub
    private let maxRequestBytes: Int

    public init(
        configuration: OTelGenAICollectorConfiguration = OTelGenAICollectorConfiguration(),
        eventHub: RunicLocalEventHub = .shared) throws
    {
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
        self.maxRequestBytes = configuration.maxBodyBytes + 16384
    }

    public func start() {
        self.listener.newConnectionHandler = { [sink, eventHub, maxRequestBytes] connection in
            connection.start(queue: DispatchQueue(label: "runic.otel-genai.connection"))
            Self.receive(
                connection: connection,
                sink: sink,
                eventHub: eventHub,
                maxRequestBytes: maxRequestBytes,
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
        maxRequestBytes: Int,
        buffer: Data)
    {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            var nextBuffer = buffer
            if let data { nextBuffer.append(data) }

            guard nextBuffer.count > maxRequestBytes || Self
                .hasCompleteHTTPRequest(nextBuffer) || isComplete || error != nil
            else {
                Self.receive(
                    connection: connection,
                    sink: sink,
                    eventHub: eventHub,
                    maxRequestBytes: maxRequestBytes,
                    buffer: nextBuffer)
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
                try await Self.send(Self.streamHeaders(for: route.format), on: connection)
                try await Self.send(Self.chunk(Self.readyFrame(for: route.format)), on: connection)
                for await event in await eventHub.stream() {
                    try Task.checkCancellation()
                    try await Self.send(Self.chunk(Self.frame(for: event, format: route.format)), on: connection)
                }
            } catch {}
            connection.cancel()
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

    private static func readyFrame(for format: EventStreamFormat) -> Data {
        switch format {
        case .sse:
            Data(": runic stream ready\n\n".utf8)
        case .ndjson:
            Data(#"{"type":"ready"}"#.utf8) + Data("\n".utf8)
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
