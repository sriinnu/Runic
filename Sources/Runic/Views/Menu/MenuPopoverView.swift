import AppKit
import RunicCore
import SwiftUI

struct MenuPopoverActions {
    let installUpdate: () -> Void
    let refresh: () -> Void
    let openDashboard: () -> Void
    let openStatusPage: () -> Void
    let switchAccount: (UsageProvider) -> Void
    let exportCSV: (UsageExporter.Scope) -> Void
    let exportJSON: (UsageExporter.Scope) -> Void
    let openSettings: () -> Void
    /// Open Settings → Providers focused on this slot (used by "Add China" /
    /// "Add International" rows for a brand with two regions).
    let openProviderSettings: (UsageProvider) -> Void
    let openAbout: () -> Void
    let quit: () -> Void
    let copyError: (String) -> Void
}

@MainActor
struct MenuPopoverView: View {
    @Environment(\.runicFonts) var fonts
    @Bindable var store: UsageStore
    @Bindable var settings: SettingsStore
    let account: AccountInfo
    let updateReady: Bool
    let width: CGFloat
    /// Popover height. Renders pass a taller canvas to capture the whole
    /// scroll content; the live popover keeps the default.
    var height: CGFloat = 680
    let actions: MenuPopoverActions
    let onSelectProvider: (UsageProvider?) -> Void

    @State var selectedProvider: UsageProvider?
    @State var selectedPanel: PopoverInsightPanel?
    @State var selectedTimelineRange: UsageTimelineChartMenuView.TimeRange = .sevenDays
    @State private var hasAppeared = false

    init(
        store: UsageStore,
        settings: SettingsStore,
        account: AccountInfo,
        updateReady: Bool,
        initialProvider: UsageProvider?,
        initialPanel: PopoverInsightPanel? = nil,
        width: CGFloat,
        height: CGFloat = 680,
        actions: MenuPopoverActions,
        onSelectProvider: @escaping (UsageProvider?) -> Void)
    {
        self.store = store
        self.settings = settings
        self.account = account
        self.updateReady = updateReady
        self.width = width
        self.height = height
        self.actions = actions
        self.onSelectProvider = onSelectProvider
        self._selectedProvider = State(initialValue: initialProvider)
        self._selectedPanel = State(initialValue: initialPanel)
    }

