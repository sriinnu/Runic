import Foundation
import RunicCore

extension UsageStore {
    func enabledProviders() -> [UsageProvider] {
        // Use cached enablement to avoid repeated UserDefaults lookups in animation ticks.
        let enabled = self.settings.enabledProvidersOrdered(metadataByProvider: self.providerMetadata)
        return enabled.filter { self.isProviderAvailable($0) }
    }

    var statusChecksEnabled: Bool {
        self.settings.statusChecksEnabled
    }

    func metadata(for provider: UsageProvider) -> ProviderMetadata {
        self.providerMetadata[provider]!
    }

    func sourceLabel(for provider: UsageProvider) -> String {
        var label = self.lastSourceLabels[provider] ?? ""
        if label.isEmpty {
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let modes = descriptor.fetchPlan.sourceModes
            if modes.count == 1, let mode = modes.first {
                label = mode.rawValue
            } else if provider == .claude {
                label = self.settings.claudeUsageDataSource.rawValue
            } else {
                label = "auto"
            }
        }

        // When OpenAI web extras are active, show a blended label like `oauth + openai-web`.
        if provider == .codex,
           self.settings.openAIWebAccessEnabled,
           self.openAIDashboard != nil,
           !self.openAIDashboardRequiresLogin,
           !label.contains("openai-web")
        {
            return "\(label) + openai-web"
        }
        return label
    }

    func style(for provider: UsageProvider) -> IconStyle {
        self.providerSpecs[provider]?.style ?? .codex
    }

    func isStale(provider: UsageProvider) -> Bool {
        self.errors[provider] != nil
    }

    /// A successful snapshot older than this is still worth a background ping
    /// when the user opens the menu. Matches the slowest auto-refresh cadence
    /// (`RefreshFrequency.fifteenMinutes`): once a snapshot is a full
    /// slowest-cycle interval old, something (sleep, a dropped timer, an
    /// inactive-provider skip) has kept it from refreshing on its own.
    static let menuOpenSnapshotMaxAge: TimeInterval = 15 * 60

    /// Whether opening a menu should trigger a background refresh ping.
    ///
    /// Error-stale and missing-snapshot providers always ping. A provider
    /// whose last fetch SUCCEEDED but whose snapshot has aged past
    /// `menuOpenSnapshotMaxAge` pings too — `isStale` is error-keyed only, so
    /// stale-but-successful data used to never re-ping on menu open. With no
    /// specific provider (merged/fallback menus), any aged snapshot counts.
    func shouldPingOnMenuOpen(provider: UsageProvider?, now: Date = Date()) -> Bool {
        func aged(_ snapshot: UsageSnapshot) -> Bool {
            now.timeIntervalSince(snapshot.updatedAt) > Self.menuOpenSnapshotMaxAge
        }
        if let provider {
            if self.isStale(provider: provider) { return true }
            guard let snapshot = self.snapshots[provider] else { return true }
            return aged(snapshot)
        }
        if self.isStale { return true }
        return self.snapshots.values.contains(where: aged)
    }

    func isEnabled(_ provider: UsageProvider) -> Bool {
        let enabled = self.settings.isProviderEnabledCached(
            provider: provider,
            metadataByProvider: self.providerMetadata)
        guard enabled else { return false }
        return self.isProviderAvailable(provider)
    }

    func refreshSingleProvider(_ provider: UsageProvider) async {
        self.isRefreshing = true
        defer { self.isRefreshing = false }
        await self.refreshProvider(provider, trigger: .manual)
        await self.refreshStatus(provider, trigger: .manual)
        self.scheduleLedgerRefresh(force: true, inactiveProviders: [])
    }

