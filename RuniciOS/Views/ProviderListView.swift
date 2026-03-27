import SwiftUI
import RunicCore

struct ProviderListView: View {
    @EnvironmentObject var usageStore: iOSUsageStore
    @State private var searchText = ""
    @State private var refreshing = false

    var filteredProviders: [EnhancedUsageSnapshot] {
        let snapshots = usageStore.snapshots.values.sorted {
            $0.provider.rawValue < $1.provider.rawValue
        }

        if searchText.isEmpty {
            return snapshots
        }

        return snapshots.filter {
            $0.provider.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section {
                    SummaryCardView(snapshots: Array(usageStore.snapshots.values))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Provider cards
                Section("Providers") {
                    ForEach(filteredProviders, id: \.provider) { snapshot in
                        NavigationLink {
                            ProviderDetailView(snapshot: snapshot)
                        } label: {
                            ProviderRowView(snapshot: snapshot)
                        }
                    }
                }
            }
            .navigationTitle("Runic")
            .searchable(text: $searchText, prompt: "Search providers")
            .refreshable {
                await usageStore.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { Task { await usageStore.refresh() } }) {
                            Label("Refresh All", systemImage: "arrow.clockwise")
                        }
                        Button(action: { /* Show sort options */ }) {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        Button(action: { /* Show filter options */ }) {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

// MARK: - Summary Card

struct SummaryCardView: View {
    let snapshots: [EnhancedUsageSnapshot]

    var totalProviders: Int { snapshots.count }
    var criticalProviders: Int {
        snapshots.filter { $0.primary.usedPercent >= 90 }.count
    }
    var warningProviders: Int {
        snapshots.filter { $0.primary.usedPercent >= 75 && $0.primary.usedPercent < 90 }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatView(
                    value: "\(totalProviders)",
                    label: "Total",
                    color: .blue
                )
                Divider()
                StatView(
                    value: "\(criticalProviders)",
                    label: "Critical",
                    color: .red
                )
                Divider()
                StatView(
                    value: "\(warningProviders)",
                    label: "Warning",
                    color: .orange
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }
}

struct StatView: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(RunicFont.title2.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(RunicFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Provider Row

struct ProviderRowView: View {
    let snapshot: EnhancedUsageSnapshot

    var statusColor: Color {
        let usage = snapshot.primary.usedPercent
        if usage >= 90 { return .red }
        if usage >= 75 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Provider icon and name
                Image(systemName: iconForProvider(snapshot.provider))
                    .font(RunicFont.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.provider.rawValue.capitalized)
                        .font(RunicFont.headline)

                    if let email = snapshot.accountEmail {
                        Text(email)
                            .font(RunicFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Usage percentage
                Text("\(Int(snapshot.primary.usedPercent))%")
                    .font(RunicFont.title3.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor.gradient)
                        .frame(width: geometry.size.width * snapshot.primary.usedPercent / 100)
                }
            }
            .frame(height: 8)

            // Reset info
            if let resetInfo = snapshot.primaryReset,
               let timeRemaining = resetInfo.timeUntilReset,
               timeRemaining > 0 {
                HStack {
                    Image(systemName: "clock")
                        .font(RunicFont.caption2)
                    Text(resetInfo.resetDescription)
                        .font(RunicFont.caption)
                }
                .foregroundStyle(.secondary)
            }

            // Model info
            if let model = snapshot.primaryModel {
                HStack {
                    Image(systemName: "cpu.fill")
                        .font(RunicFont.caption2)
                    Text(model.modelName)
                        .font(RunicFont.caption)
                }
                .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForProvider(_ provider: UsageProvider) -> String {
        switch provider.rawValue {
        case "claude": return "brain"
        case "codex", "openai": return "terminal"
        case "gemini": return "diamond"
        case "cursor": return "cursorarrow.rays"
        case "copilot": return "airplane"
        default: return "server.rack"
        }
    }
}

#Preview {
    ProviderListView()
        .environmentObject(iOSUsageStore())
}
