import Foundation

extension ClaudeUsageLogSource {
    /// Parse a single JSONL file, returning usage entries.
    func parseFile(_ file: UsageFile, minDate: Date?, dayKey: String?) throws -> ParsedUsageFile {
        var seenKeys = Set<String>()
        let sourceMetadata = self.sourceMetadata(for: file.url)
        let sourceFingerprint = self.sourceFingerprint(for: sourceMetadata)
        let resumeKey = "claude|\(sourceMetadata.path)"

        // Byte-offset resume: skip the already-parsed prefix of an append-only
        // project JSONL and carry forward the entries parsed by earlier scans.
        // Any mismatch (rotation, truncation, wider scan window) falls back to
        // a full re-read via `resumableState`.
        var startOffset: Int64 = 0
        var carriedEntries: [UsageLedgerEntry] = []
        let fingerprint: (hash: UInt64, length: Int)?
        if let prior = self.resumeStore.resumableState(
            forKey: resumeKey,
            url: file.url,
            currentSizeBytes: sourceMetadata.sizeBytes,
            minDate: minDate)
        {
            startOffset = prior.resumeOffset
            carriedEntries = prior.entries
            fingerprint = (prior.fingerprint, prior.fingerprintLength)
        } else {
            fingerprint = LedgerScanResumeStore.prefixFingerprint(url: file.url)
        }

        // Register carried entries so a re-parsed torn final line (the resume
        // offset stops at the last newline) dedupes against them. Totals
        // invariant: carried-in-window + newly-parsed tail == a from-scratch
        // scan of the whole file.
        var entries: [UsageLedgerEntry] = []
        entries.reserveCapacity(carriedEntries.count)
        for carried in carriedEntries {
            if let minDate, carried.timestamp < minDate { continue }
            let key = self.dedupeKey(forEntry: carried)
            guard seenKeys.insert(key).inserted else { continue }
            entries.append(carried)
        }

        var newEntries: [UsageLedgerEntry] = []
        func consume(_ lineData: Data) {
            guard !lineData.isEmpty,
                  let line = String(data: lineData, encoding: .utf8)?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                      !line.isEmpty
            else { return }
            if let entry = self.parseLine(
                line[...],
                file: file,
                minDate: minDate,
                sourceFingerprint: sourceFingerprint,
                seenKeys: &seenKeys)
            {
                newEntries.append(entry)
            }
        }

        let resumeOffset: Int64
        do {
            resumeOffset = try CostUsageJsonl.scan(
                fileURL: file.url,
                offset: startOffset,
                maxLineBytes: 512 * 1024,
                prefixBytes: 512 * 1024)
            { line in
                guard !line.wasTruncated else { return }
                consume(line.bytes)
            }
        } catch {
            self.resumeStore.removeState(forKey: resumeKey)
            throw ClaudeUsageLogError.readFailed("\(file.url.path): \(error.localizedDescription)")
        }
        entries.append(contentsOf: newEntries)
        let latestMetadata = self.sourceMetadata(for: file.url)
        // A live session appends to its project JSONL continuously, so the file
        // usually GROWS during a read. That is safe for an append-only log: we
        // parsed a valid prefix and the tail is captured next scan. Only reject a
        // SHRINK (truncation/rewrite) as a genuinely torn read.
        if let before = sourceMetadata.sizeBytes,
           let after = latestMetadata.sizeBytes,
           after < before
        {
            self.resumeStore.removeState(forKey: resumeKey)
            throw ClaudeUsageLogError.readFailed("Claude usage log truncated while scanning: \(sourceMetadata.path)")
        }

        if let fingerprint, let latestSize = latestMetadata.sizeBytes {
            self.resumeStore.setState(
                LedgerScanResumeStore.FileState(
                    fingerprint: fingerprint.hash,
                    fingerprintLength: fingerprint.length,
                    sizeBytes: latestSize,
                    resumeOffset: resumeOffset,
                    minDate: minDate,
                    entries: entries,
                    codexCursor: nil),
                forKey: resumeKey)
        } else {
            self.resumeStore.removeState(forKey: resumeKey)
        }
        return ParsedUsageFile(
            entries: entries,
            watermark: self.sourceWatermark(for: sourceMetadata, dayKey: dayKey))
    }

    /// Reconstructs the dedupe key for an already-built entry (Claude entries
    /// store token classes exactly as parsed, so this is a direct mapping).
    func dedupeKey(forEntry entry: UsageLedgerEntry) -> String {
        self.dedupeKey(
            requestID: entry.requestID,
            messageID: entry.messageID,
            sessionID: entry.sessionID,
            timestamp: entry.timestamp,
            tokens: DedupeTokens(
                input: entry.inputTokens,
                output: entry.outputTokens,
                cacheCreation: entry.cacheCreationTokens,
                cacheRead: entry.cacheReadTokens))
    }

