import Foundation
import RunicCore

enum UsageLedgerSourceFactory {
    static func source(
        for provider: UsageProvider,
        now: Date,
        maxAgeDays: Int) -> (any UsageLedgerSource)?
    {
        switch provider {
        case .claude:
            return ClaudeUsageLogSource(maxAgeDays: maxAgeDays, now: now)
        case .codex:
            return CodexUsageLogSource(maxAgeDays: maxAgeDays, now: now)
        case .copilot,
             .gemini,
             .antigravity,
             .cursor,
             .factory,
             .zai,
             .minimax,
             .openrouter,
             .groq,
             .deepseek,
             .fireworks,
             .mistral,
             .perplexity,
             .kimi,
             .auggie,
             .together,
             .cohere,
             .xai,
             .cerebras,
             .sambanova,
             .azure,
             .bedrock,
             .vertexai,
             .qwen:
            return self.otelHistorySource(provider: provider, now: now, maxAgeDays: maxAgeDays)
        @unknown default:
            return nil
        }
    }

    private static func otelHistorySource(
        provider: UsageProvider,
        now: Date,
        maxAgeDays: Int) -> (any UsageLedgerSource)?
    {
        let files = self.otelLedgerFiles(for: provider)
        guard !files.isEmpty else { return nil }

        let cutoff = Calendar.current.date(byAdding: .day, value: -max(1, maxAgeDays), to: now)
        let options = OTelGenAIIngestionOptions(
            enabled: true,
            allowExperimentalSemanticConventions: true,
            defaultProvider: provider,
            source: .api)
        return UsageLedgerProviderFilterSource(
            source: OTelGenAIFileLedgerSource(files: files, options: options),
            provider: provider,
            minTimestamp: cutoff)
    }

    private static func otelLedgerFiles(for provider: UsageProvider) -> [URL] {
        let env = ProcessInfo.processInfo.environment
        let providerKey = provider.rawValue
            .replacingOccurrences(of: "-", with: "_")
            .uppercased()

        let candidatePaths = [
            Self.splitPathList(env["RUNIC_OTEL_GENAI_LOG_PATHS"]),
            Self.splitPathList(env["RUNIC_OTEL_GENAI_LOG_PATH"]),
            Self.splitPathList(env["RUNIC_\(providerKey)_OTEL_GENAI_LOG_PATHS"]),
            Self.splitPathList(env["RUNIC_\(providerKey)_OTEL_GENAI_LOG_PATH"]),
            Self.splitPathList(env["RUNIC_\(providerKey)_OTEL_LOG_PATHS"]),
            Self.splitPathList(env["RUNIC_\(providerKey)_OTEL_LOG_PATH"]),
        ].flatMap(\.self)

        let urls = candidatePaths.compactMap(Self.expandTildePath)
        return Self.discoverOTelLedgerFiles(from: urls)
    }

    private static func splitPathList(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return raw
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func expandTildePath(_ rawPath: String) -> URL? {
        let fileManager = FileManager.default
        if rawPath.hasPrefix("~/") {
            return fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(String(rawPath.dropFirst(2)), isDirectory: true)
        }
        return URL(fileURLWithPath: rawPath, isDirectory: true)
    }

    private static func discoverOTelLedgerFiles(from paths: [URL]) -> [URL] {
        var found: [URL] = []
        var seen: Set<String> = []

        for path in paths {
            if Self.isSupportedOTelFile(path) {
                if seen.insert(path.standardizedFileURL.path).inserted {
                    found.append(path.standardizedFileURL)
                }
                continue
            }

            for file in Self.scanOTelDirectory(path) where seen.insert(file.standardizedFileURL.path).inserted {
                found.append(file.standardizedFileURL)
            }
        }

        return found
    }

    private static func isSupportedOTelFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists && !isDirectory.boolValue else { return false }

        let ext = url.pathExtension.lowercased()
        return ext == "json" || ext == "jsonl"
    }

    private static func scanOTelDirectory(_ directory: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue
        else { return [] }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]) else { return [] }

        var files: [URL] = []
        for case let file as URL in enumerator where Self.isSupportedOTelFile(file) {
            files.append(file)
        }
        return files
    }

    private struct UsageLedgerProviderFilterSource: UsageLedgerSource {
        private let source: any UsageLedgerSource
        private let provider: UsageProvider
        private let minTimestamp: Date?

        init(source: any UsageLedgerSource, provider: UsageProvider, minTimestamp: Date?) {
            self.source = source
            self.provider = provider
            self.minTimestamp = minTimestamp
        }

        func loadEntries() async throws -> [UsageLedgerEntry] {
            let entries = try await self.source.loadEntries()
            return entries.filter { entry in
                if entry.provider != self.provider { return false }
                if let minTimestamp, entry.timestamp < minTimestamp { return false }
                return true
            }
        }
    }
}
