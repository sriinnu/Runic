import Foundation
import RunicCore

@MainActor
extension UsageStore {
    /// Recompute the config-driven rolling-window quota gauges from log-derived usage.
    ///
    /// Some plans (notably DashScope's Token Plan) bill against a rolling request
    /// budget that no API exposes, so the provider's own fetch can never produce a
    /// percentage. Here we reconstruct it: relay-cached daily totals (which carry
    /// request counts and persist ~30 days) cover day-and-up windows, and today's
    /// in-memory hourly summaries refine the sub-day (e.g. 5h) window. The result is
    /// stored in `quotaWindows` and rendered as the card's gauge.
    func recomputeQuotaGauges() async {
        let now = Date()
        let todayKey = LedgerCache.dayKey(for: now)
        var gauges: [UsageProvider: [RateWindow]] = [:]

        for (key, providerConfig) in self.appliedConfig.providers {
            guard let quota = providerConfig.quota, !quota.windows.isEmpty,
                  let provider = UsageProvider(rawValue: key)
            else {
                continue
            }

            let dailies = await LedgerCache.shared.loadCachedDailies(provider: key)?.dailies ?? []
            let hourly = self.ledgerHourlySummaries[provider] ?? []

            // Past-day (excluding today) request + token totals, keyed by day.
            var dayRequests: [String: Int] = [:]
            var dayTokens: [String: Int] = [:]
            for daily in dailies where daily.dayKey != todayKey {
                dayRequests[daily.dayKey, default: 0] += daily.requestCount
                dayTokens[daily.dayKey, default: 0] += daily.inputTokens + daily.outputTokens
            }

            var windows: [RateWindow] = []
            for window in quota.windows.sorted(by: { $0.minutes < $1.minutes }) {
                guard window.minutes > 0,
                      let limit = window.requests ?? window.tokens, limit > 0
                else {
                    continue
                }
                let useRequests = window.requests != nil
                let windowStart = now.addingTimeInterval(-TimeInterval(window.minutes * 60))
                var used = 0
                if window.minutes < 1440 {
                    // Sub-day window: hourly only (today). Accurate within a day; in
                    // manual mode a window crossing midnight under-counts the prior
                    // evening (no hourly history for it) — an acceptable approximation.
                    for hour in hourly where hour.hourStart >= windowStart {
                        used += useRequests ? hour.requestCount : hour.totals.nonCacheTokens
                    }
                } else {
                    // Day-and-up window: full past days from the relay + today's hours.
                    let windowStartDayKey = LedgerCache.dayKey(for: windowStart)
                    for (dayKey, requests) in dayRequests where dayKey >= windowStartDayKey {
                        used += useRequests ? requests : (dayTokens[dayKey] ?? 0)
                    }
                    for hour in hourly where hour.hourStart >= windowStart {
                        used += useRequests ? hour.requestCount : hour.totals.nonCacheTokens
                    }
                }
                let percent = min(100, max(0, Double(used) / Double(limit) * 100))
                let unit = useRequests ? "req" : "tok"
                windows.append(RateWindow(
                    usedPercent: percent,
                    windowMinutes: window.minutes,
                    resetsAt: nil,
                    resetDescription: "\(used) / \(limit) \(unit)",
                    hasKnownLimit: true))
            }

            if !windows.isEmpty {
                gauges[provider] = windows
            }
        }

        self.quotaWindows = gauges
    }
}
