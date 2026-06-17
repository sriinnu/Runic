import Foundation

extension LedgerCache {
    func fileURL(provider: String) -> URL {
        self.cacheDir.appendingPathComponent("\(provider)-daily.json")
    }

    func relayFileURL(provider: String) -> URL {
        self.relayDir.appendingPathComponent("\(provider)-events.jsonl")
    }

    /// Serialize a provider's file mutations across PROCESSES via an advisory
    /// `flock`. The actor already serializes in-process; this guards the upgrade
    /// window where a second build of Runic is also running — without it,
    /// concurrent relay appends can interleave bytes within a line and a
    /// compaction swap can land while another process holds an open handle to the
    /// old inode, dropping that process's just-written records.
    ///
    /// Acquire the lock ONCE around the whole append+compaction (compaction runs
    /// inside the held lock, never re-locks) and once around each daily write, so
    /// it never nests on a second fd (which would self-deadlock under `LOCK_EX`).
    /// Advisory: only processes that also take the lock are serialized — the
    /// upgrade window where an OLD build is still running is not protected (it
    /// never takes the lock); this guards future build-to-build concurrency.
    ///
    /// Acquisition is BOUNDED: `LedgerCache` is an actor, so a blocking `LOCK_EX`
    /// would stall the actor (and any awaiting menu refresh) for as long as
    /// another process holds it — which can be seconds during a large compaction.
    /// Instead we poll `LOCK_EX|LOCK_NB` for ~500ms, then proceed unlocked rather
    /// than freeze the UI. Worst case under contention past the ceiling is the
    /// same interleaving this guards against — rare, and self-healing on read —
    /// which is the right trade for never hanging the menu.
    @discardableResult
    func withProviderFileLock<T>(provider: String, _ body: () throws -> T) rethrows -> T {
        try? FileManager.default.createDirectory(at: self.relayDir, withIntermediateDirectories: true)
        let lockURL = self.relayDir.appendingPathComponent("\(provider).lock")
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return try body() }
        defer { close(fd) }

