import Foundation
import RunicCore

/// Scheduled retention pruning for the local performance database.
///
/// The retention settings in the Performance pane
/// (`rawMetricsRetentionDays` / `aggregatedStatsRetentionYears`) were only
/// honored by the manual "Clear Old Data" button, so `performance.db` grew
/// unbounded for anyone who never pressed it. This runs the same
/// `deleteOldData` pass shortly after launch and then once per day, off the
/// main actor.
@MainActor
final class PerformanceRetentionPruner {
    nonisolated static let lastPruneDefaultsKey = "performanceRetentionLastPruneAt"
    nonisolated static let pruneInterval: TimeInterval = 24 * 60 * 60
    /// Small delay after launch so pruning never competes with startup work.
    nonisolated static let launchDelay: Duration = .seconds(30)

    private var task: Task<Void, Never>?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether a prune is due: never pruned before, or the last prune is at
    /// least a day old. (Clock rollbacks just delay the next prune by a day.)
    nonisolated static func isPruneDue(lastPrune: Date?, now: Date) -> Bool {
        guard let lastPrune else { return true }
        return now.timeIntervalSince(lastPrune) >= self.pruneInterval
    }

    func start() {
        guard self.task == nil else { return }
        self.task = Task { [weak self] in
            try? await Task.sleep(for: Self.launchDelay)
            while !Task.isCancelled {
                await self?.pruneIfDue()
                try? await Task.sleep(for: .seconds(Self.pruneInterval))
                guard self != nil else { return }
            }
        }
    }

    func stop() {
        self.task?.cancel()
        self.task = nil
    }

    private func pruneIfDue(now: Date = Date()) async {
        let lastPrune = self.defaults.object(forKey: Self.lastPruneDefaultsKey) as? Date
        guard Self.isPruneDue(lastPrune: lastPrune, now: now) else { return }

        // Same keys and defaults as the Performance pane's @AppStorage.
        let rawDays = self.defaults.object(forKey: "rawMetricsRetentionDays") as? Int ?? 30
        let aggregatedYears = self.defaults.object(forKey: "aggregatedStatsRetentionYears") as? Int ?? 1

        let succeeded = await Task.detached(priority: .utility) {
            do {
                let storage = PerformanceStorageImpl()
                try await storage.deleteOldData(
                    olderThan: max(1, rawDays),
                    aggregatedStatsOlderThanYears: max(1, aggregatedYears))
                return true
            } catch {
                RunicLog.logger("performance-retention").warning(
                    "Scheduled performance retention prune failed",
                    metadata: ["error": error.localizedDescription])
                return false
            }
        }.value

        if succeeded {
            self.defaults.set(now, forKey: Self.lastPruneDefaultsKey)
        }
    }

    deinit {
        self.task?.cancel()
    }
}
