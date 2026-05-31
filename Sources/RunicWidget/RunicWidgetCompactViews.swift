import RunicCore
import SwiftUI

struct CompactMetricView: View {
    let entry: WidgetSnapshot.ProviderEntry
    let metric: CompactMetric

    var body: some View {
        let display = self.display
        VStack(alignment: .leading, spacing: 8) {
            HeaderView(provider: self.entry.provider, updatedAt: self.entry.updatedAt)
            VStack(alignment: .leading, spacing: 2) {
                Text(display.value)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(display.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let detail = display.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }

    private var display: (value: String, label: String, detail: String?) {
        switch self.metric {
        case .credits:
            let value = self.entry.creditsRemaining.map(WidgetFormat.credits) ?? "—"
            return (value, "Credits left", nil)
        case .todayCost:
            let value = self.entry.tokenUsage?.sessionCostUSD.map(WidgetFormat.usd) ?? "—"
            let detail = self.entry.tokenUsage?.sessionTokens.map(WidgetFormat.tokenCount)
            return (value, "Today cost", detail)
        case .last30DaysCost:
            let value = self.entry.tokenUsage?.last30DaysCostUSD.map(WidgetFormat.usd) ?? "—"
            let detail = self.entry.tokenUsage?.last30DaysTokens.map(WidgetFormat.tokenCount)
            return (value, "30d cost", detail)
        }
    }
}
