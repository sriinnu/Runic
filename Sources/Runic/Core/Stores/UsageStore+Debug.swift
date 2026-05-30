import AppKit
import Foundation
import RunicCore

extension UsageStore {
    func debugClaudeDump() async -> String {
        await ClaudeStatusProbe.latestDumps()
    }

    func debugLog(for provider: UsageProvider) async -> String {
        if let cached = self.probeLogs[provider], !cached.isEmpty {
            return cached
        }

        let settingsSnapshot = self.providerSettingsSnapshot()
        let debugContext = self.providerDebugContext(settings: settingsSnapshot)
        let claudeWebExtrasEnabled = self.settings.claudeWebExtrasEnabled
        let claudeUsageDataSource = self.settings.claudeUsageDataSource
        let claudeDebugMenuEnabled = self.settings.debugMenuEnabled

        return await Task.detached(priority: .utility) { () -> String in
            if provider == .codex {
                return await self.debugCodexLog()
            }
            if provider == .claude {
                return await self.debugClaudeLog(
                    debugMenuEnabled: claudeDebugMenuEnabled,
                    selectedDataSource: claudeUsageDataSource,
                    webExtrasEnabled: claudeWebExtrasEnabled)
            }
            if provider == .zai {
                return await self.debugZaiTokenLog()
            }
            return await self.debugProviderProbeLog(
                provider: provider,
                context: debugContext,
                settings: settingsSnapshot)
        }.value
    }

    func debugDumpClaude() async {
        let output = await self.claudeFetcher.debugRawProbe(model: "sonnet")
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("runic-claude-probe.txt")
        try? output.write(to: url, atomically: true, encoding: .utf8)
        await MainActor.run {
            let snippet = String(output.prefix(180)).replacingOccurrences(of: "\n", with: " ")
            self.errors[.claude] = "[Claude] \(snippet) (saved: \(url.path))"
            NSWorkspace.shared.open(url)
        }
    }

