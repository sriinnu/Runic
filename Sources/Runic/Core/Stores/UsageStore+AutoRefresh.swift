import CoreGraphics
import Foundation
import RunicCore

extension UsageStore {
    func autoRefreshStatusLine() -> String? {
        if self.settings.refreshFrequency == .manual {
            if let reason = self.lastAutoRefreshDisableReason {
                return "Auto-refresh: Manual (switched after \(reason.label))"
            }
            return "Auto-refresh: Manual"
        }
        if let reason = self.autoRefreshSuspensionReason {
            return "Auto-refresh: Paused (\(reason.label))"
        }
        return "Auto-refresh: \(self.settings.refreshFrequency.label)"
    }

    func setAutoRefreshSuspended(_ reason: AutoRefreshSuspensionReason?) {
        self.autoRefreshSuspensionReason = reason
    }

    func disableAutoRefreshForSystemPause(_ reason: AutoRefreshSuspensionReason) {
        let detail = self.systemPauseDetailText(reason)
        self.disableAutoRefresh(
            reason: self.disableReason(for: reason),
            idPrefix: "auto-refresh-system",
            body: "Runic switched auto-refresh to Manual because \(detail).")
    }

    func handleAutoRefreshSystemPause(_ reason: AutoRefreshSuspensionReason) {
        if self.settings.autoDisableRefreshOnSleepEnabled {
            self.disableAutoRefreshForSystemPause(reason)
        } else {
            self.setAutoRefreshSuspended(reason)
        }
    }

    func lastRefreshStatusLine(now: Date = .now) -> String? {
        guard let trigger = self.lastRefreshTrigger,
              let refreshedAt = self.lastRefreshAt else { return nil }
        // Honor the app-wide date-format preference like the menu cards do.
        let when = switch self.settings.dateFormat.formatterStyle {
        case .relative: refreshedAt.relativeDescription(now: now)
        case .absolute: UsageFormatter.absoluteTimestampString(from: refreshedAt, now: now)
        }
        return "Last refresh: \(trigger.menuLabel) • \(when)"
    }

    func autoRefreshSwitchLine(now: Date = .now) -> String? {
        guard self.settings.refreshFrequency == .manual,
              let reason = self.lastAutoRefreshDisableReason,
              let disabledAt = self.lastAutoRefreshDisableAt else { return nil }
        let relative = disabledAt.relativeDescription(now: now)
        return "Auto-refresh switched to Manual after \(reason.label) • \(relative)"
    }

    func autoRefreshDisableBadgeText() -> String? {
        guard self.settings.refreshFrequency == .manual,
              let reason = self.lastAutoRefreshDisableReason else { return nil }
        return "Manual because of \(reason.label)"
    }

    func handleSettingsChange() async {
        let refreshChanged = self.settings.refreshFrequency != self.lastRefreshFrequency
        let warningEnabledChanged = self.settings.autoRefreshWarningEnabled != self.lastAutoRefreshWarningEnabled
        let warningThresholdChanged = self.settings.autoRefreshWarningThreshold
            != self.lastAutoRefreshWarningThreshold
        if refreshChanged || warningEnabledChanged || warningThresholdChanged {
            self.resetAutoRefreshWarningState()
            self.lastRefreshFrequency = self.settings.refreshFrequency
            self.lastAutoRefreshWarningEnabled = self.settings.autoRefreshWarningEnabled
            self.lastAutoRefreshWarningThreshold = self.settings.autoRefreshWarningThreshold
        }
        if refreshChanged, !self.suppressNextSettingsRefresh {
            self.clearAutoRefreshDisableReason()
        }
        self.startTimer()
        self.startTokenTimer()
        guard !self.suppressNextSettingsRefresh else {
            self.suppressNextSettingsRefresh = false
            return
        }
        await self.refresh(trigger: .settingsChange)
    }

