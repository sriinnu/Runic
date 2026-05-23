import Foundation

public struct RunicLocalEvent: Codable, Equatable, Sendable {
    public let id: String
    public let type: String
    public let createdAt: Date
    public let payload: [String: String]

    public init(id: String = UUID().uuidString, type: String, createdAt: Date = Date(), payload: [String: String]) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.payload = payload
    }

    public static func otelIngest(acceptedEntries: Int, outputFile: URL) -> RunicLocalEvent {
        RunicLocalEvent(
            type: "otel.ingest",
            payload: [
                "accepted_entries": String(acceptedEntries),
                "output_file": outputFile.path,
            ])
    }
}

public actor RunicLocalEventHub {
    public static let shared = RunicLocalEventHub()

    private var continuations: [UUID: AsyncStream<RunicLocalEvent>.Continuation] = [:]
    private var latestEvent: RunicLocalEvent?

    public init() {}

    public var subscriberCount: Int {
        self.continuations.count
    }

    public func publish(_ event: RunicLocalEvent) {
        self.latestEvent = event
        for continuation in self.continuations.values {
            continuation.yield(event)
        }
    }

    public func stream(replayLatest: Bool = true) -> AsyncStream<RunicLocalEvent> {
        AsyncStream { continuation in
            let id = UUID()
            self.continuations[id] = continuation
            if replayLatest, let latestEvent {
                continuation.yield(latestEvent)
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private func removeContinuation(_ id: UUID) {
        self.continuations[id] = nil
    }
}
