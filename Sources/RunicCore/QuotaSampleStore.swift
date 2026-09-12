import Foundation

/// One reading of a quota window: what the provider said the meter was at,
/// and when it said it would reset. Refreshes append these so the Burn
/// panel can draw the actual curve instead of a single number.
public struct QuotaSample: Codable, Sendable, Equatable {
    public let at: Date
    public let usedPercent: Double
    public let resetsAt: Date?
    public let windowMinutes: Int?

    public init(at: Date, usedPercent: Double, resetsAt: Date?, windowMinutes: Int?) {
        self.at = at
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.windowMinutes = windowMinutes
    }
}

/// Which of a snapshot's windows a sample belongs to.
public enum QuotaWindowSlot: String, Codable, Sendable, CaseIterable {
    case primary
    case secondary
    case tertiary

    public func window(in snapshot: UsageSnapshot) -> RateWindow? {
        switch self {
        case .primary: snapshot.primary
        case .secondary: snapshot.secondary
        case .tertiary: snapshot.tertiary
        }
    }
}

/// Append-only history of quota readings per provider and window, one JSONL
/// file per provider under Application Support. Cheap on every refresh:
/// exact repeats inside two minutes are dropped, and the in-memory cache is
/// what the UI reads. `memoryOnly` keeps throwaway processes (screenshot
/// renders, tests) off the disk.
public final class QuotaSampleStore: @unchecked Sendable {
    public static let shared = QuotaSampleStore()

    private struct Line: Codable {
        let slot: QuotaWindowSlot
        let sample: QuotaSample
    }

    /// Readings older than this are dropped on load and on the periodic rewrite.
    public static let retention: TimeInterval = 21 * 86400
    private static let rewriteThreshold = 6000
    private static let duplicateWindow: TimeInterval = 120

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.sriinnu.runic.quota-samples", qos: .utility)
    private let directory: URL?
    private var cache: [UsageProvider: [QuotaWindowSlot: [QuotaSample]]] = [:]
    private var loaded: Set<UsageProvider> = []
    private var appendedSinceRewrite: [UsageProvider: Int] = [:]

    /// True in throwaway processes: nothing is read from or written to disk.
    public var memoryOnly: Bool

    public init(directory: URL? = nil, memoryOnly: Bool = false) {
        self.directory = directory ?? Self.defaultDirectory()
        self.memoryOnly = memoryOnly
    }

    // MARK: - Recording

    /// Record every window of `snapshot` that reports a real percentage.
    public func record(provider: UsageProvider, snapshot: UsageSnapshot, at date: Date = .init()) {
        for slot in QuotaWindowSlot.allCases {
            guard let window = slot.window(in: snapshot), window.hasKnownLimit != false else { continue }
            self.record(
                provider: provider,
                slot: slot,
                sample: QuotaSample(
                    at: date,
                    usedPercent: min(100, max(0, window.usedPercent)),
                    resetsAt: window.resetsAt,
                    windowMinutes: window.windowMinutes))
        }
    }

    public func record(provider: UsageProvider, slot: QuotaWindowSlot, sample: QuotaSample) {
        self.lock.lock()
        self.loadIfNeededLocked(provider)
        if let last = self.cache[provider]?[slot]?.last,
           last.usedPercent == sample.usedPercent,
           last.resetsAt == sample.resetsAt,
           sample.at.timeIntervalSince(last.at) < Self.duplicateWindow
        {
            self.lock.unlock()
            return
        }
        self.cache[provider, default: [:]][slot, default: []].append(sample)
        let appended = (self.appendedSinceRewrite[provider] ?? 0) + 1
        self.appendedSinceRewrite[provider] = appended
        let needsRewrite = appended >= Self.rewriteThreshold
        if needsRewrite { self.appendedSinceRewrite[provider] = 0 }
        let snapshotForRewrite = needsRewrite ? self.cache[provider] : nil
        self.lock.unlock()

        guard !self.memoryOnly, let url = self.fileURL(for: provider) else { return }
        self.queue.async {
            if let snapshotForRewrite {
                Self.rewrite(snapshotForRewrite, to: url)
            } else {
                Self.append(Line(slot: slot, sample: sample), to: url)
            }
        }
    }

    // MARK: - Reading

    /// Samples for one window, oldest first, optionally since a date.
    public func samples(provider: UsageProvider, slot: QuotaWindowSlot, since: Date? = nil) -> [QuotaSample] {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.loadIfNeededLocked(provider)
        let all = self.cache[provider]?[slot] ?? []
        guard let since else { return all }
        return all.filter { $0.at >= since }
    }

    /// Whether any window of this provider has enough history to draw.
    public func hasHistory(provider: UsageProvider, minimumSamples: Int = 2) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.loadIfNeededLocked(provider)
        return (self.cache[provider] ?? [:]).values.contains { $0.count >= minimumSamples }
    }

    /// Drop everything for a provider (tests, debug).
    public func clear(provider: UsageProvider) {
        self.lock.lock()
        self.cache[provider] = [:]
        self.loaded.insert(provider)
        self.lock.unlock()
        guard !self.memoryOnly, let url = self.fileURL(for: provider) else { return }
        self.queue.async { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Disk

    private func loadIfNeededLocked(_ provider: UsageProvider) {
        guard !self.loaded.contains(provider) else { return }
        self.loaded.insert(provider)
        guard !self.memoryOnly, let url = self.fileURL(for: provider),
              let data = try? Data(contentsOf: url), !data.isEmpty else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cutoff = Date().addingTimeInterval(-Self.retention)
        var bySlot: [QuotaWindowSlot: [QuotaSample]] = [:]
        for chunk in data.split(separator: UInt8(ascii: "\n")) where !chunk.isEmpty {
            guard let line = try? decoder.decode(Line.self, from: Data(chunk)) else { continue }
            guard line.sample.at >= cutoff else { continue }
            bySlot[line.slot, default: []].append(line.sample)
        }
        for slot in bySlot.keys {
            bySlot[slot]?.sort { $0.at < $1.at }
        }
        self.cache[provider] = bySlot
    }

    private func fileURL(for provider: UsageProvider) -> URL? {
        self.directory?.appendingPathComponent("\(provider.rawValue).jsonl")
    }

    private static func append(_ line: Line, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard var data = try? encoder.encode(line) else { return }
        data.append(UInt8(ascii: "\n"))
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func rewrite(_ bySlot: [QuotaWindowSlot: [QuotaSample]], to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let cutoff = Date().addingTimeInterval(-Self.retention)
        var out = Data()
        for slot in QuotaWindowSlot.allCases {
            for sample in bySlot[slot] ?? [] where sample.at >= cutoff {
                guard let data = try? encoder.encode(Line(slot: slot, sample: sample)) else { continue }
                out.append(data)
                out.append(UInt8(ascii: "\n"))
            }
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? out.write(to: url, options: .atomic)
    }

    private static func defaultDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Runic/quota-samples", isDirectory: true)
    }
}
