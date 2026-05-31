import Foundation
import RunicCore

enum ProviderStatusIndicator: String {
    case none
    case minor
    case major
    case critical
    case maintenance
    case unknown

    var hasIssue: Bool {
        switch self {
        case .none: false
        default: true
        }
    }

    var label: String {
        switch self {
        case .none: "Operational"
        case .minor: "Partial outage"
        case .major: "Major outage"
        case .critical: "Critical issue"
        case .maintenance: "Maintenance"
        case .unknown: "Status unknown"
        }
    }
}

enum RefreshTrigger: String {
    case manual
    case menuOpen
    case autoTimer
    case settingsChange
    case login
    case resume
    case startup

    var isAuto: Bool {
        switch self {
        case .manual, .login: false
        case .menuOpen, .autoTimer, .settingsChange, .resume, .startup: true
        }
    }

    var menuLabel: String {
        switch self {
        case .manual: "Manual"
        case .menuOpen: "Menu open"
        case .autoTimer: "Auto"
        case .settingsChange: "Settings"
        case .login: "Login"
        case .resume: "Resume"
        case .startup: "Startup"
        }
    }
}

actor UsageLedgerOTelRelay {
    static let shared = UsageLedgerOTelRelay()

    private struct FileIdentity: Hashable {
        let path: String
        let size: Int
        let modifiedAt: TimeInterval
    }

    private struct Key: Hashable {
        let files: [FileIdentity]
        let minTimestamp: TimeInterval?
        let options: OTelGenAIIngestionOptions
    }

    private var cache: [Key: (loadedAt: Date, entries: [UsageLedgerEntry])] = [:]
    private var inFlight: [Key: Task<[UsageLedgerEntry], Error>] = [:]
    private let cacheTTL: TimeInterval = 5

    func loadEntries(
        files: [URL],
        options: OTelGenAIIngestionOptions,
        minTimestamp: Date?) async throws -> [UsageLedgerEntry]
    {
        guard !files.isEmpty else { return [] }
        let key = Key(
            files: files.map(Self.identity(for:)).sorted { $0.path < $1.path },
            minTimestamp: minTimestamp?.timeIntervalSince1970,
            options: options)
        let now = Date()
        if let cached = self.cache[key], now.timeIntervalSince(cached.loadedAt) <= self.cacheTTL {
            return cached.entries
        }
        if let task = self.inFlight[key] {
            return try await task.value
        }

        let task = Task.detached(priority: .utility) {
            try await OTelGenAIFileLedgerSource(
                files: files,
                options: options,
                minTimestamp: minTimestamp)
                .loadEntries()
        }
        self.inFlight[key] = task
        do {
            let entries = try await task.value
            self.inFlight[key] = nil
            self.cache[key] = (now, entries)
            self.pruneCache(now: now)
            return entries
        } catch {
            self.inFlight[key] = nil
            throw error
        }
    }

    private static func identity(for file: URL) -> FileIdentity {
        let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return FileIdentity(
            path: file.standardizedFileURL.path,
            size: values?.fileSize ?? 0,
            modifiedAt: values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
    }

    private func pruneCache(now: Date) {
        self.cache = self.cache.filter { now.timeIntervalSince($0.value.loadedAt) <= self.cacheTTL }
    }
}

enum AutoRefreshSuspensionReason: String {
    case systemSleep
    case screenSleep
    case sessionInactive

    var label: String {
        switch self {
        case .systemSleep: "Sleeping"
        case .screenSleep: "Display asleep"
        case .sessionInactive: "Session inactive"
        }
    }
}

enum AutoRefreshDisableReason: String {
    case idle
    case systemSleep
    case screenSleep
    case sessionInactive

    var label: String {
        switch self {
        case .idle: "idle"
        case .systemSleep: "sleep"
        case .screenSleep: "display sleep"
        case .sessionInactive: "lock"
        }
    }
}

struct ProviderStatus {
    let indicator: ProviderStatusIndicator
    let description: String?
    let updatedAt: Date?
}

/// Tracks consecutive failures so we can ignore a single flake when we previously had fresh data.
struct ConsecutiveFailureGate {
    private(set) var streak: Int = 0

    mutating func recordSuccess() {
        self.streak = 0
    }

    mutating func reset() {
        self.streak = 0
    }

    /// Returns true when the caller should surface the error to the UI.
    mutating func shouldSurfaceError(onFailureWithPriorData hadPriorData: Bool) -> Bool {
        self.streak += 1
        if hadPriorData, self.streak == 1 { return false }
        return true
    }
}

struct ProviderHistoryDaySnapshot: Hashable, Identifiable {
    let dayStart: Date
    let totals: UsageLedgerTotals
    let requestCount: Int
    let modelsUsed: [String]
    let topModel: UsageLedgerModelSummary?
    let topProject: UsageLedgerProjectSummary?
    let modelSummaries: [UsageLedgerModelSummary]
    let projectSummaries: [UsageLedgerProjectSummary]

    var id: Date {
        self.dayStart
    }
}

struct ProviderHistoryMonthSnapshot: Hashable {
    let provider: UsageProvider
    let monthStart: Date
    let generatedAt: Date
    let days: [ProviderHistoryDaySnapshot]
    let isSupported: Bool
    let note: String?
    let error: String?
}

struct UsageDebugCredentialSource: Sendable {
    let label: String
    let resolution: @Sendable () -> ProviderTokenResolution?
}

enum UsageDebugCredentialCatalog {
    static let tokenSourcesByProvider: [UsageProvider: [UsageDebugCredentialSource]] = [
        .zai: [
            .init(label: "zai", resolution: { ProviderTokenResolver.zaiResolution() }),
        ],
        .copilot: [
            .init(label: "copilot", resolution: { ProviderTokenResolver.copilotResolution() }),
        ],
        .minimax: [
            .init(label: "minimax.api", resolution: { ProviderTokenResolver.minimaxApiKeyResolution() }),
            .init(label: "minimax.cookie", resolution: { ProviderTokenResolver.minimaxCookieHeaderResolution() }),
            .init(label: "minimax.group", resolution: { ProviderTokenResolver.minimaxGroupResolution() }),
        ],
        .openrouter: [
            .init(label: "openrouter", resolution: { ProviderTokenResolver.openRouterResolution() }),
        ],
        .vercelai: [
            .init(label: "vercelai", resolution: { ProviderTokenResolver.vercelAIResolution() }),
        ],
        .groq: [
            .init(label: "groq", resolution: { ProviderTokenResolver.groqResolution() }),
        ],
        .deepseek: [
            .init(label: "deepseek", resolution: { ProviderTokenResolver.deepSeekResolution() }),
        ],
        .fireworks: [
            .init(label: "fireworks", resolution: { ProviderTokenResolver.fireworksResolution() }),
        ],
        .mistral: [
            .init(label: "mistral", resolution: { ProviderTokenResolver.mistralResolution() }),
        ],
        .perplexity: [
            .init(label: "perplexity", resolution: { ProviderTokenResolver.perplexityResolution() }),
        ],
        .kimi: [
            .init(label: "kimi", resolution: { ProviderTokenResolver.kimiResolution() }),
        ],
        .auggie: [
            .init(label: "auggie", resolution: { ProviderTokenResolver.auggieResolution() }),
        ],
        .together: [
            .init(label: "together", resolution: { ProviderTokenResolver.togetherResolution() }),
        ],
        .cohere: [
            .init(label: "cohere", resolution: { ProviderTokenResolver.cohereResolution() }),
        ],
        .xai: [
            .init(label: "xai", resolution: { ProviderTokenResolver.xaiResolution() }),
        ],
        .cerebras: [
            .init(label: "cerebras", resolution: { ProviderTokenResolver.cerebrasResolution() }),
        ],
        .sambanova: [
            .init(label: "sambanova", resolution: { ProviderTokenResolver.sambaNovaResolution() }),
        ],
        .qwen: [
            .init(label: "qwen", resolution: { ProviderTokenResolver.qwenResolution() }),
        ],
    ]
}

extension Dictionary where Value: Collection {
    mutating func setNonEmpty(_ value: Value?, forKey key: Key) {
        guard let value, !value.isEmpty else {
            self.removeValue(forKey: key)
            return
        }
        self[key] = value
    }
}
