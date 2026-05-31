import RunicCore
import SwiftUI
import WidgetKit

struct RunicUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RunicWidgetEntry

    var body: some View {
        let providerEntry = self.entry.snapshot.entries.first { $0.provider == self.entry.provider }
        ZStack {
            Color.black.opacity(0.02)
            if let providerEntry {
                self.content(providerEntry: providerEntry)
            } else {
                self.emptyState
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private func content(providerEntry: WidgetSnapshot.ProviderEntry) -> some View {
        switch self.family {
        case .systemSmall:
            SmallUsageView(entry: providerEntry)
        case .systemMedium:
            MediumUsageView(entry: providerEntry)
        default:
            LargeUsageView(entry: providerEntry)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open Runic")
                .font(.body)
                .fontWeight(.semibold)
            Text("Usage data will appear once the app refreshes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

struct RunicHistoryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RunicWidgetEntry

    var body: some View {
        let providerEntry = self.entry.snapshot.entries.first { $0.provider == self.entry.provider }
        ZStack {
            Color.black.opacity(0.02)
            if let providerEntry {
                HistoryView(entry: providerEntry, isLarge: self.family == .systemLarge)
            } else {
                self.emptyState
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open Runic")
                .font(.body)
                .fontWeight(.semibold)
            Text("Usage history will appear after a refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

struct RunicCompactWidgetView: View {
    let entry: RunicCompactEntry

    var body: some View {
        let providerEntry = self.entry.snapshot.entries.first { $0.provider == self.entry.provider }
        ZStack {
            Color.black.opacity(0.02)
            if let providerEntry {
                CompactMetricView(entry: providerEntry, metric: self.entry.metric)
            } else {
                self.emptyState
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open Runic")
                .font(.body)
                .fontWeight(.semibold)
            Text("Usage data will appear once the app refreshes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

struct RunicSwitcherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RunicSwitcherEntry

    var body: some View {
        let providerEntry = self.entry.snapshot.entries.first { $0.provider == self.entry.provider }
        ZStack {
            Color.black.opacity(0.02)
            VStack(alignment: .leading, spacing: 10) {
                ProviderSwitcherRow(
                    providers: self.entry.availableProviders,
                    selected: self.entry.provider,
                    updatedAt: providerEntry?.updatedAt ?? Date(),
                    compact: self.family == .systemSmall,
                    showsTimestamp: self.family != .systemSmall)
                if let providerEntry {
                    self.content(providerEntry: providerEntry)
                } else {
                    self.emptyState
                }
            }
            .padding(12)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private func content(providerEntry: WidgetSnapshot.ProviderEntry) -> some View {
        switch self.family {
        case .systemSmall:
            SwitcherSmallUsageView(entry: providerEntry)
        case .systemMedium:
            SwitcherMediumUsageView(entry: providerEntry)
        default:
            SwitcherLargeUsageView(entry: providerEntry)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open Runic")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Usage data appears after a refresh.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
