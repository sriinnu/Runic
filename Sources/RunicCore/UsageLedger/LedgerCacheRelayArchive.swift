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

    func snapshotID(provider: String, dayKey: String, writtenAt: Date) -> String {
        "snapshot:\(provider):\(dayKey):\(Int(writtenAt.timeIntervalSince1970 * 1000)):\(UUID().uuidString)"
    }

    func eventID(for entry: UsageLedgerEntry, dayKey: String, index: Int) -> String {
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
