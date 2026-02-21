import AppKit
import RunicCore

extension StatusItemController {
    // MARK: - Actions reachable from menus

    @objc func refreshNow() {
        Task { await self.store.refresh(trigger: .manual, forceTokenUsage: true) }
    }

    @objc func installUpdate() {
        self.updater.checkForUpdates(nil)
    }

    @objc func openDashboard() {
        let preferred = self.lastMenuProvider
            ?? (self.store.isEnabled(.codex) ? .codex : self.store.enabledProviders().first)

        let provider = preferred ?? .codex
        let meta = self.store.metadata(for: provider)

        // For Claude, route subscription users to claude.ai/settings/usage instead of console billing
        let urlString: String? = if provider == .claude, self.store.isClaudeSubscription() {
            meta.subscriptionDashboardURL ?? meta.dashboardURL
        } else {
            meta.dashboardURL
        }

        guard let urlString, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openCreditsPurchase() {
        let preferred = self.lastMenuProvider
            ?? (self.store.isEnabled(.codex) ? .codex : self.store.enabledProviders().first)
        let provider = preferred ?? .codex
        guard provider == .codex else { return }

        let dashboardURL = self.store.metadata(for: .codex).dashboardURL
        let purchaseURL = Self.sanitizedCreditsPurchaseURL(self.store.openAIDashboard?.creditsPurchaseURL)
        let urlString = purchaseURL ?? dashboardURL
        guard let urlString,
              let url = URL(string: urlString) else { return }

        let autoStart = true
        let accountEmail = self.store.codexAccountEmailForOpenAIDashboard()
        let controller = self.creditsPurchaseWindow ?? OpenAICreditsPurchaseWindowController()
        controller.show(purchaseURL: url, accountEmail: accountEmail, autoStartPurchase: autoStart)
        self.creditsPurchaseWindow = controller
    }

    private static func sanitizedCreditsPurchaseURL(_ raw: String?) -> String? {
        guard let raw, let url = URL(string: raw) else { return nil }
        guard let host = url.host?.lowercased(), host.contains("chatgpt.com") else { return nil }
        let path = url.path.lowercased()
        let allowed = ["settings", "usage", "billing", "credits"]
        guard allowed.contains(where: { path.contains($0) }) else { return nil }
        return url.absoluteString
    }

    @objc func openStatusPage() {
        let preferred = self.lastMenuProvider
            ?? (self.store.isEnabled(.codex) ? .codex : self.store.enabledProviders().first)

        let provider = preferred ?? .codex
        let meta = self.store.metadata(for: provider)
        let urlString = meta.statusPageURL ?? meta.statusLinkURL
        guard let urlString, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openInsightsReport(_ sender: NSMenuItem) {
        let rawProvider = sender.representedObject as? String
        let provider = rawProvider.flatMap(UsageProvider.init(rawValue:)) ?? self.lastMenuProvider ?? .codex
        let days = max(1, self.settings.insightsReportDays)
        Task { [weak self] in
            guard let self else { return }
            let report = await self.buildInsightsReport(provider: provider, days: days)
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard let url = self.writeInsightsReport(report, provider: provider) else { return }
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc func runSwitchAccount(_ sender: NSMenuItem) {
        if self.loginTask != nil {
            self.loginLogger.info("Switch Account tap ignored: login already in-flight")
            print("[Runic] Switch Account ignored (busy)")
            return
        }

        let rawProvider = sender.representedObject as? String
        let provider = rawProvider.flatMap(UsageProvider.init(rawValue:)) ?? self.lastMenuProvider ?? .codex
        self.loginLogger.info("Switch Account tapped", metadata: ["provider": provider.rawValue])
        print("[Runic] Switch Account tapped for provider=\(provider.rawValue)")

        self.loginTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.activeLoginProvider = nil
                self.loginTask = nil
            }
            self.activeLoginProvider = provider
            self.loginPhase = .requesting
            self.loginLogger.info("Starting login task", metadata: ["provider": provider.rawValue])
            print("[Runic] Starting login task for \(provider.rawValue)")

            let shouldRefresh = await self.runLoginFlow(provider: provider)
            if shouldRefresh {
                await self.store.refresh(trigger: .login, forceTokenUsage: true)
                print("[Runic] Triggered refresh after login")
            }
        }
    }

    @objc func showSettingsGeneral() { self.openSettings(tab: .general) }

    @objc func showSettingsAbout() { self.openSettings(tab: .about) }

    func openMenuFromShortcut() {
        if self.shouldMergeIcons {
            self.statusItem.button?.performClick(nil)
            return
        }

        let provider = self.resolvedShortcutProvider()
        let item = self.statusItems[provider] ?? self.statusItem
        item.button?.performClick(nil)
    }

    private func openSettings(tab: PreferencesTab) {
        DispatchQueue.main.async {
            self.preferencesSelection.tab = tab
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(
                name: .runicOpenSettings,
                object: nil,
                userInfo: ["tab": tab.rawValue])
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    @objc func copyError(_ sender: NSMenuItem) {
        if let err = sender.representedObject as? String {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(err, forType: .string)
        }
    }

    private func resolvedShortcutProvider() -> UsageProvider {
        if let last = self.lastMenuProvider, self.isEnabled(last) {
            return last
        }
        if let first = self.store.enabledProviders().first {
            return first
        }
        return .codex
    }

    func presentCodexLoginResult(_ result: CodexLoginRunner.Result) {
        switch result.outcome {
        case .success:
            return
        case .missingBinary:
            self.presentLoginAlert(
                title: "Codex CLI not found",
                message: "Install the Codex CLI (npm i -g @openai/codex) and try again.")
        case let .launchFailed(message):
            self.presentLoginAlert(title: "Could not start codex login", message: message)
        case .timedOut:
            self.presentLoginAlert(
                title: "Codex login timed out",
                message: self.trimmedLoginOutput(result.output))
        case let .failed(status):
            let statusLine = "codex login exited with status \(status)."
            let message = self.trimmedLoginOutput(result.output.isEmpty ? statusLine : result.output)
            self.presentLoginAlert(title: "Codex login failed", message: message)
        }
    }

    func presentClaudeLoginResult(_ result: ClaudeLoginRunner.Result) {
        switch result.outcome {
        case .success:
            return
        case .missingBinary:
            self.presentLoginAlert(
                title: "Claude CLI not found",
                message: "Install the Claude CLI (npm i -g @anthropic-ai/claude-cli) and try again.")
        case let .launchFailed(message):
            self.presentLoginAlert(title: "Could not start claude /login", message: message)
        case .timedOut:
            self.presentLoginAlert(
                title: "Claude login timed out",
                message: self.trimmedLoginOutput(result.output))
        case let .failed(status):
            let statusLine = "claude /login exited with status \(status)."
            let message = self.trimmedLoginOutput(result.output.isEmpty ? statusLine : result.output)
            self.presentLoginAlert(title: "Claude login failed", message: message)
        }
    }

    private func buildInsightsReport(provider: UsageProvider, days: Int) async -> String {
        let metadata = self.store.metadata(for: provider)
        let now = Date()
        let maxDays = max(1, days)
        let sources: [any UsageLedgerSource] = switch provider {
        case .codex:
            [CodexUsageLogSource(maxAgeDays: maxDays, now: now)]
        case .claude:
            [ClaudeUsageLogSource(maxAgeDays: maxDays, now: now)]
        default:
            []
        }

        var entries: [UsageLedgerEntry] = []
        var loadError: String?
        if !sources.isEmpty {
            do {
                let ledger = UsageLedger(sources: sources)
                entries = try await ledger.loadEntries()
            } catch {
                loadError = error.localizedDescription
            }
        }

        let timeZone = TimeZone.current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let todayStart = calendar.startOfDay(for: now)

        let dailySummaries = UsageLedgerAggregator.dailySummaries(
            entries: entries,
            timeZone: timeZone,
            groupByProject: false)
        let daily = dailySummaries.first { $0.provider == provider && $0.dayStart == todayStart }

        let blocks = UsageLedgerAggregator.blockSummaries(entries: entries, blockHours: 5, now: now)
        let block = blocks.first { $0.provider == provider && $0.isActive }

        let topModel = UsageLedgerAggregator.modelSummaries(entries: entries)
            .first { $0.provider == provider }
        let topProject = UsageLedgerAggregator.projectSummaries(entries: entries)
            .first { $0.provider == provider }
        let modelBreakdown = UsageLedgerAggregator.modelSummaries(entries: entries, groupByProject: true)
            .filter { $0.provider == provider }
        let projectBreakdown = UsageLedgerAggregator.projectSummaries(entries: entries)
            .filter { $0.provider == provider }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var lines: [String] = []
        lines.append("# Runic Insights - \(metadata.displayName)")
        lines.append("")
        lines.append("Window: last \(maxDays) day\(maxDays == 1 ? "" : "s")")
        lines.append("Generated: \(dateFormatter.string(from: now))")

        if let daily {
            lines.append("")
            lines.append("## Today")
            lines.append("- Tokens: \(UsageFormatter.tokenCountString(daily.totals.totalTokens))")
            lines.append("- Input tokens: \(UsageFormatter.tokenCountString(daily.totals.inputTokens))")
            lines.append("- Output tokens: \(UsageFormatter.tokenCountString(daily.totals.outputTokens))")
            let requestCount = modelBreakdown.reduce(0) { $0 + $1.entryCount }
            if requestCount > 0 {
                lines.append("- Requests: \(requestCount)")
                let avgTokensPerRequest = Int((Double(daily.totals.totalTokens) / Double(requestCount)).rounded())
                lines.append("- Avg tokens/request: \(UsageFormatter.tokenCountString(avgTokensPerRequest))")
            }
            if let cost = daily.totals.costUSD {
                lines.append("- Cost: \(UsageFormatter.usdString(cost))")
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: cost,
                    tokenCount: daily.totals.totalTokens)
                {
                    lines.append("- Cost per 1K tokens: \(per1K)")
                }
                if let perRequest = UsageFormatter.usdPerRequestString(
                    costUSD: cost,
                    requestCount: requestCount)
                {
                    lines.append("- Cost per request: \(perRequest)")
                }
            }
            let cacheTotal = daily.totals.cacheCreationTokens + daily.totals.cacheReadTokens
            if cacheTotal > 0 {
                lines.append("- Cache: \(UsageFormatter.tokenCountString(cacheTotal))")
            }
            if !daily.modelsUsed.isEmpty {
                lines.append("- Models: \(daily.modelsUsed.joined(separator: ", "))")
            }
        }

        if let block, block.isActive {
            lines.append("")
            lines.append("## Active block")
            lines.append("- Tokens: \(UsageFormatter.tokenCountString(block.totals.totalTokens))")
            lines.append("- Requests: \(block.entryCount)")
            lines.append("- Input tokens: \(UsageFormatter.tokenCountString(block.totals.inputTokens))")
            lines.append("- Output tokens: \(UsageFormatter.tokenCountString(block.totals.outputTokens))")
            lines.append("- Ends: \(dateFormatter.string(from: block.end))")
            if let rate = block.tokensPerMinute {
                let rateText = UsageFormatter.tokenCountString(Int(rate.rounded()))
                lines.append("- Rate: \(rateText) tok/min")
            }
            if let projected = block.projectedTotalTokens {
                lines.append("- Projected: \(UsageFormatter.tokenCountString(projected))")
            }
            if let cost = block.totals.costUSD {
                lines.append("- Cost: \(UsageFormatter.usdString(cost))")
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: cost,
                    tokenCount: block.totals.totalTokens)
                {
                    lines.append("- Cost per 1K tokens: \(per1K)")
                }
                if let perRequest = UsageFormatter.usdPerRequestString(
                    costUSD: cost,
                    requestCount: block.entryCount)
                {
                    lines.append("- Cost per request: \(perRequest)")
                }
                if let burnPerHour = UsageFormatter.usdPerHourFromTokensString(
                    costUSD: cost,
                    tokenCount: block.totals.totalTokens,
                    tokensPerMinute: block.tokensPerMinute)
                {
                    lines.append("- Estimated burn rate: \(burnPerHour)")
                }
            }
        }

        if let topModel {
            lines.append("")
            lines.append("## Top model")
            let modelName = UsageFormatter.modelDisplayName(topModel.model)
            var line = "- \(modelName): \(UsageFormatter.tokenCountString(topModel.totals.totalTokens)) tokens · \(topModel.entryCount) req"
            if let cost = topModel.totals.costUSD {
                line += " (\(UsageFormatter.usdString(cost)))"
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: cost,
                    tokenCount: topModel.totals.totalTokens)
                {
                    line += " · \(per1K)"
                }
            }
            lines.append(line)
        }

        if let topProject {
            lines.append("")
            lines.append("## Top project")
            let project = self.displayProjectName(
                projectID: topProject.projectID,
                projectName: topProject.projectName,
                confidence: topProject.projectNameConfidence,
                source: topProject.projectNameSource,
                provenance: topProject.projectNameProvenance,
                includeAttribution: true)
            var line = "- \(project): \(UsageFormatter.tokenCountString(topProject.totals.totalTokens)) tokens · \(topProject.entryCount) req"
            if let cost = topProject.totals.costUSD {
                line += " (\(UsageFormatter.usdString(cost)))"
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: cost,
                    tokenCount: topProject.totals.totalTokens)
                {
                    line += " · \(per1K)"
                }
            }
            lines.append(line)
        }

        if !modelBreakdown.isEmpty {
            lines.append("")
            lines.append("## Models by project")
            for summary in modelBreakdown {
                let project = self.displayProjectName(
                    projectID: summary.projectID,
                    projectName: summary.projectName,
                    confidence: summary.projectNameConfidence,
                    source: summary.projectNameSource,
                    provenance: summary.projectNameProvenance,
                    includeAttribution: true)
                let modelName = UsageFormatter.modelDisplayName(summary.model)
                var line = "- \(project) - \(modelName): \(UsageFormatter.tokenCountString(summary.totals.totalTokens)) tokens · \(summary.entryCount) req"
                if let cost = summary.totals.costUSD {
                    line += " (\(UsageFormatter.usdString(cost)))"
                }
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: summary.totals.costUSD,
                    tokenCount: summary.totals.totalTokens)
                {
                    line += " · \(per1K)"
                }
                lines.append(line)
            }
        }