    func dedupeKey(
        requestID: String?,
        messageID: String?,
        sessionID: String?,
        timestamp: Date,
        tokens: DedupeTokens) -> String
    {
        // ccusage convention: the unique unit is messageId+requestId. A retried
        // request reuses its requestId across DISTINCT usage-bearing messages, so
        // keying on requestId alone would silently drop the retry's usage.
        if let messageID, !messageID.isEmpty, let requestID, !requestID.isEmpty {
            return "msg:\(messageID)|req:\(requestID)"
        }
        if let messageID, !messageID.isEmpty {
            return "msg:\(messageID)"
        }
        if let requestID, !requestID.isEmpty {
            return "req:\(requestID)"
        }
        return [
            "ts:\(timestamp.timeIntervalSince1970)",
            sessionID ?? "-",
            "\(tokens.input)",
            "\(tokens.output)",
            "\(tokens.cacheCreation)",
            "\(tokens.cacheRead)",
        ].joined(separator: "|")
    }

    private func parseLine(
        _ line: Substring,
        file: UsageFile,
        minDate: Date?,
        sourceFingerprint: String,
        seenKeys: inout Set<String>) -> UsageLedgerEntry?
    {
        let text = String(line)
        guard let data = text.data(using: .utf8) else { return nil }
        do {
            let payload = try JSONDecoder().decode(ClaudeUsageLogLine.self, from: data)
            if payload.isApiErrorMessage == true { return nil }
            guard let timestamp = self.parseTimestamp(payload.timestamp) else { return nil }
            if let minDate, timestamp < minDate { return nil }
            let usage = payload.message.usage
            let input = max(0, usage.inputTokens)
            let output = max(0, usage.outputTokens)
            let cacheCreation = max(0, usage.cacheCreationInputTokens ?? 0)
            let cacheRead = max(0, usage.cacheReadInputTokens ?? 0)
            let total = input + output + cacheCreation + cacheRead
            guard total > 0 else { return nil }

            let sessionID = payload.sessionId ?? file.sessionID
            let pricingCost = payload.message.model.flatMap { model in
                CostUsagePricing.claudeCostUSD(
                    model: model,
                    inputTokens: input,
                    cacheReadInputTokens: cacheRead,
                    cacheCreationInputTokens: cacheCreation,
                    outputTokens: output)
            }
            let computedCost = payload.costUSD ?? pricingCost
            let costProvenance: MetricProvenance? = if payload.costUSD != nil {
                MetricProvenance(
                    confidence: .providerReported,
                    source: .localLog,
                    detail: "Claude JSONL cost field")
            } else if pricingCost != nil {
                MetricProvenance(
                    confidence: .estimated,
                    source: .pricingTable,
                    detail: "Claude token pricing fallback")
            } else {
                nil
            }
            let key = self.dedupeKey(
                requestID: payload.requestId,
                messageID: payload.message.id,
                sessionID: sessionID,
                timestamp: timestamp,
                tokens: .init(
                    input: input,
                    output: output,
                    cacheCreation: cacheCreation,
                    cacheRead: cacheRead))
            if seenKeys.contains(key) { return nil }
            seenKeys.insert(key)

            return UsageLedgerEntry(
                provider: .claude,
                timestamp: timestamp,
                sessionID: sessionID,
                projectID: file.projectID,
                projectName: file.projectName,
                model: payload.message.model,
                inputTokens: input,
                outputTokens: output,
                cacheCreationTokens: cacheCreation,
                cacheReadTokens: cacheRead,
                costUSD: computedCost,
                requestID: payload.requestId,
                messageID: payload.message.id,
                version: payload.version,
                source: .claudeLog,
                tokenProvenance: MetricProvenance(
                    confidence: .exact,
                    source: .localLog,
                    detail: "Claude JSONL message.usage"),
                costProvenance: costProvenance,
                sourceFingerprint: sourceFingerprint)
        } catch {
            return nil
        }
    }

    private func parseTimestamp(_ value: String) -> Date? {
        let box = claudeISOFormatterBox
        box.lock.lock()
        defer { box.lock.unlock() }
        return box.iso.date(from: value) ?? box.fractional.date(from: value)
    }
}

private struct ClaudeUsageLogLine: Decodable {
    struct Message: Decodable {
        struct Usage: Decodable {
            let inputTokens: Int
            let outputTokens: Int
            let cacheCreationInputTokens: Int?
            let cacheReadInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
        }

        let usage: Usage
        let model: String?
        let id: String?
    }

    let timestamp: String
    let sessionId: String?
    let version: String?
    let message: Message
    let costUSD: Double?
    let requestId: String?
    let isApiErrorMessage: Bool?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case sessionId
        case version
        case message
        case costUSD
        case requestId
        case isApiErrorMessage
    }
}

private final class ClaudeISO8601FormatterBox: @unchecked Sendable {
    let lock = NSLock()
    let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private let claudeISOFormatterBox = ClaudeISO8601FormatterBox()
