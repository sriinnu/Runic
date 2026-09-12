import AppKit
import SwiftUI

@MainActor
struct PreferencesView: View {
    @Environment(\.runicFonts) private var fonts

    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    let updater: UpdaterProviding
    @Bindable var selection: PreferencesSelection

    @State private var providersSection: ProvidersSubSection = .builtIn
    @State private var performanceSection: PerformanceSubSection = .monitoring
    @State private var aboutSection: AboutSubSection = .about

    // MARK: - Sub-section enums

    enum ProvidersSubSection: String, CaseIterable, Identifiable {
        case builtIn
        case custom

        var id: String {
            self.rawValue
        }

        var label: String {
            switch self {
            case .builtIn: "Built-in"
            case .custom: "Custom"
            }
        }
    }

    enum PerformanceSubSection: String, CaseIterable, Identifiable {
        case monitoring
        case refresh

        var id: String {
            self.rawValue
        }

        var label: String {
            switch self {
            case .monitoring: "Monitoring"
            case .refresh: "Refresh & Safety"
            }
        }
    }

    enum AboutSubSection: String, CaseIterable, Identifiable {
        case about
        case help

        var id: String {
            self.rawValue
        }

        var label: String {
            switch self {
            case .about: "About"
            case .help: "Help"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            self.tabStrip
            if !self.settings.theme.palette.isPaperCutout {
                Rectangle()
                    .fill(self.settings.theme.palette.menuSeparatorColor)
                    .frame(height: 1)
            }
            self.content(for: self.selection.tab)
        }
        .runicTypography()
        .id(self.settings.visualSettingsRevision)
        .environment(\.runicTheme, self.settings.theme.palette)
        .runicColorScheme(self.settings.theme.palette)
        .foregroundStyle(self.settings.theme.palette.primaryText)
        .tint(self.settings.theme.palette.accent)
        .background {
            ZStack {
                if self.settings.theme.palette.isPaperCutout {
                    // Sky behind the tab strip, the sheet's cut edge just
                    // under the tabs so they read as folder tabs on it.
                    RunicPaperStage(skyBand: Self.paperSkyBand, hillHeight: 96)
                        .environment(\.runicTheme, self.settings.theme.palette)
                } else {
                    self.settings.theme.palette.surface
                    LiquidMeshBackground()
                        .opacity(self.meshBackgroundOpacity)
                    if self.settings.theme.palette.hasSurfaceTexture {
                        RunicSurfaceTextureOverlay()
                            .environment(\.runicTheme, self.settings.theme.palette)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .frame(
            minWidth: PreferencesTab.windowWidth,
            idealWidth: PreferencesTab.windowWidth,
            maxWidth: PreferencesTab.windowWidth,
            minHeight: PreferencesTab.windowHeight,
            idealHeight: PreferencesTab.windowHeight,
            maxHeight: .infinity,
            alignment: .center)
        .onAppear {
            self.ensureValidTabSelection()
        }
        .onChange(of: self.settings.debugMenuEnabled) { _, _ in
            self.ensureValidTabSelection()
        }
    }

    /// Tab strip height on paper: vertical padding + the 56pt tab, minus a
    /// few points so the tabs overlap the sheet's top edge.
    private static let paperSkyBand: CGFloat = RunicSpacing.sm + 56 - 2

    private var visibleTabs: [PreferencesTab] {
        PreferencesTab.allCases.filter { self.settings.debugMenuEnabled || $0 != .debug }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RunicSpacing.xs) {
                ForEach(self.visibleTabs) { tab in
                    self.tabButton(tab)
                }
            }
            .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
            .padding(.vertical, RunicSpacing.sm)
        }
        .background(self.settings.theme.palette.isPaperCutout
            ? Color.clear
            : self.settings.theme.palette.surfaceAlt.opacity(self.headerBackgroundOpacity))
    }

    @ViewBuilder
    private func content(for tab: PreferencesTab) -> some View {
        switch tab {
        case .general:
            GeneralPane(settings: self.settings, store: self.store)
        case .providers:
            ZStack {
                LiquidMeshBackground()
                    .ignoresSafeArea()
                    .opacity(self.settings.theme.palette.isTerminalHUD ? 1.0 : 0.3)
                VStack(spacing: 0) {
                    HStack(spacing: RunicSpacing.xs) {
                        RunicSegmentedPicker(
                            selection: self.$providersSection,
                            cases: ProvidersSubSection.allCases,
                            label: \.label)

                        if self.providersSection == .builtIn {
                            RunicSegmentedPicker(
                                selection: self.$settings.providersPaneSidebar,
                                options: [(false, "List"), (true, "Sidebar")])
                                .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
                    .padding(.top, RunicSpacing.sm)
                    .padding(.bottom, RunicSpacing.xs)

                    switch self.providersSection {
                    case .builtIn:
                        ProvidersPane(
                            settings: self.settings,
                            store: self.store,
                            initialProvider: self.selection.provider)
                    case .custom:
                        CustomProvidersPane(settings: self.settings, store: self.store)
                    }
                }
            }
        case .analytics:
            AnalyticsPane(settings: self.settings, store: self.store)
        case .sync:
            SyncPane(settings: self.settings, store: self.store)
        case .performance:
            VStack(spacing: 0) {
                RunicSegmentedPicker(
                    selection: self.$performanceSection,
                    cases: PerformanceSubSection.allCases,
                    label: \.label)
                    .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
                    .padding(.top, RunicSpacing.sm)
                    .padding(.bottom, RunicSpacing.xs)

                switch self.performanceSection {
                case .monitoring:
                    PerformancePane(settings: self.settings, store: self.store)
                case .refresh:
                    AdvancedPane(settings: self.settings, store: self.store)
                }
            }
        case .about:
            VStack(spacing: 0) {
                RunicSegmentedPicker(selection: self.$aboutSection, cases: AboutSubSection.allCases, label: \.label)
                    .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
                    .padding(.top, RunicSpacing.sm)
                    .padding(.bottom, RunicSpacing.xs)

                switch self.aboutSection {
                case .about:
                    AboutPane(updater: self.updater)
                case .help:
                    HelpPane()
                }
            }
        case .debug:
            DebugPane(settings: self.settings, store: self.store)
        }
    }

    private func tabButton(_ tab: PreferencesTab) -> some View {
        let selected = self.selection.tab == tab
        return Button {
            withAnimation(.easeOut(duration: 0.14)) {
                self.selection.tab = tab
            }
        } label: {
            VStack(spacing: 3) {
                RunicThemedSystemIcon(
                    systemName: tab.symbolName,
                    intent: tab.iconIntent,
                    selected: selected,
                    font: .system(size: 18, weight: selected ? .semibold : .medium))
                    .frame(height: 22)
                Text(tab.label)
                    .font(self.fonts.hasDisplayFace
                        ? self.fonts.display(size: 13)
                        : self.fonts.caption.weight(selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 72, height: 56)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected
            ? self.settings.theme.palette.primaryText
            : self.settings.theme.palette.secondaryText)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? self.selectedTabFill(for: tab) : self.unselectedTabFill)
        }
        .overlay {
            if !self.settings.theme.palette.isPaperCutout {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? self.settings.theme.palette.accent.opacity(0.45) : .clear, lineWidth: 1)
            }
        }
        .runicCutout(
            radius: 8,
            lift: selected ? 0.8 : 0.4,
            seed: UInt64(tab.hashValue & 0xFF),
            tilt: selected ? 0 : ((self.visibleTabs.firstIndex(of: tab) ?? 0).isMultiple(of: 2) ? -1.2 : 1.1))
        .environment(\.runicTheme, self.settings.theme.palette)
    }

    private var meshBackgroundOpacity: Double {
        if self.settings.theme.palette.isTerminalHUD { return 1.0 }
        return self.settings.theme.palette.isCustom ? 0.38 : 0.12
    }

    private var headerBackgroundOpacity: Double {
        self.settings.theme.palette.isTerminalHUD ? 0.68 : 0.82
    }

    /// Kirigami tabs are folder tabs: every tab is a paper sticker, and the
    /// selected one takes a pastel of its own (each tab a different colour,
    /// the way a tabbed craft binder does). Other themes: accent wash.
    private func selectedTabFill(for tab: PreferencesTab) -> Color {
        let palette = self.settings.theme.palette
        if palette.isPaperCutout {
            return RunicPaperStage.pastel(self.visibleTabs.firstIndex(of: tab) ?? 0)
        }
        return palette.accent.opacity(palette.isTerminalHUD ? 0.18 : 0.12)
    }

    private var unselectedTabFill: Color {
        self.settings.theme.palette.isPaperCutout ? self.settings.theme.palette.cardFill : .clear
    }

    private func ensureValidTabSelection() {
        if !self.settings.debugMenuEnabled, self.selection.tab == .debug {
            self.selection.tab = .general
        }
    }
}

extension PreferencesTab {
    var label: String {
        switch self {
        case .general: "General"
        case .providers: "Providers"
        case .analytics: "Analytics"
        case .sync: "Sync"
        case .performance: "Performance"
        case .about: "About"
        case .debug: "Debug"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .providers: "square.grid.2x2"
        case .analytics: "chart.bar.xaxis"
        case .sync: "arrow.triangle.2.circlepath"
        case .performance: "speedometer"
        case .about: "info.circle"
        case .debug: "ladybug"
        }
    }

    var iconIntent: RunicIconIntent {
        .navigation
    }
}
