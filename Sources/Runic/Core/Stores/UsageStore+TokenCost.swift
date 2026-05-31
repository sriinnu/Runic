import Foundation
import RunicCore

extension UsageStore {
    func tokenSnapshot(for provider: UsageProvider) -> CostUsageTokenSnapshot? {
        self.tokenSnapshots[provider] ?? self.ledgerTokenSnapshot(for: provider)
    }

    func tokenError(for provider: UsageProvider) -> String? {
        self.tokenErrors[provider]
    }

    func tokenLastAttemptAt(for provider: UsageProvider) -> Date? {
        self.lastTokenFetchAt[provider]
    }

    func isTokenRefreshInFlight(for provider: UsageProvider) -> Bool {
        self.tokenRefreshInFlight.contains(provider)
    }

    func clearCostUsageCache() async -> String? {
        let errorMessage: String? = await Task.detached(priority: .utility) {
            let fm = FileManager.default
            let cacheDirs = [
                Self.costUsageCacheDirectory(fileManager: fm),
                Self.costUsageLedgerCacheDirectory(fileManager: fm),
                Self.costUsageRelayDirectory(fileManager: fm),
            ]

            for cacheDir in cacheDirs {
                do {
                    try fm.removeItem(at: cacheDir)
                } catch let error as NSError {
                    if error.domain == NSCocoaErrorDomain, error.code == NSFileNoSuchFileError { continue }
                    return error.localizedDescription
                }
            }
            return nil
        }.value

        guard errorMessage == nil else { return errorMessage }

        self.tokenSnapshots.removeAll()
        self.tokenErrors.removeAll()
        self.lastTokenFetchAt.removeAll()
        self.tokenFailureGates[.codex]?.reset()
        self.tokenFailureGates[.claude]?.reset()
        return nil
    }

