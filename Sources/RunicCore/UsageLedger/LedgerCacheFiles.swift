import Foundation

extension LedgerCache {
    func fileURL(provider: String) -> URL {
        self.cacheDir.appendingPathComponent("\(provider)-daily.json")
    }

    func relayFileURL(provider: String) -> URL {
        self.relayDir.appendingPathComponent("\(provider)-events.jsonl")
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

        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url)
        {
            defer { try? handle.close() }
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: combined)
        } else {
            try combined.write(to: url, options: .atomic)
        }

        self.compactRelayIfNeeded(provider: records[0].provider)
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
                guard !line.wasTruncated, !line.bytes.isEmpty,
                      let record = try? JSONDecoder().decode(UsageRelayRecord.self, from: line.bytes),
                      record.provider == provider
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
        do {
            try CostUsageJsonl.scan(fileURL: url, maxLineBytes: lineCap, prefixBytes: lineCap) { line in
                guard writeError == nil, !line.wasTruncated, !line.bytes.isEmpty,
                      let record = try? JSONDecoder().decode(UsageRelayRecord.self, from: line.bytes),
                      record.provider == provider
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