    func refresh(trigger: RefreshTrigger = .manual, forceTokenUsage: Bool = false) async {
        guard !self.isRefreshing else { return }
        let now = Date()
        if trigger.isAuto, !self.shouldRunAutoRefresh(trigger: trigger, now: now) {
            return
        }
        if trigger.isAuto {
            self.recordAutoRefreshRunIfNeeded(trigger: trigger)
        }

        self.lastRefreshTrigger = trigger
        self.lastRefreshAt = now
        self.isRefreshing = true
        defer { self.isRefreshing = false }

        let inactiveProviders = trigger.isAuto ? self.inactiveProviders(now: now) : []
        let skipCodexExtras = trigger.isAuto && inactiveProviders.contains(.codex)

        await withTaskGroup(of: Void.self) { group in
            for provider in UsageProvider.allCases {
                if inactiveProviders.contains(provider) { continue }
                group.addTask { await self.refreshProvider(provider, trigger: trigger) }
                group.addTask { await self.refreshStatus(provider, trigger: trigger) }
            }
            if !skipCodexExtras {
                group.addTask { await self.refreshCreditsIfNeeded() }
            }
        }

        // Token-cost usage can be slow; run it outside the refresh group so we don't block menu updates.
        self.scheduleTokenRefresh(force: forceTokenUsage, trigger: trigger, inactiveProviders: inactiveProviders)

        // OpenAI web scrape depends on the current Codex account email (which can change after login/account switch).
        // Run this after Codex usage refresh so we don't accidentally scrape with stale credentials.
        if !skipCodexExtras {
            await self.refreshOpenAIDashboardIfNeeded(force: forceTokenUsage)
        }

        if self.openAIDashboardRequiresLogin, !skipCodexExtras {
            await self.refreshProvider(.codex, trigger: trigger)
            await self.refreshCreditsIfNeeded()
        }

        self.scheduleLedgerRefresh(force: !trigger.isAuto || forceTokenUsage, inactiveProviders: inactiveProviders)

        await self.refreshCustomProviders()
        self.persistWidgetSnapshot(reason: "refresh")
    }

    func bindSettings() {
        self.observeSettingsChanges()
    }

    private func isProviderAvailable(_ provider: UsageProvider) -> Bool {
        if provider == .zai {
            // Check settings property first (reactive to user input), then
            // fall back to Keychain/env (catches tokens stored by CLI).
            if !self.settings.zaiAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            return ProviderTokenResolver.zaiToken(environment: self.processEnvironment) != nil
        }
        return true
    }

    func refreshProvider(_ provider: UsageProvider, trigger _: RefreshTrigger) async {
        guard let spec = self.providerSpecs[provider] else { return }

        if !spec.isEnabled() {
            self.refreshingProviders.remove(provider)
            await MainActor.run {
                self.snapshots.removeValue(forKey: provider)
                self.errors[provider] = nil
                self.lastSourceLabels.removeValue(forKey: provider)
                self.lastFetchAttempts.removeValue(forKey: provider)
                self.tokenSnapshots.removeValue(forKey: provider)
                self.tokenErrors[provider] = nil
                self.failureGates[provider]?.reset()
                self.tokenFailureGates[provider]?.reset()
                self.statuses.removeValue(forKey: provider)
                self.lastKnownSessionRemaining.removeValue(forKey: provider)
                self.lastTokenFetchAt.removeValue(forKey: provider)
                self.lastUsageDeltaAt.removeValue(forKey: provider)
                self.lastLedgerActivityAt.removeValue(forKey: provider)
                self.ledgerCompactions.removeValue(forKey: provider)
                self.providerCredits.removeValue(forKey: provider)
            }
            return
        }

        // History-only providers (e.g. opencode) have no live gauge to fetch —
        // their usage comes from the ledger timeline. Skip snapshotting so an
        // empty fetch plan never surfaces a spurious "no strategy" error or trips
        // the stale badge. The ledger refresh runs separately and populates them.
        if !self.metadata(for: provider).providesLiveSnapshot {
            await MainActor.run {
                self.errors[provider] = nil
                self.snapshots.removeValue(forKey: provider)
            }
            return
        }

        self.refreshingProviders.insert(provider)
        defer { self.refreshingProviders.remove(provider) }

        let previousSnapshot = self.snapshots[provider]
        let outcome = await spec.fetch()
        await MainActor.run {
            self.lastFetchAttempts[provider] = outcome.attempts
        }

        switch outcome.result {
        case let .success(result):
            let scoped = result.usage.scoped(to: provider)
            await MainActor.run {
                self.handleSessionQuotaTransition(provider: provider, snapshot: scoped)
                self.snapshots[provider] = scoped
                // Providers whose fetchers attach a credits snapshot (DeepSeek,
                // OpenRouter, Vercel AI, ...) surface it per provider; a nil
                // result keeps the last-known snapshot, mirroring how usage
                // snapshots survive transient gaps. Codex is excluded: its
                // accessor reads the dedicated `credits` slot (see
                // `credits(for:)`), so a `providerCredits[.codex]` entry would
                // only be a stale duplicate for anything iterating the map.
                if let credits = result.credits, provider != .codex {
                    self.providerCredits[provider] = credits
                }
                self.lastSourceLabels[provider] = result.sourceLabel
                self.errors[provider] = nil
                self.failureGates[provider]?.recordSuccess()
                self.recordUsageActivity(
                    provider: provider,
                    previous: previousSnapshot,
                    current: scoped)
            }
        case let .failure(error):
            await MainActor.run {
                self.recordProviderFetchFailure(provider, message: error.localizedDescription)
            }
        }
    }

