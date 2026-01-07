import Foundation

public protocol UsageLedgerSource: Sendable {
    func loadEntries() async throws -> [UsageLedgerEntry]
}

public struct UsageLedger: Sendable {
    private let sources: [UsageLedgerSource]

    public init(sources: [UsageLedgerSource]) {
        self.sources = sources
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        guard !self.sources.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: [UsageLedgerEntry].self) { group in
            for source in self.sources {
                group.addTask {
                    try await source.loadEntries()
                }
            }
            var entries: [UsageLedgerEntry] = []
            for try await batch in group {
                entries.append(contentsOf: batch)
            }
            return entries
        }
    }
}