    func scheduleTokenRefresh(
        force: Bool,
        trigger: RefreshTrigger,
        inactiveProviders: Set<UsageProvider>)
    {
        if trigger.isAuto, !self.shouldRunAutoRefresh(trigger: trigger, now: Date()) {
            return
        }
        if force {
            self.tokenRefreshSequenceTask?.cancel()
            self.tokenRefreshSequenceTask = nil
        } else if self.tokenRefreshSequenceTask != nil {
            return
        }

        self.tokenRefreshSequenceTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.tokenRefreshSequenceTask = nil
                }
            }
            await withTaskGroup(of: Void.self) { group in
                for provider in UsageProvider.allCases {
                    group.addTask {
                        guard !Task.isCancelled else { return }
                        await self.refreshTokenUsage(
                            provider,
                            force: force,
                            trigger: trigger,
                            inactiveProviders: inactiveProviders)
                    }
                }
            }
        }
    }

    private func refreshTokenUsage(
        _ provider: UsageProvider,
        force: Bool,
        trigger: RefreshTrigger,
        inactiveProviders: Set<UsageProvider>) async
    {
        guard provider == .codex || provider == .claude else {
            self.clearTokenCostState(for: provider)
            return
        }

        guard self.settings.costUsageEnabled else {
            self.clearTokenCostState(for: provider)
            return
        }

        guard self.isEnabled(provider) else {
            self.clearTokenCostState(for: provider)
            return
        }

        if trigger.isAuto, inactiveProviders.contains(provider), !force {
            return
        }

        guard !self.tokenRefreshInFlight.contains(provider) else { return }

        let now = Date()
        if !force,
           let last = self.lastTokenFetchAt[provider],
           now.timeIntervalSince(last) < self.tokenFetchTTL
        {
            return
        }
        self.lastTokenFetchAt[provider] = now
        self.tokenRefreshInFlight.insert(provider)
        defer { self.tokenRefreshInFlight.remove(provider) }

        let startedAt = Date()
        let providerText = provider.rawValue
        self.tokenCostLogger
            .info("cost usage start provider=\(providerText) force=\(force)")

        do {
            let fetcher = self.costUsageFetcher
            let timeoutSeconds = self.tokenFetchTimeout
            let snapshot = try await withThrowingTaskGroup(of: CostUsageTokenSnapshot.self) { group in
                group.addTask(priority: .utility) {
                    try await fetcher.loadTokenSnapshot(provider: provider, now: now)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    throw CostUsageError.timedOut(seconds: Int(timeoutSeconds))
                }
                defer { group.cancelAll() }
                guard let snapshot = try await group.next() else { throw CancellationError() }
                return snapshot
            }

            guard !snapshot.daily.isEmpty else {
                self.tokenSnapshots.removeValue(forKey: provider)
                self.tokenErrors[provider] = Self.tokenCostNoDataMessage(for: provider)
                self.tokenFailureGates[provider]?.recordSuccess()
                return
            }
            let duration = Date().timeIntervalSince(startedAt)
            let sessionCost = snapshot.sessionCostUSD.map(UsageFormatter.usdString) ?? "—"
            let monthCost = snapshot.last30DaysCostUSD.map(UsageFormatter.usdString) ?? "—"
            let durationText = String(format: "%.2f", duration)
            let message =
                "cost usage success provider=\(providerText) " +
                "duration=\(durationText)s " +
                "today=\(sessionCost) " +
                "30d=\(monthCost)"
            self.tokenCostLogger.info(message)
            self.tokenSnapshots[provider] = snapshot
            self.tokenErrors[provider] = nil
            self.tokenFailureGates[provider]?.recordSuccess()
            self.persistWidgetSnapshot(reason: "token-usage")
        } catch {
            if error is CancellationError { return }
            let duration = Date().timeIntervalSince(startedAt)
            let msg = error.localizedDescription
            let durationText = String(format: "%.2f", duration)
            let message = "cost usage failed provider=\(providerText) duration=\(durationText)s error=\(msg)"
            self.tokenCostLogger.error(message)
            let hadPriorData = self.tokenSnapshots[provider] != nil
            let shouldSurface = self.tokenFailureGates[provider]?
                .shouldSurfaceError(onFailureWithPriorData: hadPriorData) ?? true
            if shouldSurface {
                self.tokenErrors[provider] = error.localizedDescription
                self.tokenSnapshots.removeValue(forKey: provider)
            } else {
                self.tokenErrors[provider] = nil
            }
        }
    }

    nonisolated static func costUsageCacheDirectory(
        fileManager: FileManager = .default) -> URL
    {
        let root = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return root
            .appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("cost-usage", isDirectory: true)
    }

    nonisolated static func costUsageLedgerCacheDirectory(
        fileManager: FileManager = .default) -> URL
    {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root
            .appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("ledger-cache", isDirectory: true)
    }

    nonisolated static func costUsageRelayDirectory(
        fileManager: FileManager = .default) -> URL
    {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root
            .appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("relay", isDirectory: true)
    }

    nonisolated static func tokenCostNoDataMessage(for provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).tokenCost.noDataMessage()
    }

    private func clearTokenCostState(for provider: UsageProvider) {
        self.tokenSnapshots.removeValue(forKey: provider)
        self.tokenErrors[provider] = nil
        self.tokenFailureGates[provider]?.reset()
        self.lastTokenFetchAt.removeValue(forKey: provider)
    }

    private func ledgerTokenSnapshot(for provider: UsageProvider) -> CostUsageTokenSnapshot? {
        let allDaily = self.ledgerAllDailySummary(for: provider)
        guard !allDaily.isEmpty else { return nil }

        let now = Date()
        let todayKey = Self.ledgerDayKey(for: now)
        let today = allDaily.first(where: { $0.dayKey == todayKey })
        let since = Calendar.current.date(byAdding: .day, value: -29, to: now) ?? now
        let last30 = allDaily.filter { $0.dayStart >= since && $0.dayStart <= now }
        let window = last30.isEmpty ? allDaily : last30

        let totalTokens = window.reduce(0) { $0 + $1.totals.totalTokens }
        let costs = window.compactMap(\.totals.costUSD)
        let totalCost = costs.isEmpty ? nil : costs.reduce(0, +)
        guard totalTokens > 0 || totalCost != nil else { return nil }

        let daily = window
            .sorted { $0.dayStart < $1.dayStart }
            .map { summary in
                CostUsageDailyReport.Entry(
                    date: summary.dayKey,
                    inputTokens: summary.totals.inputTokens,
                    outputTokens: summary.totals.outputTokens,
                    cacheReadTokens: summary.totals.cacheReadTokens,
                    cacheCreationTokens: summary.totals.cacheCreationTokens,
                    totalTokens: summary.totals.totalTokens,
                    costUSD: summary.totals.costUSD,
                    modelsUsed: summary.modelsUsed,
                    modelBreakdowns: nil)
            }

        return CostUsageTokenSnapshot(
            sessionTokens: today?.totals.totalTokens,
            sessionCostUSD: today?.totals.costUSD,
            last30DaysTokens: totalTokens > 0 ? totalTokens : nil,
            last30DaysCostUSD: totalCost,
            daily: daily,
            updatedAt: self.ledgerUpdatedAt(for: provider) ?? now)
    }

    private nonisolated static func ledgerDayKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            comps.year ?? 1970,
            comps.month ?? 1,
            comps.day ?? 1)
    }
}