        if !projectBreakdown.isEmpty {
            lines.append("")
            lines.append("## Projects")
            for summary in projectBreakdown {
                let project = self.displayProjectName(
                    projectID: summary.projectID,
                    projectName: summary.projectName,
                    confidence: summary.projectNameConfidence,
                    source: summary.projectNameSource,
                    provenance: summary.projectNameProvenance,
                    includeAttribution: true)
                var line = "- \(project): \(UsageFormatter.tokenCountString(summary.totals.totalTokens)) tokens · \(summary.entryCount) req"
                if let cost = summary.totals.costUSD {
                    line += " (\(UsageFormatter.usdString(cost)))"
                }
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: summary.totals.costUSD,
                    tokenCount: summary.totals.totalTokens)
                {
                    line += " · \(per1K)"
                }
                if !summary.modelsUsed.isEmpty {
                    line += " - models: \(summary.modelsUsed.joined(separator: ", "))"
                }
                lines.append(line)
            }
        }

        if let reliability = UsageLedgerInsightsAdvisor.reliabilityScore(
            provider: provider,
            daily: daily,
            activeBlock: block,
            modelBreakdown: modelBreakdown,
            projectBreakdown: projectBreakdown,
            providerError: self.store.error(for: provider),
            ledgerError: loadError)
        {
            lines.append("")
            lines.append("## Reliability")
            lines.append("- Score: \(reliability.score)/100 (\(reliability.grade))")
            lines.append("- Summary: \(reliability.summary)")
            if let primary = reliability.primarySignal {
                lines.append("- Signal: \(primary)")
            }
        }

        if let routing = UsageLedgerInsightsAdvisor.routingRecommendation(modelBreakdown: modelBreakdown) {
            lines.append("")
            lines.append("## Routing advisor")
            let from = UsageFormatter.modelDisplayName(routing.fromModel)
            let to = UsageFormatter.modelDisplayName(routing.toModel)
            lines.append("- Suggestion: Shift \(routing.shiftPercent)% of \(from) traffic to \(to)")
            lines.append("- Estimated savings: \(UsageFormatter.usdString(routing.estimatedSavingsUSD))")
            lines.append("- Confidence: \(Int((routing.confidence * 100).rounded()))%")
            lines.append("- Rationale: \(routing.rationale)")
        }

        if let loadError {
            lines.append("")
            lines.append("## Error")
            lines.append(loadError)
        }

        if lines.isEmpty || sources.isEmpty {
            return "# Runic Insights - \(metadata.displayName)\n\nNo insights available."
        }

        return lines.joined(separator: "\n")
    }

    private func writeInsightsReport(_ report: String, provider: UsageProvider) -> URL? {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let root = base ?? fm.temporaryDirectory
        let folder = root.appendingPathComponent("Runic/Insights", isDirectory: true)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            RunicLog.logger("insights-report").error("Failed to create report folder: \(error)")
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = dateFormatter.string(from: Date())
        let filename = "insights-\(provider.rawValue)-\(stamp).md"
        let url = folder.appendingPathComponent(filename)
        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            RunicLog.logger("insights-report").error("Failed to write report: \(error)")
            return nil
        }
    }

    func describe(_ outcome: CodexLoginRunner.Result.Outcome) -> String {
        switch outcome {
        case .success: "success"
        case .timedOut: "timedOut"
        case let .failed(status): "failed(status: \(status))"
        case .missingBinary: "missingBinary"
        case let .launchFailed(message): "launchFailed(\(message))"
        }
    }

    func describe(_ outcome: ClaudeLoginRunner.Result.Outcome) -> String {
        switch outcome {
        case .success: "success"
        case .timedOut: "timedOut"
        case let .failed(status): "failed(status: \(status))"
        case .missingBinary: "missingBinary"
        case let .launchFailed(message): "launchFailed(\(message))"
        }
    }

    func describe(_ outcome: GeminiLoginRunner.Result.Outcome) -> String {
        switch outcome {
        case .success: "success"
        case .missingBinary: "missingBinary"
        case let .launchFailed(message): "launchFailed(\(message))"
        }
    }

    func presentGeminiLoginResult(_ result: GeminiLoginRunner.Result) {
        guard let info = Self.geminiLoginAlertInfo(for: result) else { return }
        self.presentLoginAlert(title: info.title, message: info.message)
    }

    struct LoginAlertInfo: Equatable, Sendable {
        let title: String
        let message: String
    }

    nonisolated static func geminiLoginAlertInfo(for result: GeminiLoginRunner.Result) -> LoginAlertInfo? {
        switch result.outcome {
        case .success:
            nil
        case .missingBinary:
            LoginAlertInfo(
                title: "Gemini CLI not found",
                message: "Install the Gemini CLI (npm i -g @google/gemini-cli) and try again.")
        case let .launchFailed(message):
            LoginAlertInfo(title: "Could not open Terminal for Gemini", message: message)
        }
    }

    func presentLoginAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func trimmedLoginOutput(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let limit = 600
        if trimmed.isEmpty { return "No output captured." }
        if trimmed.count <= limit { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return "\(trimmed[..<idx])…"
    }

    func postLoginNotification(for provider: UsageProvider) {
        let name = ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
        let title = "\(name) login successful"
        let body = "You can return to the app; authentication finished."
        AppNotifications.shared.post(idPrefix: "login-\(provider.rawValue)", title: title, body: body)
    }

    func presentCursorLoginResult(_ result: CursorLoginRunner.Result) {
        switch result.outcome {
        case .success:
            return
        case .cancelled:
            // User closed the window; no alert needed
            return
        case let .failed(message):
            self.presentLoginAlert(title: "Cursor login failed", message: message)
        }
    }

    func describe(_ outcome: CursorLoginRunner.Result.Outcome) -> String {
        switch outcome {
        case .success: "success"
        case .cancelled: "cancelled"
        case let .failed(message): "failed(\(message))"
        }
    }
}
