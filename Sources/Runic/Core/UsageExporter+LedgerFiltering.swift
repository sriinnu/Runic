import Foundation
import RunicCore

extension UsageExporter {
    static func filteredLedgerDailySummaries(
        store: UsageStore,
        provider: UsageProvider,
        days: Int?) -> [UsageLedgerDailySummary]
    {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoff = days.flatMap { calendar.date(byAdding: .day, value: -($0 - 1), to: today) }
        return store.ledgerAllDailySummary(for: provider)
            .filter { summary in
                guard let cutoff else { return true }
                return summary.dayStart >= cutoff
            }
            .sorted { $0.dayStart < $1.dayStart }
    }
}
