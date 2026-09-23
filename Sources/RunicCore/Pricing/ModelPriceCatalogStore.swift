import Foundation

/// Live prices: bundled copy, then the models.dev list cached for a day, then
/// the user's own overrides (`pricing/custom-prices.json`, same format as the
/// cache) on top. The fetch is one public GET with no credentials.
public final class ModelPriceCatalogStore: @unchecked Sendable {
    public static let shared = ModelPriceCatalogStore()

    static let sourceURL = URL(string: "https://models.dev/api.json")!
    static let maxAge: TimeInterval = 24 * 3600
    static let failureBackoff: TimeInterval = 15 * 60

    private let lock = NSLock()
    private let directory: URL?
    private var live: ModelPriceCatalog?
    private var liveFetchedAt: Date?
    private var lastFailureAt: Date?
    private var loadedFromDisk = false
    private var isFetching = false
    private static let log = RunicLog.logger("model-prices")

    public init(directory: URL? = ModelPriceCatalogStore.defaultDirectory()) {
        self.directory = directory
    }

    /// The prices to use right now; never blocks on the network.
    public func catalog() -> ModelPriceCatalog {
        self.lock.lock()
        self.loadFromDiskLocked()
        var catalog = ModelPriceCatalog.bundled
        if let live = self.live { catalog = catalog.overlaid(by: live) }
        self.lock.unlock()
        if let custom = self.read("custom-prices.json") { catalog = catalog.overlaid(by: custom) }
        return catalog
    }

    /// Fetches models.dev when the cached copy is over a day old, backing off
    /// for 15 minutes after a failure. Safe to call on every ledger refresh.
    public func refreshIfStale(now: Date = Date()) async {
        guard self.beginFetchIfStale(now: now) else { return }
        var request = URLRequest(url: Self.sourceURL)
        request.timeoutInterval = 30
        var fetched: ModelPriceCatalog?
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let day = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate])
            fetched = try ModelPriceCatalog.fromModelsDev(data, snapshot: day)
        } catch {
            Self.log.warning("models.dev price fetch failed: \(error.localizedDescription)")
        }
        self.finishFetch(fetched, now: now)
        if let fetched, let data = try? fetched.encodedSnapshot() { self.write(data, to: "models-dev.json") }
    }

    private func beginFetchIfStale(now: Date) -> Bool {
        self.lock.withLock {
            self.loadFromDiskLocked()
            let fresh = self.liveFetchedAt.map { now.timeIntervalSince($0) < Self.maxAge } ?? false
            let backingOff = self.lastFailureAt.map { now.timeIntervalSince($0) < Self.failureBackoff } ?? false
            guard !fresh, !backingOff, !self.isFetching else { return false }
            self.isFetching = true
            return true
        }
    }

    private func finishFetch(_ fetched: ModelPriceCatalog?, now: Date) {
        self.lock.withLock {
            self.isFetching = false
            if let fetched {
                self.live = fetched
                self.liveFetchedAt = now
                self.lastFailureAt = nil
            } else {
                self.lastFailureAt = now
            }
        }
    }

    private func loadFromDiskLocked() {
        guard !self.loadedFromDisk else { return }
        self.loadedFromDisk = true
        guard let url = self.directory?.appendingPathComponent("models-dev.json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? ModelPriceCatalog.decodeSnapshot(data) else { return }
        self.live = catalog
        let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        self.liveFetchedAt = modified
    }

    private func read(_ name: String) -> ModelPriceCatalog? {
        guard let url = self.directory?.appendingPathComponent(name),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? ModelPriceCatalog.decodeSnapshot(data)
    }

    private func write(_ data: Data, to name: String) {
        guard let directory = self.directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    public static func defaultDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Runic/pricing", isDirectory: true)
    }
}

/// Spend estimated from token counts in the local logs, at catalog prices.
public struct LogSpendEstimate: Sendable, Equatable {
    public var today: Double
    public var thisMonth: Double
    /// Tokens this month on models the catalog has no price for. Shown as a
    /// count, never folded in as $0.
    public var unpricedTokens: Int
    public var unpricedModels: [String]

    public init(today: Double, thisMonth: Double, unpricedTokens: Int = 0, unpricedModels: [String] = []) {
        self.today = today
        self.thisMonth = thisMonth
        self.unpricedTokens = unpricedTokens
        self.unpricedModels = unpricedModels
    }
}

public enum LogSpendEstimator {
    /// Month-to-date and today for one provider's entries. Nil when the
    /// provider has no price list or no usage this month.
    public static func estimate(
        provider: UsageProvider,
        entries: [UsageLedgerEntry],
        catalog: ModelPriceCatalog,
        now: Date,
        calendar: Calendar) -> LogSpendEstimate?
    {
        guard ModelPriceCatalog.pricedProviders.contains(provider) else { return nil }
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        var estimate = LogSpendEstimate(today: 0, thisMonth: 0)
        var unpriced = Set<String>()
        var sawUsage = false
        let monthEntries = entries.filter {
            $0.provider == provider && $0.timestamp >= monthStart && $0.timestamp <= now
        }
        for entry in monthEntries {
            let tokens = entry.inputTokens + entry.outputTokens + entry.cacheCreationTokens + entry.cacheReadTokens
            guard tokens > 0 else { continue }
            sawUsage = true
            guard let model = entry.model, let price = catalog.price(for: provider, model: model) else {
                estimate.unpricedTokens += tokens
                unpriced.insert(entry.model ?? "unknown model")
                continue
            }
            let cost = price.cost(
                input: entry.inputTokens,
                output: entry.outputTokens,
                cacheWrite: entry.cacheCreationTokens,
                cacheRead: entry.cacheReadTokens)
            estimate.thisMonth += cost
            if calendar.isDate(entry.timestamp, inSameDayAs: now) { estimate.today += cost }
        }
        guard sawUsage else { return nil }
        estimate.unpricedModels = unpriced.sorted()
        return estimate
    }
}