    var body: some View {
        let palette = self.settings.theme.palette
        let popoverRadius = min(palette.shape.cornerRadius(18), 14)
        let enabledProviders = self.store.menuVisibleProviders()
        let provider = self.effectiveProvider(enabledProviders: enabledProviders)
        let isOverview = provider == nil && enabledProviders.count > 1

        ZStack {
            MenuPopoverBackground(showsProviderTabs: enabledProviders.count > 1)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: RunicSpacing.menuPanelSpacing) {
                    if enabledProviders.count > 1 {
                        self.providerTabs(providers: enabledProviders, selected: provider)
                    }

                    // A two-region brand stacks a card per configured slot
                    // under one tab, with an offer to add the missing side.
                    let slots = provider.map { self.brandSlots(for: $0, in: enabledProviders) } ?? []
                    let leadSlot = slots.first
                    let missingSlot = provider.flatMap { self.missingBrandSlot(for: $0, in: enabledProviders) }

                    Group {
                        if isOverview {
                            MenuPopoverSurfaceCard {
                                self.overviewView(providers: enabledProviders)
                            }
                        } else if !slots.isEmpty {
                            VStack(alignment: .leading, spacing: RunicSpacing.menuControlSpacing) {
                                ForEach(slots, id: \.rawValue) { slot in
                                    if let model = self.menuCardModel(for: slot) {
                                        MenuPopoverSurfaceCard {
                                            UsageMenuCardView(model: model, width: self.contentWidth)
                                                .environment(\.menuItemHighlighted, false)
                                        }
                                    }
                                }
                                if let missingSlot {
                                    self.addRegionRow(for: missingSlot)
                                }
                            }
                        } else {
                            MenuPopoverSurfaceCard {
                                self.emptyProviderState
                            }
                        }
                    }
                    .frame(width: self.contentWidth, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    self.resetScheduleSection(
                        providers: isOverview ? enabledProviders : slots,
                        isOverview: isOverview)

                    if let leadSlot, !isOverview {
                        self.insightSection(provider: leadSlot)
                        if let panel = self.effectivePanel(from: self.availablePanels(for: leadSlot)) {
                            self.exportSection(panel: panel)
                        }
                    }

                    self.actionSections(provider: leadSlot ?? provider, isOverview: isOverview)

                    if palette.id == "retro" {
                        RetroTaglineFooter()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, RunicSpacing.xs)
                    }
                }
                .padding(.horizontal, self.outerHorizontalPadding)
                .padding(.top, self.outerVerticalPadding)
                .padding(.bottom, self.outerVerticalPadding)
            }
        }
        .frame(width: self.width, height: self.height)
        .environment(\.runicTheme, palette)
        .runicColorScheme(palette)
        .runicTypography()
        .foregroundStyle(palette.primaryText)
        .tint(palette.accent)
        .clipShape(RoundedRectangle(cornerRadius: popoverRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: popoverRadius, style: .continuous)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: palette.style.chrome.borderWeight,
                        dash: []))
                .foregroundStyle(palette.cardStroke.opacity(palette.style.chrome.borderOpacity))
        }
        .retroBevel(baseRadius: popoverRadius)
        .shadow(
            color: Color.black.opacity(palette.id == "retro" ? 0.22 : 0.24 + palette.style.effects.glowStrength * 0.12),
            radius: palette.shape.separator == .glow ? 22 : (palette.id == "retro" ? 12 : 20),
            y: palette.shape.separator == .glow ? 14 : (palette.id == "retro" ? 6 : 10))
        .onAppear {
            withAnimation(palette.motion.curve) {
                self.hasAppeared = true
            }
            self.store.ensureLedgerHistoryCovers(days: self.selectedTimelineRange.days)
        }
        .onChange(of: self.selectedTimelineRange) { _, range in
            self.store.ensureLedgerHistoryCovers(days: range.days)
        }
        .animation(palette.motion.curve, value: self.selectedProvider)
        .animation(palette.motion.curve, value: self.selectedPanel)
    }

    var contentWidth: CGFloat {
        max(0, self.width - (self.outerHorizontalPadding * 2))
    }

    var outerHorizontalPadding: CGFloat {
        self.settings.theme.palette.density.padding(RunicSpacing.menuOuterInset)
    }

    var outerVerticalPadding: CGFloat {
        self.settings.theme.palette.density.padding(RunicSpacing.menuPanelSpacing)
    }

    var panelInset: CGFloat {
        self.settings.theme.palette.density.padding(RunicSpacing.menuPanelInset)
    }

    var panelContentWidth: CGFloat {
        max(0, self.contentWidth - (self.panelInset * 2))
    }

    var panelBodyWidth: CGFloat {
        max(0, self.panelContentWidth - (RunicSpacing.menuPanelBodyInset * 2))
    }

    /// "Add China account" / "Add International account" under a brand's
    /// stacked cards. Opens Settings → Providers on that slot.
    private func addRegionRow(for slot: UsageProvider) -> some View {
        let brand = UsageProvider.compactDisplayName(self.store.metadata(for: slot.brandRoot).displayName)
        return MenuPopoverSurfaceCard {
            MenuPopoverActionButton(
                title: "Add \(brand) \(slot.region.displayName) account",
                systemImage: "plus.circle",
                iconIntent: .action,
                style: .compact,
                action: { self.actions.openProviderSettings(slot) })
                .padding(self.panelInset)
        }
        .frame(width: self.contentWidth, alignment: .leading)
    }

    private var emptyProviderState: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(spacing: RunicSpacing.xs) {
                RunicThemedSystemIcon(
                    systemName: "sparkles",
                    intent: .info,
                    font: self.fonts.subheadline.weight(.semibold),
                    width: RunicSpacing.menuIconColumnWidth)
                Text("No active providers")
                    .font(self.fonts.subheadline.weight(.semibold))
            }
            Text("Open Settings, enable a provider, then refresh.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.settings.theme.palette.secondaryText)
        }
        .padding(self.panelInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func effectiveProvider(enabledProviders: [UsageProvider]) -> UsageProvider? {
        if enabledProviders.count > 1, self.selectedProvider == nil {
            return nil
        }
        if let selectedProvider {
            // A brand tab selects its root; accept it when any of the
            // brand's slots is visible (only the China side may be set up).
            if enabledProviders.contains(where: { $0.brandRoot == selectedProvider.brandRoot }) {
                return selectedProvider
            }
        }
        return enabledProviders.first ?? .codex
    }

    func selectProvider(_ provider: UsageProvider?) {
        self.selectedProvider = provider
        self.selectedPanel = nil
        self.onSelectProvider(provider)
    }
}