    /// Record a fetch failure without discarding the last-known-good snapshot.
    ///
    /// The menu card keeps rendering the stale usage bars (dated by the kept
    /// snapshot's `updatedAt`) with the error header surfaced alongside once the
    /// failure gate lets it through. Wiping the snapshot here used to flip the
    /// card from usage bars to error-text-only on the first surfaced failure.
    func recordProviderFetchFailure(_ provider: UsageProvider, message: String) {
        let hadPriorData = self.snapshots[provider] != nil
        let shouldSurface = self.failureGates[provider]?
            .shouldSurfaceError(onFailureWithPriorData: hadPriorData) ?? true
        self.errors[provider] = shouldSurface ? message : nil
    }

    private func handleSessionQuotaTransition(provider: UsageProvider, snapshot: UsageSnapshot) {
        let currentRemaining = snapshot.primary.remainingPercent
        let previousRemaining = self.lastKnownSessionRemaining[provider]

        // A 0%-remaining window with no real quota evidence (no window duration,
        // no reset time, no reset/balance text) is a hardcoded stub, not a
        // measurement. Bail before recording it: posting would spam a phantom
        // depletion alert, and remembering it as "previous = 0" would fire a
        // phantom "restored" alert once real data arrives.
        if SessionQuotaNotificationLogic.isDepleted(currentRemaining),
           !SessionQuotaNotificationLogic.hasRealQuota(snapshot.primary)
        {
            let providerText = provider.rawValue
            self.sessionQuotaLogger.debug("ignoring stub depleted window: provider=\(providerText)")
            return
        }

        defer { self.lastKnownSessionRemaining[provider] = currentRemaining }

        let quotaKind = SessionQuotaNotificationLogic.quotaKind(
            windowMinutes: snapshot.primary.windowMinutes,
            resetsAt: snapshot.primary.resetsAt,
            supportsCredits: self.metadata(for: provider).supportsCredits)

        guard self.settings.sessionQuotaNotificationsEnabled else {
            if SessionQuotaNotificationLogic.isDepleted(currentRemaining) ||
                SessionQuotaNotificationLogic.isDepleted(previousRemaining)
            {
                let providerText = provider.rawValue
                let message =
                    "notifications disabled: provider=\(providerText) " +
                    "prev=\(previousRemaining ?? -1) curr=\(currentRemaining)"
                self.sessionQuotaLogger.debug(message)
            }
            return
        }

        guard previousRemaining != nil else {
            if SessionQuotaNotificationLogic.isDepleted(currentRemaining) {
                let providerText = provider.rawValue
                let message = "startup depleted: provider=\(providerText) curr=\(currentRemaining)"
                self.sessionQuotaLogger.info(message)
                self.sessionQuotaNotifier.post(transition: .depleted, provider: provider, quotaKind: quotaKind)
            }
            return
        }

        let transition = SessionQuotaNotificationLogic.transition(
            previousRemaining: previousRemaining,
            currentRemaining: currentRemaining)
        guard transition != .none else {
            if SessionQuotaNotificationLogic.isDepleted(currentRemaining) ||
                SessionQuotaNotificationLogic.isDepleted(previousRemaining)
            {
                let providerText = provider.rawValue
                let message =
                    "no transition: provider=\(providerText) " +
                    "prev=\(previousRemaining ?? -1) curr=\(currentRemaining)"
                self.sessionQuotaLogger.debug(message)
            }
            return
        }

        let providerText = provider.rawValue
        let transitionText = String(describing: transition)
        let message =
            "transition \(transitionText): provider=\(providerText) " +
            "prev=\(previousRemaining ?? -1) curr=\(currentRemaining)"
        self.sessionQuotaLogger.info(message)

        self.sessionQuotaNotifier.post(transition: transition, provider: provider, quotaKind: quotaKind)
    }
}
