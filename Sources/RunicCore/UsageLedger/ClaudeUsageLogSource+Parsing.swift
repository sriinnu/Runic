import Foundation

extension ClaudeUsageLogSource {
    /// Parse a single JSONL file, returning usage entries.
    func parseFile(_ file: UsageFile, minDate: Date?, dayKey: String?) throws -> ParsedUsageFile {
        var entries: [UsageLedgerEntry] = []
        var seenKeys = Set<String>()
        let sourceMetadata = self.sourceMetadata(for: file.url)
        let sourceFingerprint = self.sourceFingerprint(for: sourceMetadata)

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
                entries.append(entry)
            }
        }

        do {
            try CostUsageJsonl.scan(
                fileURL: file.url,
                maxLineBytes: 512 * 1024,
                prefixBytes: 512 * 1024)
            { line in
                guard !line.wasTruncated else { return }
                consume(line.bytes)
            }
        } catch {
            throw ClaudeUsageLogError.readFailed("\(file.url.path): \(error.localizedDescription)")
        }
        let latestMetadata = self.sourceMetadata(for: file.url)
        guard latestMetadata == sourceMetadata else {
            throw ClaudeUsageLogError.readFailed("Claude usage log changed while scanning: \(sourceMetadata.path)")
        }
        return ParsedUsageFile(
            entries: entries,
            watermark: self.sourceWatermark(for: sourceMetadata, dayKey: dayKey))
    }

    func dedupeKey(
        requestID: String?,
        messageID: String?,
        sessionID: String?,
        timestamp: Date,
        tokens: DedupeTokens) -> String
    {
        if let requestID, !requestID.isEmpty {
            return "req:\(requestID)"
        }
        if let messageID, !messageID.isEmpty {
            return "msg:\(messageID)"
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
