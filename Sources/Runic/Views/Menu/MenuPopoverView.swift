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
        width: CGFloat,
        actions: MenuPopoverActions,
        onSelectProvider: @escaping (UsageProvider?) -> Void)
    {
        self.store = store
        self.settings = settings
        self.account = account
        self.updateReady = updateReady
        self.width = width
        self.actions = actions
        self.onSelectProvider = onSelectProvider
        self._selectedProvider = State(initialValue: initialProvider)
    }

    var body: some View {
        let palette = self.settings.theme.palette
        let popoverRadius = min(palette.shape.cornerRadius(18), 14)
        let enabledProviders = self.store.enabledProviders()
        let provider = self.effectiveProvider(enabledProviders: enabledProviders)
        let isOverview = provider == nil && enabledProviders.count > 1

        ZStack {
            MenuPopoverBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: RunicSpacing.menuPanelSpacing) {
                    if enabledProviders.count > 1 {
                        self.providerTabs(providers: enabledProviders, selected: provider)
                    }

                    Group {
                        if isOverview {
                            MenuPopoverSurfaceCard {
                                self.overviewView(providers: enabledProviders)
                            }
                        } else if let provider, let model = self.menuCardModel(for: provider) {
                            MenuPopoverSurfaceCard {
                                UsageMenuCardView(model: model, width: self.contentWidth)
                                    .environment(\.menuItemHighlighted, false)
                            }
                        } else {
                            MenuPopoverSurfaceCard {
                                self.emptyProviderState
                            }
                        }
                    }
                    .frame(width: self.contentWidth, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    if let provider, !isOverview {
                        self.insightSection(provider: provider)
                        if let panel = self.effectivePanel(from: self.availablePanels(for: provider)) {
                            self.exportSection(panel: panel)
                        }
                    }

                    self.actionSections(provider: provider, isOverview: isOverview)

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
        .frame(width: self.width, height: 680)
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
        if let selectedProvider, enabledProviders.contains(selectedProvider) {
            return selectedProvider
        }
        return enabledProviders.first ?? .codex
    }

    func selectProvider(_ provider: UsageProvider?) {
        self.selectedProvider = provider
        self.selectedPanel = nil
        self.onSelectProvider(provider)
    }
}
