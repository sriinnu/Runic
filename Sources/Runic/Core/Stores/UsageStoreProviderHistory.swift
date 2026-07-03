import Foundation
import RunicCore

struct UsageStoreProviderHistorySupport {
    let configuredOTelLogPaths: String
    let environment: [String: String]
    let maxScanDays: Int

    func normalizedMonthStart(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    func cacheKey(for monthStart: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.year, .month], from: monthStart)
        return String(format: "%04d-%02d", components.year ?? 1970, components.month ?? 1)
    }

    func scanDays(monthStart: Date, now: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: monthStart)
        let end = calendar.startOfDay(for: now)
        let daysBetween = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        let target = max(35, daysBetween + 7)
        return min(self.maxScanDays, target)
    }

    func note(scanDays: Int) -> String? {
        guard scanDays >= self.maxScanDays else { return nil }
        return "History scans up to the most recent \(scanDays) days for performance."
    }

    func source(
        provider: UsageProvider,
        now: Date,
        maxAgeDays: Int) -> (any UsageLedgerSource)?
    {
        switch provider {
        case .claude:
            return ClaudeUsageLogSource(maxAgeDays: maxAgeDays, now: now)
        case .codex:
            return CodexUsageLogSource(maxAgeDays: maxAgeDays, now: now)
        case .opencode:
            return OpencodeUsageLogSource(maxAgeDays: maxAgeDays, now: now)
        case .copilot,
             .gemini,
             .antigravity,
             .cursor,
             .factory,
             .zai,
             .minimax,
             .openrouter,
             .vercelai,
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
             .qwen,
             .localLLM:
            return self.otelHistorySource(provider: provider, now: now, maxAgeDays: maxAgeDays)
        @unknown default:
            return nil
        }
    }

    static func unsupportedSnapshot(
        provider: UsageProvider,
        monthStart: Date,
        generatedAt: Date) -> ProviderHistoryMonthSnapshot
    {
        ProviderHistoryMonthSnapshot(
            provider: provider,
            monthStart: monthStart,
            generatedAt: generatedAt,
            days: [],
            isSupported: false,
            note: "History is available for Claude/Codex/opencode local ledgers and configured OTel sources.",
            error: nil)
    }

    nonisolated static func providerHistoryDays(
        entries: [UsageLedgerEntry],
        timeZone: TimeZone) -> [ProviderHistoryDaySnapshot]
    {
        guard !entries.isEmpty else { return [] }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dailySummaries = UsageLedgerAggregator.dailySummaries(
            entries: entries,
            timeZone: timeZone,
            groupByProject: false)
            .sorted { $0.dayStart < $1.dayStart }

        var entriesByDay: [Date: [UsageLedgerEntry]] = [:]
        for entry in entries {
            let dayStart = calendar.startOfDay(for: entry.timestamp)
            entriesByDay[dayStart, default: []].append(entry)
        }

        return dailySummaries.map { summary in
            let dayEntries = entriesByDay[summary.dayStart] ?? []
            let modelSummaries = UsageLedgerAggregator.modelSummaries(entries: dayEntries)
            let projectSummaries = UsageLedgerAggregator.projectSummaries(entries: dayEntries)
            let topModel = modelSummaries.first
            let topProject = projectSummaries.first
            return ProviderHistoryDaySnapshot(
                dayStart: summary.dayStart,
                totals: summary.totals,
                requestCount: dayEntries.count,
                modelsUsed: summary.modelsUsed,
                topModel: topModel,
                topProject: topProject,
                modelSummaries: modelSummaries,
                projectSummaries: projectSummaries)
        }
    }

    nonisolated static func cachedProviderHistoryDays(
        provider: UsageProvider,
        monthStart: Date,
        timeZone: TimeZone) async -> [ProviderHistoryDaySnapshot]
    {
        guard let cached = await LedgerCache.shared.loadCachedDailies(provider: provider.rawValue) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return cached.dailies.compactMap { daily in
            guard let summary = daily.toLedgerDailySummary(provider: provider),
                  calendar.isDate(summary.dayStart, equalTo: monthStart, toGranularity: .month)
            else { return nil }
            return ProviderHistoryDaySnapshot(
                dayStart: summary.dayStart,
                totals: summary.totals,
                requestCount: daily.requestCount,
                modelsUsed: summary.modelsUsed,
                topModel: nil,
                topProject: nil,
                modelSummaries: [],
                projectSummaries: [])
        }
        .sorted { $0.dayStart < $1.dayStart }
    }

    nonisolated static func mergedProviderHistoryDays(
        cachedDays: [ProviderHistoryDaySnapshot],
        entryDays: [ProviderHistoryDaySnapshot]) -> [ProviderHistoryDaySnapshot]
    {
        var byDay = Dictionary(uniqueKeysWithValues: cachedDays.map { ($0.dayStart, $0) })
        for day in entryDays {
            byDay[day.dayStart] = day
        }
        return byDay.values.sorted { $0.dayStart < $1.dayStart }
    }

    private func otelHistorySource(
        provider: UsageProvider,
        now: Date,
        maxAgeDays: Int) -> (any UsageLedgerSource)?
    {
        let files = self.otelLedgerFiles(for: provider)
        guard !files.common.isEmpty || !files.providerSpecific.isEmpty else { return nil }

        let options = OTelGenAIIngestionOptions(
            enabled: true,
            allowExperimentalSemanticConventions: true,
            defaultProvider: provider,
            source: .openTelemetry)
        return CachedOTelProviderHistorySource(
            commonFiles: files.common,
            providerSpecificFiles: files.providerSpecific,
            options: options,
            provider: provider,
            maxAgeDays: maxAgeDays,
            now: now)
    }

    private func otelLedgerFiles(for provider: UsageProvider) -> (common: [URL], providerSpecific: [URL]) {
        let providerKey = provider.rawValue
            .replacingOccurrences(of: "-", with: "_")
            .uppercased()

        let commonPaths = [
            [
                OTelGenAICollectorConfiguration.defaultOutputFile().path,
                OTelGenAICollectorConfiguration.defaultOutputDirectory().path,
            ],
            Self.splitPathList(self.configuredOTelLogPaths),
            Self.splitPathList(self.environment["RUNIC_OTEL_GENAI_LOG_PATHS"]),
            Self.splitPathList(self.environment["RUNIC_OTEL_GENAI_LOG_PATH"]),
        ].flatMap(\.self)
        let providerPaths = [
            Self.splitPathList(self.environment["RUNIC_\(providerKey)_OTEL_GENAI_LOG_PATHS"]),
            Self.splitPathList(self.environment["RUNIC_\(providerKey)_OTEL_GENAI_LOG_PATH"]),
            Self.splitPathList(self.environment["RUNIC_\(providerKey)_OTEL_LOG_PATHS"]),
            Self.splitPathList(self.environment["RUNIC_\(providerKey)_OTEL_LOG_PATH"]),
        ].flatMap(\.self)

        let commonFiles = Self.discoverOTelLedgerFiles(from: commonPaths.compactMap(Self.expandTildePath))
        let commonPathsSeen = Set(commonFiles.map(\.standardizedFileURL.path))
        let providerFiles = Self.discoverOTelLedgerFiles(from: providerPaths.compactMap(Self.expandTildePath))
            .filter { !commonPathsSeen.contains($0.standardizedFileURL.path) }
        return (commonFiles, providerFiles)
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
            options: [.skipsHiddenFiles])
        else { return [] }

        var files: [URL] = []
        for case let file as URL in enumerator where Self.isSupportedOTelFile(file) {
            files.append(file)
        }
        return files
    }
}

