import Foundation

/// In-process, per-file resume state for the ledger log scanners.
///
/// A live Codex rollout (or Claude project JSONL) is append-only and can grow
/// to multiple GB; before this cache every 90s refresh re-read such files from
/// byte 0. The scanners now remember, per file, how far they safely read
/// (`resumeOffset` — always at a newline boundary), a fingerprint of the file
/// prefix to detect rotation/rewrites, and the entries already parsed for the
/// active scan window so a resumed scan can still hand the aggregator the
/// FULL window (replace-semantics day aggregates require partial-day counts to
/// be carried forward, not just the tail).
///
/// v1 scope: state lives only for this process's lifetime (that alone removes
/// the repeated GB re-reads on the refresh cycle). Cross-launch persistence is
/// future work — the first scan after launch still reads from byte 0.
///
/// Safety rules enforced by callers via `resumableState(...)`:
/// - fingerprint mismatch (rotation/rewrite) → full re-read
/// - file shrank below the resume offset (truncation) → full re-read
/// - scan window reaches further back than the cached window → full re-read
public final class LedgerScanResumeStore: @unchecked Sendable {
    public static let shared = LedgerScanResumeStore()

    /// Cumulative-counter cursor for the Codex legacy `total_token_usage`
    /// delta path, plus the streamed turn context, so a resumed scan continues
    /// mid-file exactly where the previous read stopped.
    struct CodexCursor {
        let currentModel: String?
        let currentProjectID: String?
        let currentProjectName: String?
        let previousTotalsInput: Int?
        let previousTotalsCached: Int?
        let previousTotalsOutput: Int?
    }

    struct FileState {
        /// FNV-1a hash of the first `fingerprintLength` bytes of the file.
        let fingerprint: UInt64
        let fingerprintLength: Int
        /// File size observed at the end of the last successful scan.
        let sizeBytes: Int64
        /// Offset just past the last newline-terminated line already parsed.
        let resumeOffset: Int64
        /// Scan window lower bound the cached entries were parsed with.
        let minDate: Date?
        /// Entries already parsed from this file within `minDate`'s window.
        let entries: [UsageLedgerEntry]
        let codexCursor: CodexCursor?
    }

    private let lock = NSLock()
    private var states: [String: FileState] = [:]
    private var accessOrder: [String] = []
    private let maxFiles: Int
    /// Files whose window yields more entries than this are not worth holding
    /// in memory between scans; they fall back to full re-reads.
    static let maxCachedEntriesPerFile = 200_000

    public init(maxFiles: Int = 256) {
        self.maxFiles = max(1, maxFiles)
    }

    /// Testing/diagnostics: drop all cached scan state.
    public func reset() {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.states.removeAll()
        self.accessOrder.removeAll()
    }

    func state(forKey key: String) -> FileState? {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard let state = self.states[key] else { return nil }
        self.touch(key)
        return state
    }

    func setState(_ state: FileState, forKey key: String) {
        guard state.entries.count <= Self.maxCachedEntriesPerFile else {
            self.removeState(forKey: key)
            return
        }
        self.lock.lock()
        defer { self.lock.unlock() }
        self.states[key] = state
        self.touch(key)
        while self.accessOrder.count > self.maxFiles, let oldest = self.accessOrder.first {
            self.accessOrder.removeFirst()
            self.states.removeValue(forKey: oldest)
        }
    }

    func removeState(forKey key: String) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.states.removeValue(forKey: key)
        if let index = self.accessOrder.firstIndex(of: key) {
            self.accessOrder.remove(at: index)
        }
    }

    private func touch(_ key: String) {
        if let index = self.accessOrder.firstIndex(of: key) {
            self.accessOrder.remove(at: index)
        }
        self.accessOrder.append(key)
    }

    // MARK: - Resume validation

    /// Returns the prior state iff it is safe to resume this file from
    /// `resumeOffset`; otherwise drops the stale state and returns nil.
    func resumableState(
        forKey key: String,
        url: URL,
        currentSizeBytes: Int64?,
        minDate: Date?) -> FileState?
    {
        guard let prior = self.state(forKey: key) else { return nil }
        guard let currentSizeBytes,
              currentSizeBytes >= prior.resumeOffset,
              Self.isWindowCompatible(priorMinDate: prior.minDate, minDate: minDate),
              let current = Self.prefixFingerprint(url: url, length: prior.fingerprintLength),
              current.length == prior.fingerprintLength,
              current.hash == prior.fingerprint
        else {
            self.removeState(forKey: key)
            return nil
        }
        return prior
    }

    /// A cached window can serve a scan that starts at the same point or LATER
    /// (entries are filtered down); a scan reaching further back must re-read.
    static func isWindowCompatible(priorMinDate: Date?, minDate: Date?) -> Bool {
        guard let priorMinDate else { return true }
        guard let minDate else { return false }
        return priorMinDate <= minDate
    }

    /// FNV-1a over the first `length` bytes of the file. Cheap (≤1KB read) and
    /// good enough to detect a rotated/rewritten file reusing the same path.
    static func prefixFingerprint(url: URL, length: Int = 1024) -> (hash: UInt64, length: Int)? {
        guard length > 0, let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: length), !data.isEmpty else { return nil }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in data {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        return (hash, data.count)
    }
}
