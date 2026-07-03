import Foundation
import OSLog

extension LedgerCache {
    @discardableResult
    func archiveDailySummariesAsRelayEvents(provider: String, dailies: [CachedDaily], writtenAt: Date) -> Bool {
        let records = dailies
            .sorted { $0.dayKey < $1.dayKey }
            .flatMap { daily -> [UsageRelayRecord] in
                let snapshotID = self.snapshotID(provider: provider, dayKey: daily.dayKey, writtenAt: writtenAt)
                let sourceFingerprint = "daily-summary:\(provider):\(daily.dayKey)"
                let event = UsageRelayEvent(
                    eventID: "daily-summary:\(provider):\(daily.dayKey)",
                    snapshotID: snapshotID,
                    provider: provider,
                    timestamp: Self.dayDate(fromKey: daily.dayKey) ?? writtenAt,
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
    func archiveEntriesAsRelayEvents(
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
            let dayEntries = entries.filter { Self.dayKey(for: $0.timestamp) == dayKey }

            // The relay is a compact daily memory: every day — today included —
            // collapses to ONE aggregate record ("yesterday, as of yesterday").
            // Writing a record per raw log line is what let a single Codex rebuild
            // balloon this file past 500MB. Fine-grained intra-day detail is
            // recomputed live from the provider logs, so the relay never needs
            // per-event rows.
            if let event = Self.aggregatedDailyEvent(
                provider: provider,
                dayKey: dayKey,
                snapshotID: snapshotID,
                entries: dayEntries)
            {
                records.append(UsageRelayRecord(
                    schemaVersion: Self.relaySchemaVersion,
                    recordType: UsageRelayRecordType.event.rawValue,
                    provider: provider,
                    writtenAt: scanDate,
                    event: event,
                    watermark: nil))
            }

            // One watermark per day — all the materializer needs to pick the
            // latest snapshot for a day. Writing one per scanned source file made
            // the relay O(files × days): 671 Claude logs × 30 days ≈ 20k rows /
            // 17MB of pure bookkeeping. Nothing reads per-file watermarks (the
            // sources gate incremental scans on file mtime), so collapse to O(days).
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
                    sourceFingerprint: "scan:\(provider):\(dayKey):\(snapshotID)",
                    path: nil,
                    modifiedAt: nil,
                    sizeBytes: nil,
                    scannedAt: scanDate)))
        }

        do {
            try self.appendRelayRecords(records)
            return true
        } catch {
            Self.log.warning("Failed to append relay event records for \(provider): \(error.localizedDescription)")
            return false
        }
    }

    /// Collapse a day's raw entries into a single aggregate relay event. This is
    /// the whole point of the relay: a historical day is remembered as one summed
    /// row, not as a verbatim copy of every provider log line.
    static func aggregatedDailyEvent(
        provider: String,
        dayKey: String,
        snapshotID: String,
        entries: [UsageLedgerEntry]) -> UsageRelayEvent?
    {
        guard !entries.isEmpty else { return nil }

        var input = 0
        var output = 0
        var cacheCreation = 0
        var cacheRead = 0
        var cost = 0.0
        var hasCost = false
        var models = Set<String>()

        for entry in entries {
            input += entry.inputTokens
            output += entry.outputTokens
            cacheCreation += entry.cacheCreationTokens
            cacheRead += entry.cacheReadTokens
            if let entryCost = entry.costUSD {
                cost += entryCost
                hasCost = true
            }
            if let model = entry.model { models.insert(model) }
        }

        let modelsUsed = models.sorted()
        return UsageRelayEvent(
            eventID: "daily-aggregate:\(provider):\(dayKey)",
            snapshotID: snapshotID,
            provider: provider,
            timestamp: Self.dayDate(fromKey: dayKey) ?? entries[0].timestamp,
            dayKey: dayKey,
            sessionID: nil,
            projectID: nil,
            projectName: nil,
            model: modelsUsed.count == 1 ? modelsUsed.first : nil,
            modelsUsed: modelsUsed,
            inputTokens: input,
            outputTokens: output,
            cacheCreationTokens: cacheCreation,
            cacheReadTokens: cacheRead,
            costUSD: hasCost ? cost : nil,
            requestCount: entries.count,
            requestID: nil,
            messageID: nil,
            version: nil,
            source: "relay-daily-aggregate",
            operationKind: nil,
            tokenProvenance: nil,
            costProvenance: nil,
            sourceFingerprint: "daily-aggregate:\(provider):\(dayKey)")
    }

    func snapshotID(provider: String, dayKey: String, writtenAt: Date) -> String {
        "snapshot:\(provider):\(dayKey):\(Int(writtenAt.timeIntervalSince1970 * 1000)):\(UUID().uuidString)"
    }

    static func touchedDayKeys(
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
}