    func dumpLog(toFileFor provider: UsageProvider) async -> URL? {
        let text = await self.debugLog(for: provider)
        let filename = "runic-\(provider.rawValue)-probe.txt"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            _ = await MainActor.run { NSWorkspace.shared.open(url) }
            return url
        } catch {
            await MainActor.run {
                self.errors[provider] = "Failed to save log: \(error.localizedDescription)"
            }
            return nil
        }
    }

    func detectVersions() {
        Task.detached { [claudeFetcher] in
            let codexVer = Self.readCLI("codex", args: ["-s", "read-only", "-a", "untrusted", "--version"])
            let claudeVer = claudeFetcher.detectVersion()
            let geminiVer = Self.readCLI("gemini", args: ["--version"])
            let antigravityVer = await AntigravityStatusProbe.detectVersion()
            await MainActor.run {
                self.codexVersion = codexVer
                self.claudeVersion = claudeVer
                self.geminiVersion = geminiVer
                self.zaiVersion = nil
                self.antigravityVersion = antigravityVer
            }
        }
    }

    func refreshPathDebugInfo() {
        self.pathDebugInfo = PathBuilder.debugSnapshot(purposes: [.rpc, .tty, .nodeTooling])
    }

    /// For demo/testing: drop the snapshot so the loading animation plays, then restore the last snapshot.
    func replayLoadingAnimation(duration: TimeInterval = 3) {
        let current = self.preferredSnapshot
        self.snapshots.removeAll()
        self.debugForceAnimation = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if let current, let provider = self.enabledProviders().first {
                self.snapshots[provider] = current
            }
            self.debugForceAnimation = false
        }
    }

    nonisolated func trackLatency(
        provider: UsageProvider,
        providerLabel: String? = nil,
        requestID: String,
        startTime: Date,
        endTime: Date,
        success: Bool) async
    {
        guard let storage = self.performanceStorage else { return }
        guard Self.localPerformanceTrackingEnabled() else { return }

        let metric = LatencyMetric(
            id: UUID().uuidString,
            requestID: requestID,
            provider: provider,
            providerLabel: providerLabel,
            model: nil,
            startTime: startTime,
            endTime: endTime,
            durationMs: Int(endTime.timeIntervalSince(startTime) * 1000),
            success: success,
            createdAt: Date())

        try? await storage.save(latency: metric)
    }

    nonisolated func trackError(provider: UsageProvider, providerLabel: String? = nil, error: Error) async {
        guard let storage = self.performanceStorage else { return }
        guard Self.localPerformanceTrackingEnabled() else { return }

        let errorType = self.classifyError(error)
        let errorEvent = ErrorEvent(
            id: UUID().uuidString,
            provider: provider,
            providerLabel: providerLabel,
            errorType: errorType,
            errorMessage: error.localizedDescription,
            retryCount: 0,
            timestamp: Date())

        try? await storage.save(error: errorEvent)
    }

    nonisolated static func customProviderMetricLabel(_ config: CustomProviderConfig) -> String {
        let raw = config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? config.id
            : config.name
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}._-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        return "custom:\(normalized.isEmpty ? config.id : normalized)"
    }

    private func providerSettingsSnapshot() -> ProviderSettingsSnapshot {
        ProviderSettingsSnapshot(
            debugMenuEnabled: self.settings.debugMenuEnabled,
            codex: ProviderSettingsSnapshot.CodexProviderSettings(
                usageDataSource: self.settings.codexUsageDataSource),
            claude: ProviderSettingsSnapshot.ClaudeProviderSettings(
                usageDataSource: self.settings.claudeUsageDataSource,
                webExtrasEnabled: self.settings.claudeWebExtrasEnabled),
            zai: ProviderSettingsSnapshot.ZaiProviderSettings(),
            copilot: ProviderSettingsSnapshot.CopilotProviderSettings(
                apiToken: self.providerSettingValue(self.settings.copilotAPIToken)),
            azure: ProviderSettingsSnapshot.AzureProviderSettings(
                apiToken: self.providerSettingValue(self.settings.azureOpenAIAPIToken),
                endpoint: self.providerSettingValue(self.settings.azureOpenAIEndpoint),
                deployment: self.providerSettingValue(self.settings.azureOpenAIDeployment),
                apiVersion: self.providerSettingValue(self.settings.azureOpenAIAPIVersion)),
            bedrock: ProviderSettingsSnapshot.BedrockProviderSettings(
                region: self.providerSettingValue(self.settings.bedrockRegion),
                profile: self.providerSettingValue(self.settings.bedrockAWSProfile),
                modelID: self.providerSettingValue(self.settings.bedrockModelID)),
            vertexai: ProviderSettingsSnapshot.VertexAIProviderSettings(
                project: self.providerSettingValue(self.settings.vertexaiProject),
                location: self.providerSettingValue(self.settings.vertexaiLocation)))
    }

    private func providerSettingValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func providerDebugContext(settings: ProviderSettingsSnapshot) -> ProviderFetchContext {
        ProviderFetchContext(
            runtime: .app,
            sourceMode: .auto,
            includeCredits: true,
            webTimeout: 15,
            webDebugDumpHTML: false,
            verbose: false,
            env: ProcessInfo.processInfo.environment,
            settings: settings,
            fetcher: self.codexFetcher,
            claudeFetcher: self.claudeFetcher)
    }

    private nonisolated func debugCodexLog() async -> String {
        let raw = await self.codexFetcher.debugRawRateLimits()
        await self.cacheProbeLog(raw, for: .codex)
        return raw
    }

    private nonisolated func debugClaudeLog(
        debugMenuEnabled: Bool,
        selectedDataSource: ClaudeUsageDataSource,
        webExtrasEnabled: Bool) async -> String
    {
        let text = await self.runWithTimeout(seconds: 15) {
            var lines: [String] = []
            let hasKey = ClaudeWebAPIFetcher.hasSessionKey { msg in lines.append(msg) }
            let hasOAuthCredentials = (try? ClaudeOAuthCredentialsStore.load()) != nil

            let strategy = ClaudeProviderDescriptor.resolveUsageStrategy(
                debugMenuEnabled: debugMenuEnabled,
                selectedDataSource: selectedDataSource,
                webExtrasEnabled: webExtrasEnabled,
                hasWebSession: hasKey,
                hasOAuthCredentials: hasOAuthCredentials)
            let automaticCLIFallbackSkipped = strategy.dataSource == .cli && !debugMenuEnabled

            if !automaticCLIFallbackSkipped {
                await MainActor.run {
                    if self.settings.claudeUsageDataSource != strategy.dataSource {
                        self.settings.claudeUsageDataSource = strategy.dataSource
                    }
                }
            }

            lines.append("strategy=\(strategy.dataSource.rawValue)")
            lines.append("hasSessionKey=\(hasKey)")
            lines.append("hasOAuthCredentials=\(hasOAuthCredentials)")
            if strategy.useWebExtras {
                lines.append("web_extras=enabled")
            }
            if automaticCLIFallbackSkipped {
                lines.append("cli_auto_fallback=skipped_to_avoid_password_prompt")
                lines.append("")
                lines.append(
                    "Enable the Debug menu and choose Claude CLI source only " +
                        "when you want Runic to launch the Claude CLI explicitly.")
                return lines.joined(separator: "\n")
            }
            lines.append("")

            return await self.debugClaudeSelectedSourceLines(
                strategy: strategy,
                existingLines: lines)
        }
        await self.cacheProbeLog(text, for: .claude)
        return text
    }

    private nonisolated func debugClaudeSelectedSourceLines(
        strategy: ClaudeUsageStrategy,
        existingLines: [String]) async -> String
    {
        var lines = existingLines
        switch strategy.dataSource {
        case .web:
            do {
                let web = try await ClaudeWebAPIFetcher.fetchUsage { msg in lines.append(msg) }
                lines.append("")
                lines.append("Web API summary:")

                let sessionReset = web.sessionResetsAt?.description ?? "nil"
                lines.append("session_used=\(web.sessionPercentUsed)% resetsAt=\(sessionReset)")

                if let weekly = web.weeklyPercentUsed {
                    let weeklyReset = web.weeklyResetsAt?.description ?? "nil"
                    lines.append("weekly_used=\(weekly)% resetsAt=\(weeklyReset)")
                } else {
                    lines.append("weekly_used=nil")
                }

                lines.append("opus_used=\(web.opusPercentUsed?.description ?? "nil")")

                if let extra = web.extraUsageCost {
                    let resetsAt = extra.resetsAt?.description ?? "nil"
                    let period = extra.period ?? "nil"
                    let line =
                        "extra_usage used=\(extra.used) limit=\(extra.limit) " +
                            "currency=\(extra.currencyCode) period=\(period) resetsAt=\(resetsAt)"
                    lines.append(line)
                } else {
                    lines.append("extra_usage=nil")
                }
            } catch {
                lines.append("Web API failed: \(error.localizedDescription)")
            }
        case .cli:
            let cli = await self.claudeFetcher.debugRawProbe(model: "sonnet")
            lines.append(cli)
        case .oauth:
            lines.append("OAuth source selected.")
        }
        return lines.joined(separator: "\n")
    }

    private nonisolated func debugZaiTokenLog() async -> String {
        let text = self.debugTokenSummary(
            provider: "zai",
            resolution: ProviderTokenResolver.zaiResolution())
        await self.cacheProbeLog(text, for: .zai)
        return text
    }

    private nonisolated func debugProviderProbeLog(
        provider: UsageProvider,
        context: ProviderFetchContext,
        settings: ProviderSettingsSnapshot) async -> String
    {
        let text = await self.runWithTimeout(seconds: 15) {
            await self.debugProviderProbe(
                provider: provider,
                context: context,
                settings: settings)
        }
        await self.cacheProbeLog(text, for: provider)
        return text
    }

    private nonisolated func cacheProbeLog(_ text: String, for provider: UsageProvider) async {
        await MainActor.run {
            self.probeLogs[provider] = text
        }
    }

    private nonisolated func debugProviderProbe(
        provider: UsageProvider,
        context: ProviderFetchContext,
        settings: ProviderSettingsSnapshot) async -> String
    {
        var lines = [
            "provider=\(provider.rawValue)",
        ]

        lines.append(contentsOf: self.debugCredentialLines(for: provider, settings: settings))
        let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
        let outcome = await descriptor.fetchOutcome(context: context)
        lines.append(contentsOf: self.debugAttemptLines(from: outcome.attempts))

        switch outcome.result {
        case let .success(result):
            lines.append("result=success")
            lines.append("strategy_id=\(result.strategyID)")
            lines.append("strategy_kind=\(self.debugStrategyKindLabel(result.strategyKind))")
            lines.append("source_label=\(result.sourceLabel)")
            lines.append(contentsOf: self.debugUsageSummary(result.usage))
        case let .failure(error):
            lines.append("result=failure")
            lines.append("error=\(error.localizedDescription)")
        }

        return lines.joined(separator: "\n")
    }

    private nonisolated func debugCredentialLines(
        for provider: UsageProvider,
        settings: ProviderSettingsSnapshot) -> [String]
    {
        if let tokenSources = UsageDebugCredentialCatalog.tokenSourcesByProvider[provider] {
            return tokenSources.map { source in
                self.debugTokenSummary(provider: source.label, resolution: source.resolution())
            }
        }
        return self.debugProviderSettingLines(for: provider, settings: settings)
    }

    private nonisolated func debugProviderSettingLines(
        for provider: UsageProvider,
        settings: ProviderSettingsSnapshot) -> [String]
    {
        switch provider {
        case .azure:
            var lines: [String] = [
                "azure.endpoint=\(self.debugFieldValue(settings.azure?.endpoint))",
                "azure.deployment=\(self.debugFieldValue(settings.azure?.deployment))",
                "azure.apiVersion=\(self.debugFieldValue(settings.azure?.apiVersion))",
            ]
            lines.append(self.debugTokenSummary(
                provider: "azure.token",
                resolution: ProviderTokenResolver.azureOpenAIResolution()))
            return lines
        case .bedrock:
            return [
                "bedrock.region=\(self.debugFieldValue(settings.bedrock?.region))",
                "bedrock.profile=\(self.debugFieldValue(settings.bedrock?.profile))",
                "bedrock.model_filter=\(self.debugFieldValue(settings.bedrock?.modelID))",
            ]
        case .vertexai:
            return [
                "vertexai.project=\(self.debugFieldValue(settings.vertexai?.project))",
                "vertexai.location=\(self.debugFieldValue(settings.vertexai?.location))",
            ]
        case .gemini:
            return [
                "gemini.authType=\(GeminiStatusProbe.currentAuthType().rawValue)",
            ]
        case .localLLM:
            return [
                "local_llm.discovery=ollama:11434,lmstudio:1234,vllm:8000,llama.cpp:8080,openwebui:3000",
                "local_llm.api_cost=not_applicable",
            ]
        case .antigravity, .cursor, .factory:
            return ["credentials=provider_internal"]
        default:
            return []
        }
    }

    private nonisolated func debugAttemptLines(from attempts: [ProviderFetchAttempt]) -> [String] {
        var lines: [String] = []
        if attempts.isEmpty {
            lines.append("attempts=none")
            return lines
        }

        let attemptSummary = attempts.enumerated().map { index, attempt in
            let error = attempt.errorDescription ?? "nil"
            return [
                "attempt\(index + 1):",
                "id=\(attempt.strategyID)",
                "kind=\(attempt.kind)",
                "available=\(attempt.wasAvailable)",
                "error=\(error)",
            ].joined(separator: " ")
        }
        lines.append("attempts=\(attempts.count)")
        lines.append(contentsOf: attemptSummary)
        return lines
    }

    private nonisolated func debugUsageSummary(_ snapshot: UsageSnapshot) -> [String] {
        var lines: [String] = []
        lines.append(self.debugRateWindowSummary(label: "primary", window: snapshot.primary))
        if let secondary = snapshot.secondary {
            lines.append(self.debugRateWindowSummary(label: "secondary", window: secondary))
        }
        if let tertiary = snapshot.tertiary {
            lines.append(self.debugRateWindowSummary(label: "tertiary", window: tertiary))
        }
        if let identity = snapshot.identity {
            lines.append("identity.email=\(identity.accountEmail ?? "nil")")
            lines.append("identity.organization=\(identity.accountOrganization ?? "nil")")
            lines.append("identity.loginMethod=\(identity.loginMethod ?? "nil")")
        }
        if let providerCost = snapshot.providerCost {
            let resetsAt = providerCost.resetsAt?.description ?? "nil"
            lines.append(
                "provider_cost.used=\(providerCost.used) limit=\(providerCost.limit) " +
                    "currency=\(providerCost.currencyCode) " +
                    "period=\(providerCost.period ?? "nil") resetsAt=\(resetsAt)")
        }
        return lines
    }

    private nonisolated func debugRateWindowSummary(label: String, window: RateWindow) -> String {
        let resetsAt = window.resetsAt?.description ?? "nil"
        let windowMinutes = window.windowMinutes.map { "\($0)m" } ?? "nil"
        let resetDescription = window.resetDescription ?? "nil"
        let windowLabel = window.label ?? "nil"
        let used = String(format: "%.2f", window.usedPercent)
        let remaining = String(format: "%.2f", window.remainingPercent)
        return [
            "\(label).usedPercent=\(used)",
            "remainingPercent=\(remaining)",
            "window=\(windowMinutes)",
            "resetsAt=\(resetsAt)",
            "label=\(windowLabel)",
            "desc=\(resetDescription)",
        ].joined(separator: " ")
    }

    private nonisolated func debugTokenSummary(provider: String, resolution: ProviderTokenResolution?) -> String {
        let tokenState = resolution == nil ? "missing" : "present"
        let source = resolution.flatMap { r in
            let key = r.sourceKey.map { "(\($0))" } ?? ""
            return "\(r.source.rawValue)\(key)"
        } ?? "nil"
        let length = resolution?.token.count ?? 0
        return "\(provider)=\(tokenState) source=\(source) length=\(length)"
    }

    private nonisolated func debugFieldValue(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "missing" : trimmed
    }

    private nonisolated func debugStrategyKindLabel(_ kind: ProviderFetchKind) -> String {
        switch kind {
        case .cli: "cli"
        case .api: "api"
        case .web: "web"
        case .oauth: "oauth"
        case .apiToken: "apiToken"
        case .localProbe: "localProbe"
        case .webDashboard: "webDashboard"
        }
    }

    private nonisolated static func readCLI(_ cmd: String, args: [String]) -> String? {
        let env = ProcessInfo.processInfo.environment
        var pathEnv = env
        pathEnv["PATH"] = PathBuilder.effectivePATH(purposes: [.rpc, .tty, .nodeTooling], env: env)
        let loginPATH = LoginShellPathCache.shared.current

        let resolved: String = switch cmd {
        case "codex":
            BinaryLocator.resolveCodexBinary(env: env, loginPATH: loginPATH) ?? cmd
        case "gemini":
            BinaryLocator.resolveGeminiBinary(env: env, loginPATH: loginPATH) ?? cmd
        default:
            cmd
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [resolved] + args
        process.environment = pathEnv
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty else { return nil }
        return text
    }

    private nonisolated static func localPerformanceTrackingEnabled() -> Bool {
        (UserDefaults.standard.object(forKey: "performanceTrackingEnabled") as? Bool) ?? true
    }

    private nonisolated func classifyError(_ error: Error) -> ErrorType {
        let message = error.localizedDescription.lowercased()

        if message.contains("timed out") || message.contains("timeout") {
            return .timeout
        }

        if message.contains("quota") || message.contains("rate limit") || message.contains("429") {
            return .quota
        }

        if message.contains("auth") || message.contains("unauthorized") ||
            message.contains("401") || message.contains("403")
        {
            return .auth
        }

        if message.contains("network") || message.contains("connection") ||
            message.contains("offline") || message.contains("no internet")
        {
            return .network
        }

        if message.contains("json") || message.contains("decode") || message.contains("parse") {
            return .parsing
        }

        if message.contains("api") || message.contains("server") {
            return .apiError
        }

        return .unknown
    }

    private func runWithTimeout(seconds: Double, operation: @escaping @Sendable () async -> String) async -> String {
        await withTaskGroup(of: String?.self) { group -> String in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let result = await group.next()?.flatMap(\.self)
            group.cancelAll()
            return result ?? "Probe timed out after \(Int(seconds))s"
        }
    }
}