    func startTimer() {
        self.timerTask?.cancel()
        guard let wait = self.settings.refreshFrequency.seconds else { return }

        // Background poller so the menu stays responsive; canceled when settings change or store deallocates.
        self.timerTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(wait))
                await self?.refresh(trigger: .autoTimer)
            }
        }
    }

    func startTokenTimer() {
        self.tokenTimerTask?.cancel()
        guard self.settings.refreshFrequency != .manual else { return }
        guard self.settings.costUsageEnabled else { return }
        let wait = self.tokenFetchTTL
        self.tokenTimerTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(wait))
                let inactive = await self?.inactiveProviders(now: Date()) ?? []
                await self?.scheduleTokenRefresh(
                    force: false,
                    trigger: .autoTimer,
                    inactiveProviders: inactive)
            }
        }
    }

    func shouldRunAutoRefresh(trigger: RefreshTrigger, now: Date) -> Bool {
        guard trigger.isAuto else { return true }
        guard self.settings.refreshFrequency != .manual else { return false }
        if self.autoRefreshSuspensionReason != nil { return false }

        if self.settings.autoDisableRefreshWhenIdleEnabled,
           let idleSeconds = self.currentIdleSeconds()
        {
            let thresholdMinutes = max(1, self.settings.autoDisableRefreshWhenIdleMinutes)
            let thresholdSeconds = TimeInterval(thresholdMinutes) * 60
            if idleSeconds >= thresholdSeconds {
                self.disableAutoRefreshForIdle(thresholdMinutes: thresholdMinutes)
                return false
            }
        }
        return true
    }

    func recordAutoRefreshRunIfNeeded(trigger: RefreshTrigger) {
        guard trigger == .autoTimer else { return }
        guard self.settings.autoRefreshWarningEnabled else { return }
        guard !self.autoRefreshWarningSent else { return }
        let threshold = max(1, self.settings.autoRefreshWarningThreshold)
        self.autoRefreshRunCount += 1
        guard self.autoRefreshRunCount >= threshold else { return }
        self.autoRefreshWarningSent = true
        AppNotifications.shared.post(
            idPrefix: "auto-refresh-warning",
            title: "Auto-refresh is enabled",
            body: "Runic has auto-refreshed \(threshold) times. Auto-refresh can touch CLIs, "
                + "logs, or browser cookies depending on provider settings. Switch to Manual if you prefer "
                + "click-only refresh.")
    }

    func inactiveProviders(now: Date) -> Set<UsageProvider> {
        guard self.settings.autoSuspendInactiveProvidersEnabled else { return [] }
        let thresholdMinutes = max(1, self.settings.autoSuspendInactiveProvidersMinutes)
        let thresholdSeconds = TimeInterval(thresholdMinutes) * 60

        var inactive: Set<UsageProvider> = []
        for provider in UsageProvider.allCases {
            guard self.isEnabled(provider) else { continue }
            guard let lastActivity = self.lastActivityAt(for: provider) else { continue }
            if now.timeIntervalSince(lastActivity) >= thresholdSeconds {
                inactive.insert(provider)
            }
        }
        return inactive
    }

    func recordUsageActivity(
        provider: UsageProvider,
        previous: UsageSnapshot?,
        current: UsageSnapshot)
    {
        if previous == nil || self.usageChanged(previous: previous, current: current) {
            self.lastUsageDeltaAt[provider] = current.updatedAt
        }
    }

    private func disableAutoRefreshForIdle(thresholdMinutes: Int) {
        self.disableAutoRefresh(
            reason: .idle,
            idPrefix: "auto-refresh-idle",
            body: "Runic switched auto-refresh to Manual after \(thresholdMinutes) minutes of inactivity. "
                + "Use Refresh in the menu when you want new data.")
    }

    private func disableAutoRefresh(reason: AutoRefreshDisableReason, idPrefix: String, body: String) {
        guard self.settings.refreshFrequency != .manual else { return }
        self.suppressNextSettingsRefresh = true
        self.settings.refreshFrequency = .manual
        self.autoRefreshSuspensionReason = nil
        self.lastAutoRefreshDisableReason = reason
        self.lastAutoRefreshDisableAt = Date()
        AppNotifications.shared.post(
            idPrefix: idPrefix,
            title: "Auto-refresh switched to Manual",
            body: body)
    }

    private func clearAutoRefreshDisableReason() {
        self.lastAutoRefreshDisableReason = nil
        self.lastAutoRefreshDisableAt = nil
    }

    private func systemPauseDetailText(_ reason: AutoRefreshSuspensionReason) -> String {
        switch reason {
        case .systemSleep:
            "your Mac went to sleep"
        case .screenSleep:
            "the display went to sleep"
        case .sessionInactive:
            "your session became inactive"
        }
    }

    private func disableReason(for reason: AutoRefreshSuspensionReason) -> AutoRefreshDisableReason {
        switch reason {
        case .systemSleep: .systemSleep
        case .screenSleep: .screenSleep
        case .sessionInactive: .sessionInactive
        }
    }

    private func currentIdleSeconds() -> TimeInterval? {
        #if os(macOS)
        guard let anyInputType = CGEventType(rawValue: UInt32.max) else { return nil }
        let seconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputType)
        return seconds >= 0 ? seconds : nil
        #else
        return nil
        #endif
    }

    private func resetAutoRefreshWarningState() {
        self.autoRefreshRunCount = 0
        self.autoRefreshWarningSent = false
    }

    private func lastActivityAt(for provider: UsageProvider) -> Date? {
        let ledger = self.lastLedgerActivityAt[provider]
        let delta = self.lastUsageDeltaAt[provider]
        switch (ledger, delta) {
        case let (l?, d?):
            return max(l, d)
        case let (l?, nil):
            return l
        case let (nil, d?):
            return d
        case (nil, nil):
            return nil
        }
    }

    private func usageChanged(previous: UsageSnapshot?, current: UsageSnapshot) -> Bool {
        guard let previous else { return true }

        func windowChanged(_ lhs: RateWindow?, _ rhs: RateWindow?) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                false
            case let (l?, r?):
                abs(l.usedPercent - r.usedPercent) >= 0.1
            case (nil, _), (_, nil):
                true
            }
        }

        if windowChanged(previous.primary, current.primary) { return true }
        if windowChanged(previous.secondary, current.secondary) { return true }
        if windowChanged(previous.tertiary, current.tertiary) { return true }

        switch (previous.providerCost, current.providerCost) {
        case (nil, nil):
            return false
        case let (lhs?, rhs?):
            if lhs.used != rhs.used { return true }
            if lhs.limit != rhs.limit { return true }
            return false
        case (nil, _), (_, nil):
            return true
        }
    }
}
