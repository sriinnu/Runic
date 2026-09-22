import RunicCore
import SwiftUI

/// Per-provider reload (↻). Unlike the menu's Ping, it first lets the provider
/// re-read credentials that changed outside Runic — e.g. Claude after a
/// terminal `/login` — which may show one Keychain prompt.
@MainActor
struct ProviderReloadButton: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider
    @Bindable var store: UsageStore
    let isEnabled: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let isBusy = self.store.refreshSlots(for: self.provider)
            .contains { self.store.refreshingProviders.contains($0) }
        let name = self.store.metadata(for: self.provider).displayName

        Button {
            Task { await self.store.reloadProvider(self.provider) }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(self.fonts.callout.weight(.medium))
                .foregroundStyle(self.runicTheme.secondaryText)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!self.isEnabled || isBusy)
        .opacity(self.isEnabled ? (isBusy ? 0.35 : 1) : 0.25)
        .help("Reload \(name): re-read credentials and fetch usage now")
        .accessibilityLabel("Reload \(name)")
    }
}
