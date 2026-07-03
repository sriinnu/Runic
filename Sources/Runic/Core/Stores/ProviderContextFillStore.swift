import Foundation
import RunicCore

/// A live context-window reading for a provider's current session with its
/// denominator already resolved (transcript-reported window preferred, else
/// the registry chain).
struct ResolvedContextFill: Equatable {
    let occupiedTokens: Int
    let maxTokens: Int?
    let model: String?
    /// Timestamp of the transcript entry (NOT the scan time) — the staleness
    /// gate at render time.
    let sampledAt: Date
}

/// Bridges the ledger refresh path (writer, off-main) and menu card
/// construction (reader) without widening the card-model `Input` surface.
/// Same lock-guarded singleton pattern as `ProviderContextWindowRegistry`.
final class ProviderContextFillStore: @unchecked Sendable {
    static let shared = ProviderContextFillStore()

    /// A reading whose transcript entry is older than this belongs to an idle
    /// session; its fill percentage is noise and must not be shown.
    static let maxSampleAge: TimeInterval = 30 * 60

    private let lock = NSLock()
    private var fills: [UsageProvider: ResolvedContextFill] = [:]

    func update(_ fill: ResolvedContextFill?, for provider: UsageProvider) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.fills[provider] = fill
    }

    func fill(for provider: UsageProvider) -> ResolvedContextFill? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.fills[provider]
    }
}
