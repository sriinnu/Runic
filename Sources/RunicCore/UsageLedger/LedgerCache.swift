import Foundation
import OSLog

/// Persistent cache for aggregated ledger data. Stores daily summaries per provider
/// so the app does not need to re-scan old JSONL files on every refresh.
/// Normal menu refreshes treat existing historical days as frozen and replace
/// only today's aggregate; explicit full scans can still rebuild old days.
///
/// Storage:
///   - `~/Library/Application Support/Runic/ledger-cache/{provider}-daily.json`
///   - `~/Library/Application Support/Runic/relay/{provider}-events.jsonl`
///
/// The JSON cache is a materialized view. The relay JSONL is Runic-owned
/// normalized event memory with scan watermarks, so provider JSONLs only need
/// to be read for today's live deltas.
public actor LedgerCache {
    public static let shared = LedgerCache()

    private static let cacheSchemaVersion = 3
    private static let relaySchemaVersion = 3
    private static let maxTrustedLegacyDailyTokens = 100_000_000
    private static let maxTrustedLegacyDailyRequests = 50_000
    private static let log = Logger(subsystem: "com.sriinnu.athena.Runic", category: "ledger-cache")
    private let cacheDir: URL
    private let relayDir: URL
    private let legacyCostCacheRoot: URL?

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    public init(cacheDir: URL? = nil, relayDir: URL? = nil, legacyCostCacheRoot: URL? = nil) {
        if let cacheDir {
            self.legacyCostCacheRoot = legacyCostCacheRoot
                ?? cacheDir.appendingPathComponent("legacy-cost-cache", isDirectory: true)
            self.cacheDir = cacheDir
            self.relayDir = relayDir ?? cacheDir.appendingPathComponent("relay", isDirectory: true)
        } else {
            self.legacyCostCacheRoot = legacyCostCacheRoot
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let runicRoot = appSupport.appendingPathComponent("Runic", isDirectory: true)
            self.cacheDir = runicRoot.appendingPathComponent("ledger-cache", isDirectory: true)
            self.relayDir = relayDir ?? runicRoot.appendingPathComponent("relay", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: self.relayDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Load cached daily summaries for a provider. Returns instantly.
    public func loadCachedDailies(provider: String) -> CachedLedger? {
        let url = self.fileURL(provider: provider)
        let decoded: CachedLedger? = if let data = try? Data(contentsOf: url) {
            try? JSONDecoder().decode(CachedLedger.self, from: data)
        } else {
            nil
        }

        let relayState = self.materializedRelayState(provider: provider)
        guard decoded != nil || !relayState.touchedDayKeys.isEmpty else { return nil }

        var ledger = decoded ?? CachedLedger(
            lastScanDate: .distantPast,
            lastFullScanDate: nil,
            coveredMaxAgeDays: nil,
            dailies: [])

        if (ledger.schemaVersion ?? 0) < Self.cacheSchemaVersion {
            ledger.dailies = ledger.dailies.filter {
                Self.isTrustedLegacyDaily(provider: provider, daily: $0)
            }
        }

        if !relayState.touchedDayKeys.isEmpty {
            var byDay = Dictionary(uniqueKeysWithValues: ledger.dailies.map { ($0.dayKey, $0) })
            for dayKey in relayState.touchedDayKeys {
                byDay.removeValue(forKey: dayKey)
            }
            for daily in relayState.dailies {
                byDay[daily.dayKey] = daily
            }
            ledger.dailies = byDay.values.sorted { $0.dayKey < $1.dayKey }
        }

        return ledger
    }

    /// Save aggregated daily summaries for a provider.
    public func saveDailies(provider: String, ledger: CachedLedger) {
        let url = self.fileURL(provider: provider)
        var versionedLedger = ledger
        versionedLedger.schemaVersion = Self.cacheSchemaVersion
        guard let data = try? JSONEncoder().encode(versionedLedger) else { return }
        try? data.write(to: url, options: .atomic)
        Self.log.debug("Saved \(ledger.dailies.count) days for \(provider)")
    }

    /// Merge hot daily entries into the frozen daily cache.
    ///
    /// When `todayKey` is supplied, existing days before today are immutable:
    /// this is the fast relay path used by menu refreshes. Passing `nil`
    /// preserves full-rebuild behavior for tests and future backfill tools.
    public func mergeDailies(
        provider: String,
        newDailies: [CachedDaily],
        scanDate: Date,
        todayKey: String? = nil,
        coveredMaxAgeDays: Int? = nil)
    {
        var ledger = self.loadCachedDailies(provider: provider) ?? CachedLedger(
            lastScanDate: scanDate,
            lastFullScanDate: nil,
            coveredMaxAgeDays: nil,
            dailies: [])

        var existingByKey: [String: CachedDaily] = [:]
        for daily in ledger.dailies {
            existingByKey[daily.dayKey] = daily
        }

        for newDaily in newDailies {
            if let todayKey,
               newDaily.dayKey != todayKey,
               existingByKey[newDaily.dayKey] != nil
            {
                continue
            }
            existingByKey[newDaily.dayKey] = newDaily
        }

        ledger.dailies = existingByKey.values.sorted { $0.dayKey < $1.dayKey }
        self.updateScanMetadata(&ledger, scanDate: scanDate, coveredMaxAgeDays: coveredMaxAgeDays)
        self.archiveDailySummariesAsRelayEvents(
            provider: provider,
            dailies: todayKey.map { key in ledger.dailies.filter { $0.dayKey < key } } ?? ledger.dailies,
            writtenAt: scanDate)
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Merge normalized usage events into the relay and refresh the daily materialized view.
    public func mergeEntries(
        provider: String,
        entries: [UsageLedgerEntry],
        scanDate: Date,
        todayKey: String? = nil,
        coveredMaxAgeDays: Int? = nil,
        sourceWatermarks: [UsageRelaySourceWatermark] = [])
    {
        self.seedRelayFromLegacyCacheIfNeeded(provider: provider, todayKey: todayKey, writtenAt: scanDate)
        guard self.archiveEntriesAsRelayEvents(
            provider: provider,
            entries: entries,
            scanDate: scanDate,
            todayKey: todayKey,
            sourceWatermarks: sourceWatermarks)
        else {
            return
        }

        var ledger = self.loadCacheFileLedger(provider: provider) ?? CachedLedger(
            lastScanDate: scanDate,
            lastFullScanDate: nil,
            coveredMaxAgeDays: nil,
            dailies: [])
        let relayState = self.materializedRelayState(provider: provider)
        var existingByKey = Dictionary(uniqueKeysWithValues: ledger.dailies.map { ($0.dayKey, $0) })
        let touchedDayKeys = relayState.touchedDayKeys.union(Self.touchedDayKeys(
            entries: entries,
            todayKey: todayKey,
            sourceWatermarks: sourceWatermarks))
        for dayKey in touchedDayKeys {
            existingByKey.removeValue(forKey: dayKey)
        }
        for daily in relayState.dailies {
            existingByKey[daily.dayKey] = daily
        }
        ledger.dailies = existingByKey.values.sorted { $0.dayKey < $1.dayKey }
        self.updateScanMetadata(&ledger, scanDate: scanDate, coveredMaxAgeDays: coveredMaxAgeDays)
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Seed the event relay from legacy daily/cache stores without marking new coverage.
    public func migrateLegacyRelaySeedsIfNeeded(provider: String, scanDate: Date, todayKey: String? = nil) {
        self.seedRelayFromLegacyCacheIfNeeded(provider: provider, todayKey: todayKey, writtenAt: scanDate)
    }

    /// Record that a provider was scanned even if it produced no new entries.
    public func markScanComplete(
        provider: String,
        scanDate: Date,
        coveredMaxAgeDays: Int? = nil,
        todayKey: String? = nil)
    {
        var ledger = self.loadCachedDailies(provider: provider) ?? CachedLedger(
            lastScanDate: scanDate,
            lastFullScanDate: nil,
            coveredMaxAgeDays: nil,
            dailies: [])
        self.updateScanMetadata(&ledger, scanDate: scanDate, coveredMaxAgeDays: coveredMaxAgeDays)
        self.seedRelayFromLegacyCacheIfNeeded(provider: provider, todayKey: todayKey, writtenAt: scanDate)
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Mark that a full historical scan has been completed.
    public func markFullScanComplete(provider: String) {
        guard var ledger = self.loadCachedDailies(provider: provider) else { return }
        ledger.lastFullScanDate = Date()
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Whether a full historical scan has been done for this provider.
    public func hasFullScan(provider: String) -> Bool {
        self.loadCachedDailies(provider: provider)?.lastFullScanDate != nil
    }

    /// Date of last incremental scan (to know which files to scan next).
    public func lastScanDate(provider: String) -> Date? {
        self.loadCachedDailies(provider: provider)?.lastScanDate
    }

    /// Largest bounded history window that has already been scanned.
    public func coveredMaxAgeDays(provider: String) -> Int? {
        self.loadCachedDailies(provider: provider)?.coveredMaxAgeDays
    }

    /// Best available coverage for old and new cache files.
    ///
    /// Older cache files do not have `coveredMaxAgeDays`; using their cached
    /// day count avoids one expensive post-upgrade rescan for established users.
    public func effectiveCoveredMaxAgeDays(provider: String) -> Int? {
        guard let ledger = self.loadCachedDailies(provider: provider) else { return nil }
        let covered = max(ledger.coveredMaxAgeDays ?? 0, ledger.dailies.count)
        return covered > 0 ? covered : nil
    }

    /// Location of Runic's append-only relay history for diagnostics/tests.
    public func relayHistoryFileURL(provider: String) -> URL {
        self.relayFileURL(provider: provider)
    }

    // MARK: - Internal

    private func fileURL(provider: String) -> URL {
        self.cacheDir.appendingPathComponent("\(provider)-daily.json")
    }

    private func relayFileURL(provider: String) -> URL {
        self.relayDir.appendingPathComponent("\(provider)-events.jsonl")
    }

    private func loadCacheFileLedger(provider: String) -> CachedLedger? {
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

    private func seedRelayFromLegacyCacheIfNeeded(provider: String, todayKey: String?, writtenAt: Date) {
        var seededDayKeys = self.materializedRelayState(provider: provider).touchedDayKeys

        if let ledger = self.loadCacheFileLedger(provider: provider) {
            let seedDailies = ledger.dailies.filter { daily in
                if seededDayKeys.contains(daily.dayKey) { return false }
                if let todayKey {
                    return daily.dayKey < todayKey
                }
                return true
            }
            if self.archiveDailySummariesAsRelayEvents(provider: provider, dailies: seedDailies, writtenAt: writtenAt) {
                seededDayKeys.formUnion(seedDailies.map(\.dayKey))
            }
        }

        guard let usageProvider = UsageProvider(rawValue: provider) else { return }
        let legacyCostDailies = self.dailiesFromLegacyCostUsageCache(provider: usageProvider)
        let seedCostDailies = legacyCostDailies.filter { daily in
            if seededDayKeys.contains(daily.dayKey) { return false }
            if let todayKey {
                return daily.dayKey < todayKey
            }
            return true
        }
        _ = self.archiveDailySummariesAsRelayEvents(provider: provider, dailies: seedCostDailies, writtenAt: writtenAt)
    }

    private func materializedRelayState(provider: String) -> UsageRelayMaterializedState {
        let url = self.relayFileURL(provider: provider)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return UsageRelayMaterializedState(dailies: [], touchedDayKeys: [])
        }

        var eventsByDaySnapshot: [String: [String: [String: UsageRelayEvent]]] = [:]
        var latestSnapshotByDay: [String: UsageRelaySnapshotMarker] = [:]
        var sequence = 0

        do {
            try CostUsageJsonl.scan(
                fileURL: url,
                maxLineBytes: 512 * 1024,
                prefixBytes: 512 * 1024)
            { line in
                guard !line.wasTruncated, !line.bytes.isEmpty else { return }
                guard
                    let record = try? JSONDecoder().decode(UsageRelayRecord.self, from: line.bytes),
                    record.provider == provider,
                    record.schemaVersion >= Self.relaySchemaVersion
                else {
                    return
                }

                sequence += 1
                switch record.recordType {
                case UsageRelayRecordType.event.rawValue:
                    guard let event = record.event else { return }
                    var snapshots = eventsByDaySnapshot[event.dayKey] ?? [:]
                    var snapshotEvents = snapshots[event.snapshotID] ?? [:]
                    snapshotEvents[event.eventID] = event
                    snapshots[event.snapshotID] = snapshotEvents
                    eventsByDaySnapshot[event.dayKey] = snapshots
                case UsageRelayRecordType.watermark.rawValue:
                    guard let watermark = record.watermark else { return }
                    let marker = UsageRelaySnapshotMarker(
                        snapshotID: watermark.snapshotID,
                        writtenAt: record.writtenAt,
                        sequence: sequence)
                    if marker.isNewer(than: latestSnapshotByDay[watermark.dayKey]) {
                        latestSnapshotByDay[watermark.dayKey] = marker
                    }
                default:
                    return
                }
            }
        } catch {
            Self.log.warning("Failed to read relay history for \(provider): \(error.localizedDescription)")
        }

        let selectedByDay = latestSnapshotByDay
        let dailies = selectedByDay.compactMap { dayKey, marker -> CachedDaily? in
            guard let events = eventsByDaySnapshot[dayKey]?[marker.snapshotID]?.values, !events.isEmpty else {
                return nil
            }
            var input = 0
            var output = 0
            var cacheCreation = 0
            var cacheRead = 0
            var cost = 0.0
            var hasCost = false
            var requests = 0
            var models = Set<String>()

            for event in events {
                input += event.inputTokens
                output += event.outputTokens
                cacheCreation += event.cacheCreationTokens
                cacheRead += event.cacheReadTokens
                requests += event.requestCount ?? 1
                if let eventCost = event.costUSD {
                    cost += eventCost
                    hasCost = true
                }
                if let modelsUsed = event.modelsUsed {
                    models.formUnion(modelsUsed)
                } else if let model = event.model {
                    models.insert(model)
                }
            }

            let daily = CachedDaily(
                dayKey: dayKey,
                inputTokens: input,
                outputTokens: output,
                cacheCreationTokens: cacheCreation,
                cacheReadTokens: cacheRead,
                costUSD: hasCost ? cost : nil,
                requestCount: requests,
                modelsUsed: models.sorted())
            guard Self.isTrustedLegacyDaily(provider: provider, daily: daily) else { return nil }
            return daily
        }
        .sorted { $0.dayKey < $1.dayKey }

        return UsageRelayMaterializedState(
            dailies: dailies,
            touchedDayKeys: Set(selectedByDay.keys))
    }

    @discardableResult
    private func archiveDailySummariesAsRelayEvents(provider: String, dailies: [CachedDaily], writtenAt: Date) -> Bool {
        let records = dailies
            .sorted { $0.dayKey < $1.dayKey }
            .flatMap { daily -> [UsageRelayRecord] in
                let snapshotID = self.snapshotID(provider: provider, dayKey: daily.dayKey, writtenAt: writtenAt)
                let sourceFingerprint = "daily-summary:\(provider):\(daily.dayKey)"
                let event = UsageRelayEvent(
                    eventID: "daily-summary:\(provider):\(daily.dayKey)",
                    snapshotID: snapshotID,
                    provider: provider,
                    timestamp: Self.dayKeyFormatter.date(from: daily.dayKey) ?? writtenAt,
                    dayKey: daily.dayKey,
                    sessionID: nil,
                    projectID: nil,
                    projectName: nil,
                    model: daily.modelsUsed.count == 1 ? daily.modelsUsed.first : nil,
                    modelsUsed: daily.modelsUsed,
                    inputTokens: daily.inputTokens,
                    outputTokens: daily.outputTokens,
                    cacheCreationTokens: daily.cacheCreationTokens,
                    cacheReadTokens: daily.cacheReadTokens,
                    costUSD: daily.costUSD,
                    requestCount: daily.requestCount,
                    requestID: nil,
                    messageID: nil,
                    version: nil,
                    source: "relay-daily-summary",
                    operationKind: nil,
                    tokenProvenance: nil,
                    costProvenance: nil,
                    sourceFingerprint: sourceFingerprint)
                let watermark = UsageRelayWatermark(
                    snapshotID: snapshotID,
                    dayKey: daily.dayKey,
                    sourceKind: "daily-summary",
                    sourceID: "cache:\(provider):\(daily.dayKey)",
                    sourceFingerprint: sourceFingerprint,
                    path: nil,
                    modifiedAt: nil,
                    sizeBytes: nil,
                    scannedAt: writtenAt)
                return [
                    UsageRelayRecord(
                        schemaVersion: Self.relaySchemaVersion,
                        recordType: UsageRelayRecordType.event.rawValue,
                        provider: provider,
                        writtenAt: writtenAt,
                        event: event,
                        watermark: nil),
                    UsageRelayRecord(
                        schemaVersion: Self.relaySchemaVersion,
                        recordType: UsageRelayRecordType.watermark.rawValue,
                        provider: provider,
                        writtenAt: writtenAt,
                        event: nil,
                        watermark: watermark),
                ]
            }
        do {
            try self.appendRelayRecords(records)
            return true
        } catch {
            Self.log.warning("Failed to append relay summary records for \(provider): \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    private func archiveEntriesAsRelayEvents(
        provider: String,
        entries: [UsageLedgerEntry],
        scanDate: Date,
        todayKey: String?,
        sourceWatermarks: [UsageRelaySourceWatermark])
        -> Bool
    {
        let dayKeys = Self.touchedDayKeys(entries: entries, todayKey: todayKey, sourceWatermarks: sourceWatermarks)
        guard !dayKeys.isEmpty else { return true }

        var records: [UsageRelayRecord] = []
        for dayKey in dayKeys.sorted() {
            let snapshotID = self.snapshotID(provider: provider, dayKey: dayKey, writtenAt: scanDate)
            let dayEntries = entries
                .enumerated()
                .filter { Self.dayKey(for: $0.element.timestamp) == dayKey }
            for (index, entry) in dayEntries {
                let event = UsageRelayEvent(
                    eventID: self.eventID(for: entry, dayKey: dayKey, index: index),
                    snapshotID: snapshotID,
                    provider: provider,
                    timestamp: entry.timestamp,
                    dayKey: dayKey,
                    sessionID: entry.sessionID,
                    projectID: entry.projectID,
                    projectName: entry.projectName,
                    model: entry.model,
                    modelsUsed: nil,
                    inputTokens: entry.inputTokens,
                    outputTokens: entry.outputTokens,
                    cacheCreationTokens: entry.cacheCreationTokens,
                    cacheReadTokens: entry.cacheReadTokens,
                    costUSD: entry.costUSD,
                    requestCount: nil,
                    requestID: entry.requestID,
                    messageID: entry.messageID,
                    version: entry.version,
                    source: entry.source.rawValue,
                    operationKind: entry.operationKind?.rawValue,
                    tokenProvenance: entry.tokenProvenance,
                    costProvenance: entry.costProvenance,
                    sourceFingerprint: entry.sourceFingerprint)
                records.append(UsageRelayRecord(
                    schemaVersion: Self.relaySchemaVersion,
                    recordType: UsageRelayRecordType.event.rawValue,
                    provider: provider,
                    writtenAt: scanDate,
                    event: event,
                    watermark: nil))
            }

            let matchingWatermarks = sourceWatermarks.filter { watermark in
                watermark.dayKey == nil || watermark.dayKey == dayKey
            }
            if matchingWatermarks.isEmpty {
                records.append(UsageRelayRecord(
                    schemaVersion: Self.relaySchemaVersion,
                    recordType: UsageRelayRecordType.watermark.rawValue,
                    provider: provider,
                    writtenAt: scanDate,
                    event: nil,
                    watermark: UsageRelayWatermark(
                        snapshotID: snapshotID,
                        dayKey: dayKey,
                        sourceKind: "scan",
                        sourceID: "scan:\(provider):\(dayKey)",
                        sourceFingerprint: "scan:\(provider):\(dayKey):\(scanDate.timeIntervalSince1970)",
                        path: nil,
                        modifiedAt: nil,
                        sizeBytes: nil,
                        scannedAt: scanDate)))
            } else {
                for sourceWatermark in matchingWatermarks {
                    records.append(UsageRelayRecord(
                        schemaVersion: Self.relaySchemaVersion,
                        recordType: UsageRelayRecordType.watermark.rawValue,
                        provider: provider,
                        writtenAt: scanDate,
                        event: nil,
                        watermark: UsageRelayWatermark(
                            snapshotID: snapshotID,
                            dayKey: dayKey,
                            sourceKind: sourceWatermark.sourceKind,
                            sourceID: sourceWatermark.sourceID,
                            sourceFingerprint: sourceWatermark.sourceFingerprint,
                            path: sourceWatermark.path,
                            modifiedAt: sourceWatermark.modifiedAt,
                            sizeBytes: sourceWatermark.sizeBytes,
                            scannedAt: scanDate)))
                }
            }
        }

        do {
            try self.appendRelayRecords(records)
            return true
        } catch {
            Self.log.warning("Failed to append relay event records for \(provider): \(error.localizedDescription)")
            return false
        }
    }

    private func appendRelayRecords(_ records: [UsageRelayRecord]) throws {
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

    private func snapshotID(provider: String, dayKey: String, writtenAt: Date) -> String {
        "snapshot:\(provider):\(dayKey):\(Int(writtenAt.timeIntervalSince1970 * 1000)):\(UUID().uuidString)"
    }

    private func eventID(for entry: UsageLedgerEntry, dayKey: String, index: Int) -> String {
        if let requestID = entry.requestID, !requestID.isEmpty {
            return "\(entry.source.rawValue):request:\(requestID)"
        }
        if let messageID = entry.messageID, !messageID.isEmpty {
            return "\(entry.source.rawValue):message:\(messageID)"
        }
        let timestampMillis = Int(entry.timestamp.timeIntervalSince1970 * 1000)
        return [
            entry.source.rawValue,
            dayKey,
            entry.sessionID ?? "-",
            "\(timestampMillis)",
            "\(entry.inputTokens)",
            "\(entry.outputTokens)",
            "\(entry.cacheCreationTokens)",
            "\(entry.cacheReadTokens)",
            "\(index)",
        ].joined(separator: ":")
    }

    private static func touchedDayKeys(
        entries: [UsageLedgerEntry],
        todayKey: String?,
        sourceWatermarks: [UsageRelaySourceWatermark])
        -> Set<String>
    {
        var dayKeys = Set(entries.map { Self.dayKey(for: $0.timestamp) })
        dayKeys.formUnion(sourceWatermarks.compactMap(\.dayKey))
        if dayKeys.isEmpty, let todayKey {
            dayKeys.insert(todayKey)
        }
        return dayKeys
    }

    private func dailiesFromLegacyCostUsageCache(provider: UsageProvider) -> [CachedDaily] {
        let cache = CostUsageCacheIO.load(provider: provider, cacheRoot: self.legacyCostCacheRoot)
        return cache.days.keys.sorted().compactMap { dayKey in
            guard let models = cache.days[dayKey], !models.isEmpty else { return nil }
            guard let daily = Self.dailyFromLegacyCostUsageModels(provider: provider, dayKey: dayKey, models: models)
            else {
                return nil
            }
            guard Self.isTrustedLegacyDaily(provider: provider.rawValue, daily: daily) else { return nil }
            return daily
        }
    }

    private static func dailyFromLegacyCostUsageModels(
        provider: UsageProvider,
        dayKey: String,
        models: [String: [Int]])
        -> CachedDaily?
    {
        var input = 0
        var output = 0
        var cacheRead = 0
        var cacheCreate = 0
        var cost = 0.0
        var hasCost = false
        let modelNames = models.keys.sorted()

        for model in modelNames {
            let packed = models[model] ?? []
            switch provider {
            case .codex:
                let modelInput = packed[safe: 0] ?? 0
                let modelCacheRead = packed[safe: 1] ?? 0
                let modelOutput = packed[safe: 2] ?? 0
                input += modelInput
                cacheRead += modelCacheRead
                output += modelOutput
                if let modelCost = CostUsagePricing.codexCostUSD(
                    model: model,
                    inputTokens: modelInput,
                    cachedInputTokens: modelCacheRead,
                    outputTokens: modelOutput)
                {
                    cost += modelCost
                    hasCost = true
                }
            case .claude:
                let modelInput = packed[safe: 0] ?? 0
                let modelCacheRead = packed[safe: 1] ?? 0
                let modelCacheCreate = packed[safe: 2] ?? 0
                let modelOutput = packed[safe: 3] ?? 0
                let costNanos = packed[safe: 4] ?? 0
                input += modelInput
                cacheRead += modelCacheRead
                cacheCreate += modelCacheCreate
                output += modelOutput
                let modelCost = costNanos > 0
                    ? Double(costNanos) / 1_000_000_000.0
                    : CostUsagePricing.claudeCostUSD(
                        model: model,
                        inputTokens: modelInput,
                        cacheReadInputTokens: modelCacheRead,
                        cacheCreationInputTokens: modelCacheCreate,
                        outputTokens: modelOutput)
                if let modelCost {
                    cost += modelCost
                    hasCost = true
                }
            default:
                continue
            }
        }

        let totalTokens = input + output + cacheRead + cacheCreate
        guard totalTokens > 0 || hasCost else { return nil }
        return CachedDaily(
            dayKey: dayKey,
            inputTokens: input,
            outputTokens: output,
            cacheCreationTokens: cacheCreate,
            cacheReadTokens: cacheRead,
            costUSD: hasCost ? cost : nil,
            requestCount: max(1, modelNames.count),
            modelsUsed: modelNames)
    }

    private static func isTrustedLegacyDaily(provider: String, daily: CachedDaily) -> Bool {
        guard provider == "codex" || provider == "claude" else { return true }
        if daily.totalTokens > Self.maxTrustedLegacyDailyTokens { return false }
        if daily.requestCount > Self.maxTrustedLegacyDailyRequests { return false }
        return true
    }

    private func updateScanMetadata(
        _ ledger: inout CachedLedger,
        scanDate: Date,
        coveredMaxAgeDays: Int?)
    {
        ledger.lastScanDate = scanDate
        if let coveredMaxAgeDays {
            ledger.coveredMaxAgeDays = max(ledger.coveredMaxAgeDays ?? 0, coveredMaxAgeDays)
            ledger.lastFullScanDate = scanDate
        }
    }

    public static func dayKey(for date: Date) -> String {
        self.dayKeyFormatter.string(from: date)
    }
}

// MARK: - Models

public struct CachedLedger: Codable, Sendable {
    public var schemaVersion: Int?
    public var lastScanDate: Date
    public var lastFullScanDate: Date?
    public var coveredMaxAgeDays: Int?
    public var dailies: [CachedDaily]

    public init(
        schemaVersion: Int? = nil,
        lastScanDate: Date,
        lastFullScanDate: Date?,
        coveredMaxAgeDays: Int? = nil,
        dailies: [CachedDaily])
    {
        self.schemaVersion = schemaVersion
        self.lastScanDate = lastScanDate
        self.lastFullScanDate = lastFullScanDate
        self.coveredMaxAgeDays = coveredMaxAgeDays
        self.dailies = dailies
    }
}

public struct CachedDaily: Codable, Sendable {
    public let dayKey: String // "2026-03-23"
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let costUSD: Double?
    public let requestCount: Int
    public let modelsUsed: [String]

    private static let dayKeyParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    public init(
        dayKey: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double?,
        requestCount: Int,
        modelsUsed: [String])
    {
        self.dayKey = dayKey
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
        self.requestCount = requestCount
        self.modelsUsed = modelsUsed
    }

    public var totalTokens: Int {
        self.inputTokens + self.outputTokens + self.cacheCreationTokens + self.cacheReadTokens
    }

    /// Convert to a UsageLedgerDailySummary for immediate display from cache.
    public func toLedgerDailySummary(provider: UsageProvider) -> UsageLedgerDailySummary? {
        guard let dayStart = Self.dayKeyParser.date(from: self.dayKey) else { return nil }
        return UsageLedgerDailySummary(
            provider: provider,
            projectID: nil,
            dayStart: dayStart,
            dayKey: self.dayKey,
            totals: UsageLedgerTotals(
                inputTokens: self.inputTokens,
                outputTokens: self.outputTokens,
                cacheCreationTokens: self.cacheCreationTokens,
                cacheReadTokens: self.cacheReadTokens,
                costUSD: self.costUSD),
            modelsUsed: self.modelsUsed)
    }
}

public struct UsageRelaySourceWatermark: Codable, Sendable, Hashable {
    public let dayKey: String?
    public let sourceKind: String
    public let sourceID: String
    public let sourceFingerprint: String
    public let path: String?
    public let modifiedAt: Date?
    public let sizeBytes: Int64?

    public init(
        dayKey: String? = nil,
        sourceKind: String,
        sourceID: String,
        sourceFingerprint: String,
        path: String? = nil,
        modifiedAt: Date? = nil,
        sizeBytes: Int64? = nil)
    {
        self.dayKey = dayKey
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.sourceFingerprint = sourceFingerprint
        self.path = path
        self.modifiedAt = modifiedAt
        self.sizeBytes = sizeBytes
    }
}

private enum UsageRelayRecordType: String {
    case event
    case watermark
}

private struct UsageRelayRecord: Codable, Sendable {
    let schemaVersion: Int
    let recordType: String
    let provider: String
    let writtenAt: Date
    let event: UsageRelayEvent?
    let watermark: UsageRelayWatermark?
}

private struct UsageRelayEvent: Codable, Sendable {
    let eventID: String
    let snapshotID: String
    let provider: String
    let timestamp: Date
    let dayKey: String
    let sessionID: String?
    let projectID: String?
    let projectName: String?
    let model: String?
    let modelsUsed: [String]?
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let costUSD: Double?
    let requestCount: Int?
    let requestID: String?
    let messageID: String?
    let version: String?
    let source: String
    let operationKind: String?
    let tokenProvenance: MetricProvenance?
    let costProvenance: MetricProvenance?
    let sourceFingerprint: String?
}

private struct UsageRelayWatermark: Codable, Sendable {
    let snapshotID: String
    let dayKey: String
    let sourceKind: String
    let sourceID: String
    let sourceFingerprint: String
    let path: String?
    let modifiedAt: Date?
    let sizeBytes: Int64?
    let scannedAt: Date
}

private struct UsageRelayMaterializedState {
    let dailies: [CachedDaily]
    let touchedDayKeys: Set<String>
}

private struct UsageRelaySnapshotMarker {
    let snapshotID: String
    let writtenAt: Date
    let sequence: Int

    func isNewer(than other: UsageRelaySnapshotMarker?) -> Bool {
        guard let other else { return true }
        if self.writtenAt != other.writtenAt {
            return self.writtenAt > other.writtenAt
        }
        return self.sequence > other.sequence
    }
}
