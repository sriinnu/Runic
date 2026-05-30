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
            Rectangle()
                .fill(self.settings.theme.palette.menuSeparatorColor)
                .frame(height: 1)
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
                self.settings.theme.palette.surface
                LiquidMeshBackground()
                    .opacity(self.meshBackgroundOpacity)
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
        .background(self.settings.theme.palette.surfaceAlt.opacity(self.headerBackgroundOpacity))
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
                        Picker("", selection: self.$providersSection) {
                            ForEach(ProvidersSubSection.allCases) { section in
                                Text(section.label).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)

                        if self.providersSection == .builtIn {
                            Picker("", selection: self.$settings.providersPaneSidebar) {
                                Text("List").tag(false)
                                Text("Sidebar").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
                    .padding(.top, RunicSpacing.sm)
                    .padding(.bottom, RunicSpacing.xs)

                    switch self.providersSection {
                    case .builtIn:
                        ProvidersPane(settings: self.settings, store: self.store)
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
                Picker("", selection: self.$performanceSection) {
                    ForEach(PerformanceSubSection.allCases) { section in
                        Text(section.label).tag(section)
                    }
                }
                .pickerStyle(.segmented)
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
                Picker("", selection: self.$aboutSection) {
                    ForEach(AboutSubSection.allCases) { section in
                        Text(section.label).tag(section)
                    }
                }
                .pickerStyle(.segmented)
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
                    .font(self.fonts.caption.weight(selected ? .semibold : .medium))
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
                .fill(selected ? self.selectedTabFill : .clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? self.settings.theme.palette.accent.opacity(0.45) : .clear, lineWidth: 1)
        }
    }

    private var meshBackgroundOpacity: Double {
        if self.settings.theme.palette.isTerminalHUD { return 1.0 }
        return self.settings.theme.palette.isCustom ? 0.38 : 0.12
    }

    private var headerBackgroundOpacity: Double {
        self.settings.theme.palette.isTerminalHUD ? 0.68 : 0.82
    }

    private var selectedTabFill: Color {
        self.settings.theme.palette.accent.opacity(self.settings.theme.palette.isTerminalHUD ? 0.18 : 0.12)
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
