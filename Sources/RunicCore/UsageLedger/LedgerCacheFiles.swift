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
    }
}