struct CachedOTelProviderHistorySource: UsageLedgerSource {
    private let commonFiles: [URL]
    private let providerSpecificFiles: [URL]
    private let options: OTelGenAIIngestionOptions
    private let provider: UsageProvider
    private let maxAgeDays: Int
    private let now: Date
    private let cache: LedgerCache

    init(
        commonFiles: [URL],
        providerSpecificFiles: [URL],
        options: OTelGenAIIngestionOptions,
        provider: UsageProvider,
        maxAgeDays: Int,
        now: Date,
        cache: LedgerCache = .shared)
    {
        self.commonFiles = commonFiles
        self.providerSpecificFiles = providerSpecificFiles
        self.options = options
        self.provider = provider
        self.maxAgeDays = maxAgeDays
        self.now = now
        self.cache = cache
    }

    func loadEntries() async throws -> [UsageLedgerEntry] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let todayStart = calendar.startOfDay(for: self.now)
        let requestedCoverageDays = max(1, self.maxAgeDays)
        let coveredDays = await self.cache.effectiveCoveredMaxAgeDays(provider: self.provider.rawValue) ?? 0
        let historyCovered = coveredDays >= requestedCoverageDays
        let historyStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -requestedCoverageDays, to: self.now) ?? self.now)
        // A covered refresh used to be today-only, which permanently lost any
        // day the app was closed during: usage kept landing in the OTel files,
        // but `lastScanDate` still advanced, so the gap became invisible and
        // those days stayed blank forever. Mirror the log sources' scanGapDays
        // catch-up: anchor the scan window to the last scan date so exactly the
        // missed days are backfilled. Additive on purpose — this is NOT a
        // history rebuild: days outside the window are never touched, and a gap
        // day whose raw entries have since rotated away keeps its cached
        // aggregate (see mergeDailies below).
        let gapDays = await self.cache.scanGapDays(provider: self.provider.rawValue, now: self.now)
        let minTimestamp = historyCovered
            ? Self.gapScanStart(
                gapDays: gapDays,
                requestedCoverageDays: requestedCoverageDays,
                now: self.now,
                calendar: calendar)
            : historyStart
        let isGapCatchUp = historyCovered && minTimestamp < todayStart

        let commonOptions = OTelGenAIIngestionOptions(
            enabled: self.options.enabled,
            allowExperimentalSemanticConventions: self.options.allowExperimentalSemanticConventions,
            defaultProvider: nil,
            source: self.options.source)
        let commonEntries = try await UsageLedgerOTelRelay.shared.loadEntries(
            files: self.commonFiles,
            options: commonOptions,
            minTimestamp: minTimestamp)
        let providerEntries = try await UsageLedgerOTelRelay.shared.loadEntries(
            files: self.providerSpecificFiles,
            options: self.options,
            minTimestamp: minTimestamp)
        let loaded = commonEntries + providerEntries
        let entries = loaded.filter { entry in
            if entry.provider != self.provider { return false }
            if entry.timestamp < minTimestamp { return false }
            return true
        }

        let dailies = Self.cachedDailies(from: entries)
        if dailies.isEmpty {
            await self.cache.markScanComplete(
                provider: self.provider.rawValue,
                scanDate: self.now,
                coveredMaxAgeDays: historyCovered ? nil : requestedCoverageDays)
        } else {
            // Steady state passes todayKey so existing pre-today days stay
            // frozen (relay contract). During a gap catch-up the freshly
            // recounted gap days must REPLACE their aggregates — a day the app
            // was closed halfway through was only partially counted, and
            // replacing the recomputed total (instead of freezing or adding)
            // is what keeps it from being double-counted. Merge only touches
            // days present in `dailies`, so a gap day that produced no entries
            // keeps its existing aggregate. The archive boundary is ALWAYS
            // today: relay rows take precedence for their day, so archiving
            // today's still-partial aggregate (as the nil-todayKey catch-up
            // used to, every morning rollover) pinned today at the catch-up
            // moment's count for the rest of the day.
            await self.cache.mergeDailies(
                provider: self.provider.rawValue,
                newDailies: dailies,
                scanDate: self.now,
                todayKey: historyCovered && !isGapCatchUp ? LedgerCache.dayKey(for: self.now) : nil,
                archiveBoundaryDayKey: LedgerCache.dayKey(for: self.now),
                coveredMaxAgeDays: historyCovered ? nil : requestedCoverageDays)
        }
        return entries
    }

    /// Lower bound for a covered refresh scan.
    ///
    /// - Scanned today (gap 1 or unknown): today only (steady state, costs nothing).
    /// - Last scan N days ago: the start of that N-day gap window, bounded by
    ///   the retention window, so days missed while the app was closed are
    ///   additively backfilled.
    static func gapScanStart(
        gapDays: Int?,
        requestedCoverageDays: Int,
        now: Date,
        calendar: Calendar) -> Date
    {
        let todayStart = calendar.startOfDay(for: now)
        let catchUpDays = min(max(1, gapDays ?? 1), requestedCoverageDays)
        guard catchUpDays > 1 else { return todayStart }
        let start = calendar.date(byAdding: .day, value: -(catchUpDays - 1), to: todayStart) ?? todayStart
        return calendar.startOfDay(for: start)
    }

    private static func cachedDailies(from entries: [UsageLedgerEntry]) -> [CachedDaily] {
        struct Bucket {
            var input = 0
            var output = 0
            var cacheCreate = 0
            var cacheRead = 0
            var cost = 0.0
            var requests = 0
            var models = Set<String>()
        }

        var buckets: [String: Bucket] = [:]
        for entry in entries {
            let key = LedgerCache.dayKey(for: entry.timestamp)
            var bucket = buckets[key] ?? Bucket()
            bucket.input += entry.inputTokens
            bucket.output += entry.outputTokens
            bucket.cacheCreate += entry.cacheCreationTokens
            bucket.cacheRead += entry.cacheReadTokens
            bucket.cost += entry.costUSD ?? 0
            bucket.requests += 1
            if let model = entry.model { bucket.models.insert(model) }
            buckets[key] = bucket
        }
        return buckets.map { dayKey, bucket in
            CachedDaily(
                dayKey: dayKey,
                inputTokens: bucket.input,
                outputTokens: bucket.output,
                cacheCreationTokens: bucket.cacheCreate,
                cacheReadTokens: bucket.cacheRead,
                costUSD: bucket.cost > 0 ? bucket.cost : nil,
                requestCount: bucket.requests,
                // Sorted for determinism: Set order varies across launches, and
                // `mergeDailies` detects changed days by CachedDaily equality —
                // an unstable order made every multi-model day look "changed"
                // and re-archive on each refresh.
                modelsUsed: bucket.models.sorted())
        }
    }
}
