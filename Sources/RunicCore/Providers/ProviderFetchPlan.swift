import Foundation

public enum ProviderRuntime: Sendable {
    case app
    case cli
}

public enum ProviderSourceMode: String, CaseIterable, Sendable {
    case auto
    case web
    case api
    case cli
    case oauth

    public var usesWeb: Bool {
        self == .auto || self == .web
    }
}

public struct ProviderFetchContext: Sendable {
    public let runtime: ProviderRuntime
    public let sourceMode: ProviderSourceMode
    public let includeCredits: Bool
    public let webTimeout: TimeInterval
    public let webDebugDumpHTML: Bool
    public let verbose: Bool
    public let env: [String: String]
    public let settings: ProviderSettingsSnapshot?
    public let fetcher: UsageFetcher
    public let claudeFetcher: any ClaudeUsageFetching
    /// The account this fetch is for; nil means the kind's default account.
    public let account: AccountID?
    /// Where that account's credential lives; nil means the kind's historical
    /// path (keychain item, environment, vendor default directories).
    public let credential: CredentialRef?

    public init(
        runtime: ProviderRuntime,
        sourceMode: ProviderSourceMode,
        includeCredits: Bool,
        webTimeout: TimeInterval,
        webDebugDumpHTML: Bool,
        verbose: Bool,
        env: [String: String],
        settings: ProviderSettingsSnapshot?,
        fetcher: UsageFetcher,
        claudeFetcher: any ClaudeUsageFetching,
        account: AccountID? = nil,
        credential: CredentialRef? = nil)
    {
        self.runtime = runtime
        self.sourceMode = sourceMode
        self.includeCredits = includeCredits
        self.webTimeout = webTimeout
        self.webDebugDumpHTML = webDebugDumpHTML
        self.verbose = verbose
        self.env = env
        self.settings = settings
        self.fetcher = fetcher
        self.claudeFetcher = claudeFetcher
        self.account = account
        self.credential = credential
    }

    /// The API credential for this fetch's account of `kind`: the account's own
    /// keychain item, or for the default account the kind's historical keychain
    /// item and environment variables.
    public func credential(for kind: UsageProvider) -> ProviderTokenResolution? {
        ProviderTokenResolver.credentialResolution(
            for: self.account ?? kind.defaultAccount, environment: self.env)
    }
}

public struct ProviderFetchResult: Sendable {
    public let usage: UsageSnapshot
    public let credits: CreditsSnapshot?
    public let dashboard: OpenAIDashboardSnapshot?
    public let sourceLabel: String
    public let strategyID: String
    public let strategyKind: ProviderFetchKind

    public init(
        usage: UsageSnapshot,
        credits: CreditsSnapshot?,
        dashboard: OpenAIDashboardSnapshot?,
        sourceLabel: String,
        strategyID: String,
        strategyKind: ProviderFetchKind)
    {
        self.usage = usage
        self.credits = credits
        self.dashboard = dashboard
        self.sourceLabel = sourceLabel
        self.strategyID = strategyID
        self.strategyKind = strategyKind
    }
}

public struct ProviderFetchAttempt: Sendable {
    public let strategyID: String
    public let kind: ProviderFetchKind
    public let wasAvailable: Bool
    public let errorDescription: String?

    public init(strategyID: String, kind: ProviderFetchKind, wasAvailable: Bool, errorDescription: String?) {
        self.strategyID = strategyID
        self.kind = kind
        self.wasAvailable = wasAvailable
        self.errorDescription = errorDescription
    }
}

public struct ProviderFetchOutcome: @unchecked Sendable {
    public let result: Result<ProviderFetchResult, Error>
    public let attempts: [ProviderFetchAttempt]

    public init(result: Result<ProviderFetchResult, Error>, attempts: [ProviderFetchAttempt]) {
        self.result = result
        self.attempts = attempts
    }
}

public enum ProviderFetchError: LocalizedError, Sendable {
    case noAvailableStrategy(UsageProvider)
    case missingCredentials
    case strategyTimeout(
        provider: UsageProvider,
        strategyID: String,
        timeoutSeconds: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case let .noAvailableStrategy(provider):
            if provider == .copilot {
                return "No available fetch strategy for copilot. Add `COPILOT_API_TOKEN`, " +
                    "`GITHUB_TOKEN`, or `GH_TOKEN`, " +
                    "or configure GitHub CLI (`GH_CONFIG_DIR` / `~/.config/gh`). " +
                    "You can also sign in from Runic Copilot settings or keep VS Code signed in " +
                    "with accessible keychain secrets."
            }
            if provider == .claude {
                return "No non-interactive Claude credentials found. " +
                    "If you signed in again with `claude /login`, press the reload button (↻) on Claude " +
                    "in Settings → Providers so Runic can re-read the new token (one Keychain prompt)."
            }
            if provider == .ollamacloud {
                return "Ollama Cloud API key not found. Add it in Settings → Providers → Ollama Cloud " +
                    "(or export OLLAMA_API_KEY)."
            }
            if provider == .siliconflowCN {
                return "Not signed in to cloud.siliconflow.cn and no API key. Sign in there in your browser " +
                    "for the balance, or add a key in Settings → Providers → SiliconFlow (China)."
            }
            if provider == .siliconflow {
                return "Not signed in to cloud.siliconflow.com and no API key. Sign in there in your browser " +
                    "for the balance, or add a key in Settings → Providers → SiliconFlow."
            }
            return "No available fetch strategy for \(provider.rawValue)."
        case .missingCredentials:
            return "Missing or invalid credentials."
        case let .strategyTimeout(provider, strategyID, timeoutSeconds):
            return "Fetch strategy \(strategyID) for \(provider.rawValue) timed out after " +
                "\(String(format: "%.1f", timeoutSeconds))s."
        }
    }
}

