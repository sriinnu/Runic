import Foundation

extension GenericProviderFetcher {
    /// Convert usage data to Runic's UsageSnapshot format
    public func toUsageSnapshot(_ data: UsageData) -> UsageSnapshot {
        let usedPercent: Double = if let quota = data.quota, let used = data.used, quota > 0 {
            (used / quota) * 100.0
        } else if let remaining = data.remaining, let quota = data.quota, quota > 0 {
            ((quota - remaining) / quota) * 100.0
        } else {
            0
        }

        let primary = RateWindow(
            usedPercent: max(0, min(100, usedPercent)),
            windowMinutes: nil,
            resetsAt: data.resetDate,
            resetDescription: data.resetDate.map { self.resetDescription(from: $0) })

        return UsageSnapshot(
            primary: primary,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }

    /// Format reset date into human-readable description
    private func resetDescription(from date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval <= 0 {
            return "Reset now"
        }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            return "Resets in \(days)d"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }
}
