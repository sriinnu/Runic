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
            if ZaiSettingsReader.apiToken(environment: self.processEnvironment) != nil {
                return true
            }
            return !self.settings.zaiAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func refreshProvider(_ provider: UsageProvider, trigger _: RefreshTrigger) async {
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
                let hadPriorData = self.snapshots[provider] != nil
                let shouldSurface = self.failureGates[provider]?
                    .shouldSurfaceError(onFailureWithPriorData: hadPriorData) ?? true
                if shouldSurface {
                    self.errors[provider] = error.localizedDescription
                    self.snapshots.removeValue(forKey: provider)
                } else {
                    self.errors[provider] = nil
                }
            }
        }
    }

    private func handleSessionQuotaTransition(provider: UsageProvider, snapshot: UsageSnapshot) {
        let currentRemaining = snapshot.primary.remainingPercent
        let previousRemaining = self.lastKnownSessionRemaining[provider]

        defer { self.lastKnownSessionRemaining[provider] = currentRemaining }

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
                self.sessionQuotaNotifier.post(transition: .depleted, provider: provider)
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

        self.sessionQuotaNotifier.post(transition: transition, provider: provider)
    }
}