public enum ProviderFetchKind: Sendable {
    case cli
    case api
    case web
    case oauth
    case apiToken
    case localProbe
    case webDashboard
}

public protocol ProviderFetchStrategy: Sendable {
    var id: String { get }
    var kind: ProviderFetchKind { get }
    func isAvailable(_ context: ProviderFetchContext) async -> Bool
    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult
    func shouldFallback(on error: Error, context: ProviderFetchContext) -> Bool
}

extension ProviderFetchStrategy {
    public func makeResult(
        usage: UsageSnapshot,
        credits: CreditsSnapshot? = nil,
        dashboard: OpenAIDashboardSnapshot? = nil,
        sourceLabel: String) -> ProviderFetchResult
    {
        ProviderFetchResult(
            usage: usage,
            credits: credits,
            dashboard: dashboard,
            sourceLabel: sourceLabel,
            strategyID: self.id,
            strategyKind: self.kind)
    }
}

public struct ProviderFetchPipeline: Sendable {
    public let resolveStrategies: @Sendable (ProviderFetchContext) async -> [any ProviderFetchStrategy]
    public let strategyTimeout: TimeInterval

    public init(
        resolveStrategies: @escaping @Sendable (ProviderFetchContext) async -> [any ProviderFetchStrategy],
        strategyTimeout: TimeInterval = 45)
    {
        self.resolveStrategies = resolveStrategies
        self.strategyTimeout = strategyTimeout
    }

    /// Strategy kinds an added account may use. CLI, PTY, web-cookie and local
    /// probes read the machine's default login, not the account's, and a CLI
    /// pointed at a fresh home sits in onboarding until the timeout; an added
    /// account therefore uses only what its own credential can serve.
    public static let addedAccountKinds: Set<ProviderFetchKind> = [.oauth, .apiToken, .api]

    public func fetch(context: ProviderFetchContext, provider: UsageProvider) async -> ProviderFetchOutcome {
        var strategies = await self.resolveStrategies(context)
        if let account = context.account, !account.isDefault {
            strategies = strategies.filter { Self.addedAccountKinds.contains($0.kind) }
        }
        var attempts: [ProviderFetchAttempt] = []
        attempts.reserveCapacity(strategies.count)

        for strategy in strategies {
            let available = await strategy.isAvailable(context)
            guard available else {
                attempts.append(ProviderFetchAttempt(
                    strategyID: strategy.id,
                    kind: strategy.kind,
                    wasAvailable: false,
                    errorDescription: nil))
                continue
            }

            do {
                let result = try await self.fetchWithTimeout(
                    strategy: strategy,
                    context: context,
                    provider: provider)
                attempts.append(ProviderFetchAttempt(
                    strategyID: strategy.id,
                    kind: strategy.kind,
                    wasAvailable: true,
                    errorDescription: nil))
                return ProviderFetchOutcome(result: .success(result), attempts: attempts)
            } catch {
                attempts.append(ProviderFetchAttempt(
                    strategyID: strategy.id,
                    kind: strategy.kind,
                    wasAvailable: true,
                    errorDescription: error.localizedDescription))
                if strategy.shouldFallback(on: error, context: context) {
                    continue
                }
                return ProviderFetchOutcome(result: .failure(error), attempts: attempts)
            }
        }

        let error = ProviderFetchError.noAvailableStrategy(provider)
        return ProviderFetchOutcome(result: .failure(error), attempts: attempts)
    }

    private func fetchWithTimeout(
        strategy: any ProviderFetchStrategy,
        context: ProviderFetchContext,
        provider: UsageProvider) async throws -> ProviderFetchResult
    {
        try await withThrowingTaskGroup(of: ProviderFetchResult.self) { group in
            group.addTask {
                try await strategy.fetch(context)
            }

            group.addTask {
                try await Task.sleep(for: .seconds(self.strategyTimeout))
                throw ProviderFetchError.strategyTimeout(
                    provider: provider,
                    strategyID: strategy.id,
                    timeoutSeconds: self.strategyTimeout)
            }

            defer { group.cancelAll() }

            guard let result = try await group.next() else {
                throw CancellationError()
            }
            return result
        }
    }
}

public struct ProviderFetchPlan: Sendable {
    public let sourceModes: Set<ProviderSourceMode>
    public let pipeline: ProviderFetchPipeline

    public init(sourceModes: Set<ProviderSourceMode>, pipeline: ProviderFetchPipeline) {
        self.sourceModes = sourceModes
        self.pipeline = pipeline
    }

    public func fetchOutcome(context: ProviderFetchContext, provider: UsageProvider) async -> ProviderFetchOutcome {
        await self.pipeline.fetch(context: context, provider: provider)
    }
}