        var acquired = false
        for _ in 0..<50 { // ~500ms ceiling (50 × 10ms)
            if flock(fd, LOCK_EX | LOCK_NB) == 0 { acquired = true; break }
            if errno != EWOULDBLOCK { break } // a real error, not contention
            usleep(10_000)
        }
        defer { if acquired { _ = flock(fd, LOCK_UN) } }
        return try body()
    }

    func loadCacheFileLedger(provider: String) -> CachedLedger? {
        let url = self.fileURL(provider: provider)
        guard let data = try? Data(contentsOf: url),
              var ledger = try? JSONDecoder().decode(CachedLedger.self, from: data)
        else {
            return nil
        }

        if (ledger.schemaVersion ?? 0) < Self.cacheSchemaVersion {
            ledger.dailies = ledger.dailies.filter {
                Self.isTrustedLegacyDaily(provider: provider, daily: $0)
            }
        }
        return ledger
    }

    func appendRelayRecords(_ records: [UsageRelayRecord]) throws {
        guard !records.isEmpty else { return }

        let url = self.relayFileURL(provider: records[0].provider)
        try FileManager.default.createDirectory(at: self.relayDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var combined = Data()
        for record in records {
            let encoded = try encoder.encode(record)
            var line = encoded
            line.append(0x0A)
            combined.append(line)
        }
        guard !combined.isEmpty else { return }

        let provider = records[0].provider
        try self.withProviderFileLock(provider: provider) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url)
            {
                defer { try? handle.close() }
                _ = try handle.seekToEnd()
                try handle.write(contentsOf: combined)
            } else {
                try combined.write(to: url, options: .atomic)
            }

            // Inside the held lock: a cross-process compaction can't swap the file
            // out from under another writer mid-append.
            self.compactRelayIfNeeded(provider: provider)
        }
    }

    /// The relay is append-only, so every scan leaves the prior day-snapshots
    /// behind even though the reader only ever uses the newest one. Left
    /// unchecked that log grows without bound (a Codex rebuild once drove it past
    /// 500MB). When the file crosses a size cap, rewrite it keeping only the
    /// latest snapshot per day — exactly what `materializedRelayState` already
    /// selects — so disk matches what we actually read.
    func compactRelayIfNeeded(provider: String, maxBytes: Int = 4_000_000) {
        let url = self.relayFileURL(provider: provider)
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > maxBytes
        else {
            return
        }
        self.compactRelay(provider: provider)
    }

    func compactRelay(provider: String) {
        let url = self.relayFileURL(provider: provider)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let lineCap = 512 * 1024

        // Pass 1: find the newest snapshot per day from watermark records. Streamed
        // in constant memory — the file this targets can be hundreds of MB (it
        // exists to clean exactly that), so we never load it whole.
        var latest: [String: UsageRelaySnapshotMarker] = [:]
        var sequence = 0
        do {
            try CostUsageJsonl.scan(fileURL: url, maxLineBytes: lineCap, prefixBytes: lineCap) { line in
                // Gate IDENTICALLY to materialization (same filters, same order)
                // so `sequence` and latest-per-day selection match exactly. If
                // compaction counted/kept a future-schema record the reader skips,
                // it could drop the snapshot the reader would have selected.
                guard !line.wasTruncated, !line.bytes.isEmpty,
                      let record = try? JSONDecoder().decode(UsageRelayRecord.self, from: line.bytes),
                      record.provider == provider,
                      record.schemaVersion <= Self.relaySchemaVersion
                else {
                    return
                }
                sequence += 1
                guard record.recordType == UsageRelayRecordType.watermark.rawValue,
                      let watermark = record.watermark
                else {
                    return
                }
                let marker = UsageRelaySnapshotMarker(
                    snapshotID: watermark.snapshotID,
                    writtenAt: record.writtenAt,
                    sequence: sequence)
                if marker.isNewer(than: latest[watermark.dayKey]) {
                    latest[watermark.dayKey] = marker
                }
            }
        } catch {
            Self.log.warning("Failed to scan relay for compaction for \(provider): \(error.localizedDescription)")
            return
        }
        guard !latest.isEmpty else { return }

        // Pass 2: stream again, copying only the records the reader would ever use
        // (the newest snapshot per day) into a temp file, then swap it in atomically.
        let tempURL = self.relayDir.appendingPathComponent("\(provider)-events.compact.\(UUID().uuidString).jsonl")
        guard FileManager.default.createFile(atPath: tempURL.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: tempURL)
        else {
            try? FileManager.default.removeItem(at: tempURL)
            Self.log.warning("Failed to open temp file for relay compaction for \(provider)")
            return
        }

        var writeError: Error?
        var keptWatermarkDays = Set<String>()
        do {
            try CostUsageJsonl.scan(fileURL: url, maxLineBytes: lineCap, prefixBytes: lineCap) { line in
                guard writeError == nil, !line.wasTruncated, !line.bytes.isEmpty,
                      let record = try? JSONDecoder().decode(UsageRelayRecord.self, from: line.bytes),
                      record.provider == provider,
                      record.schemaVersion <= Self.relaySchemaVersion
                else {
                    return
                }
                let snapshotID: String
                let dayKey: String
                switch record.recordType {
                case UsageRelayRecordType.event.rawValue:
                    guard let event = record.event else { return }
                    snapshotID = event.snapshotID
                    dayKey = event.dayKey
                case UsageRelayRecordType.watermark.rawValue:
                    guard let watermark = record.watermark else { return }
                    snapshotID = watermark.snapshotID
                    dayKey = watermark.dayKey
                default:
                    return
                }
                guard latest[dayKey]?.snapshotID == snapshotID else { return }
                // One watermark per day is enough to mark the latest snapshot, so
                // drop the rest — this is what shrinks a relay already bloated with
                // per-file watermarks (events, one per day, are always kept).
                if record.recordType == UsageRelayRecordType.watermark.rawValue {
                    guard keptWatermarkDays.insert(dayKey).inserted else { return }
                }
                var out = line.bytes
                out.append(0x0A)
                do { try handle.write(contentsOf: out) } catch { writeError = error }
            }
        } catch {
            writeError = error
        }
        try? handle.close()

        if let writeError {
            try? FileManager.default.removeItem(at: tempURL)
            Self.log.warning("Failed to write compacted relay for \(provider): \(writeError.localizedDescription)")
            return
        }

        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            Self.log.warning("Failed to swap compacted relay for \(provider): \(error.localizedDescription)")
        }
    }
}
