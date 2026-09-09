import RunicCore
import SwiftUI

extension MenuPopoverView {
    func resetScheduleInputs(for providers: [UsageProvider]) -> [ResetScheduleBuilder.ProviderInput] {
        providers.map { provider in
            ResetScheduleBuilder.ProviderInput(
                provider: provider,
                metadata: self.store.metadata(for: provider),
                snapshot: self.store.snapshot(for: provider),
                quotaWindows: self.store.quotaWindows[provider])
        }
    }

    /// Every reset-bearing window for the given providers, soonest first.
    func resetScheduleEntries(for providers: [UsageProvider]) -> [ResetScheduleEntry] {
        ResetScheduleBuilder.entries(self.resetScheduleInputs(for: providers))
    }

    /// "Resets" card. Overview lists every provider; a single provider lists
    /// just its own windows and banked resets. Hidden when there's nothing.
    @ViewBuilder
    func resetScheduleSection(providers: [UsageProvider], isOverview: Bool) -> some View {
        let inputs = self.resetScheduleInputs(for: providers)
        let entries = ResetScheduleBuilder.entries(inputs)
        let credits = ResetScheduleBuilder.credits(inputs)
        if !entries.isEmpty || !credits.isEmpty {
            MenuPopoverSurfaceCard {
                ResetScheduleMenuView(
                    entries: entries,
                    width: self.panelContentWidth,
                    showsProvider: isOverview,
                    credits: credits)
                    .padding(self.panelInset)
            }
            .frame(width: self.contentWidth, alignment: .leading)
        }
    }
}
