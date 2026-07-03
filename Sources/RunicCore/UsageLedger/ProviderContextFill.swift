import Foundation

/// A point-in-time reading of how much of a model's context window the most
/// recent request in the current (most recently active) session occupied.
///
/// Unlike the block-volume "context pressure" heuristic, this is REAL context
/// state: local transcripts record, per request, exactly how many tokens were
/// in the model's window when the request was made.
public struct ProviderContextFillSample: Equatable, Sendable {
    /// Prompt-side tokens that were in the context window for the last request.
    /// Claude: `input_tokens + cache_read_input_tokens + cache_creation_input_tokens`.
    /// Codex: `last_token_usage.input_tokens` (cached tokens are a subset of input).
    public let occupiedTokens: Int
    public let model: String?
    /// Context window size reported by the transcript itself (Codex rollouts
    /// carry `model_context_window`); nil when the transcript doesn't say.
    public let transcriptContextWindow: Int?
    /// Timestamp of the transcript entry the sample was read from — the
    /// staleness gate for "is this session still live".
    public let timestamp: Date
    public let sessionID: String?

    public init(
        occupiedTokens: Int,
        model: String?,
        transcriptContextWindow: Int?,
        timestamp: Date,
        sessionID: String?)
    {
        self.occupiedTokens = occupiedTokens
        self.model = model
        self.transcriptContextWindow = transcriptContextWindow
        self.timestamp = timestamp
        self.sessionID = sessionID
    }
}

/// Reads only the tail of a (potentially multi-GB) JSONL transcript. The
/// latest context state lives in the last few entries, so scanning the whole
/// file — the mistake that made full-history codex scans balloon — is never
/// needed here.
enum ContextFillTailReader {
    /// Returns the complete lines contained in the final `tailBytes` of the
    /// file, oldest first. When the read starts mid-file the first line is a
    /// partial fragment and is dropped.
    static func tailLines(of url: URL, tailBytes: Int = 256 * 1024) -> [Data] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return [] }
        let start = size > UInt64(tailBytes) ? size - UInt64(tailBytes) : 0
        guard (try? handle.seek(toOffset: start)) != nil,
              let data = try? handle.readToEnd(),
              !data.isEmpty
        else {
            return []
        }
        var lines = data.split(separator: 0x0A, omittingEmptySubsequences: true).map { Data($0) }
        if start > 0, !lines.isEmpty {
            lines.removeFirst()
        }
        return lines
    }
}
