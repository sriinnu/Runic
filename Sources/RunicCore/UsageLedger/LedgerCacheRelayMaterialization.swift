import Foundation
import OSLog

extension LedgerCache {
    func materializedRelayState(provider: String) -> UsageRelayMaterializedState {
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
                // Accept this schema and OLDER (records are additive-optional, so
                // they still decode). Only skip genuinely future versions whose
                // semantics this build can't safely interpret. Using `>=` here was
                // a latent landmine: the next `relaySchemaVersion` bump would have
                // silently dropped every existing day — the exact "renders as zero"
                // failure the relay exists to prevent.
                guard
                    let record = try? JSONDecoder().decode(UsageRelayRecord.self, from: line.bytes),
                    record.provider == provider,
                    record.schemaVersion <= Self.relaySchemaVersion
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

            // Relay events are Runic's own normalized scan output, not untrusted
            // legacy cache data, so the plausibility cap does not apply here.
            // Heavy real days legitimately exceed 100M tokens (cache reads alone
            // can run into the billions); quarantining them here is what made
            // recent high-usage days render as zero.
            return CachedDaily(
                dayKey: dayKey,
                inputTokens: input,
                outputTokens: output,
                cacheCreationTokens: cacheCreation,
                cacheReadTokens: cacheRead,
                costUSD: hasCost ? cost : nil,
                requestCount: requests,
                modelsUsed: models.sorted())
        }
        .sorted { $0.dayKey < $1.dayKey }

        return UsageRelayMaterializedState(
            dailies: dailies,
            touchedDayKeys: Set(selectedByDay.keys))
    }
}
