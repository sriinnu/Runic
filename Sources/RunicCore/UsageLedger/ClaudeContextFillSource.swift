import Foundation

/// Extracts the live context-window occupancy of the CURRENT Claude session.
///
/// The most recently modified transcript under the Claude projects directory
/// is the live session (the same mtime-selection pattern the ledger uses).
/// Its latest usage-bearing JSONL entry records exactly what was in the
/// model's context for the last request:
/// `input_tokens + cache_read_input_tokens + cache_creation_input_tokens`.
/// Output tokens are excluded — the sample is the prompt-side window state at
/// request time, matching how Claude itself reports context usage.
///
/// Only the tail of the file is read; live project JSONLs grow without bound.
public struct ClaudeContextFillSource: @unchecked Sendable {
    private let environment: [String: String]
    private let fileManager: FileManager
    private let basePaths: [URL]?
    /// Transcripts whose file mtime is older than this are ignored: an idle
    /// session's context occupancy is noise, not signal.
    private let maxSampleAge: TimeInterval
    private let tailBytes: Int

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        basePaths: [URL]? = nil,
        maxSampleAge: TimeInterval = 30 * 60,
        tailBytes: Int = 256 * 1024)
    {
        self.environment = environment
        self.fileManager = fileManager
        self.basePaths = basePaths
        self.maxSampleAge = maxSampleAge
        self.tailBytes = tailBytes
    }

    public func latestSample(now: Date = Date()) -> ProviderContextFillSample? {
        let source = ClaudeUsageLogSource(
            environment: self.environment,
            fileManager: self.fileManager,
            basePaths: self.basePaths,
            now: now)
        guard let projectsDirs = try? source.resolveProjectsDirectories(), !projectsDirs.isEmpty else {
            return nil
        }

        let minDate = now.addingTimeInterval(-self.maxSampleAge)
        let candidates = source.findUsageFiles(in: projectsDirs, minDate: minDate)
            .compactMap { file -> (file: ClaudeUsageLogSource.UsageFile, modifiedAt: Date)? in
                let values = try? file.url.resourceValues(forKeys: [.contentModificationDateKey])
                guard let modifiedAt = values?.contentModificationDate, modifiedAt >= minDate else {
                    return nil
                }
                return (file, modifiedAt)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }

        for candidate in candidates {
            if let sample = self.latestUsageEntry(in: candidate.file) {
                return sample
            }
        }
        return nil
    }

    private func latestUsageEntry(in file: ClaudeUsageLogSource.UsageFile) -> ProviderContextFillSample? {
        let lines = ContextFillTailReader.tailLines(of: file.url, tailBytes: self.tailBytes)
        let decoder = JSONDecoder()
        for lineData in lines.reversed() {
            guard let line = try? decoder.decode(ContextFillTranscriptLine.self, from: lineData) else { continue }
            if line.isApiErrorMessage == true { continue }
            guard let usage = line.message?.usage,
                  let timestampText = line.timestamp,
                  let timestamp = Self.parseTimestamp(timestampText)
            else { continue }
            let occupied = max(0, usage.inputTokens ?? 0)
                + max(0, usage.cacheReadInputTokens ?? 0)
                + max(0, usage.cacheCreationInputTokens ?? 0)
            guard occupied > 0 else { continue }
            return ProviderContextFillSample(
                occupiedTokens: occupied,
                model: line.message?.model,
                transcriptContextWindow: nil,
                timestamp: timestamp,
                sessionID: line.sessionId ?? file.sessionID)
        }
        return nil
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

private struct ContextFillTranscriptLine: Decodable {
    struct Message: Decodable {
        struct Usage: Decodable {
            let inputTokens: Int?
            let cacheCreationInputTokens: Int?
            let cacheReadInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
        }

        let usage: Usage?
        let model: String?
    }

    let timestamp: String?
    let sessionId: String?
    let message: Message?
    let isApiErrorMessage: Bool?
}
