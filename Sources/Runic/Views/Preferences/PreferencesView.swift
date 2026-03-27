import AppKit
import SwiftUI

@MainActor
struct PreferencesView: View {
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

        var id: String { self.rawValue }

        var label: String {
            switch self {
            case .builtIn: return "Built-in"
            case .custom: return "Custom"
            }
        }
    }

    enum PerformanceSubSection: String, CaseIterable, Identifiable {
        case monitoring
        case refresh

        var id: String { self.rawValue }

        var label: String {
            switch self {
            case .monitoring: return "Monitoring"
            case .refresh: return "Refresh & Safety"
            }
        }
    }

    enum AboutSubSection: String, CaseIterable, Identifiable {
        case about
        case help

        var id: String { self.rawValue }

        var label: String {
            switch self {
            case .about: return "About"
            case .help: return "Help"
            }
        }
    }

    var body: some View {
        TabView(selection: self.$selection.tab) {
            // MARK: - General

            GeneralPane(settings: self.settings, store: self.store)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(PreferencesTab.general)

            // MARK: - Providers (Built-in + Custom)

            ZStack {
                LiquidMeshBackground().ignoresSafeArea().opacity(0.3)
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
            .tabItem {
                Label("Providers", systemImage: "square.grid.2x2")
            }
            .tag(PreferencesTab.providers)

            // MARK: - Analytics (Display + Insights + Alerts + Budgets)

            AnalyticsPane(settings: self.settings, store: self.store)
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }
                .tag(PreferencesTab.analytics)

            // MARK: - Sync (Integrations + Teams)

            SyncPane(settings: self.settings, store: self.store)
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(PreferencesTab.sync)

            // MARK: - Performance (Monitoring + Refresh/Safety)

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
            .tabItem {
                Label("Performance", systemImage: "speedometer")
            }
            .tag(PreferencesTab.performance)

            // MARK: - About (About + Help)

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
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
            .tag(PreferencesTab.about)

            // MARK: - Debug (conditional)

            if self.settings.debugMenuEnabled {
                DebugPane(settings: self.settings, store: self.store)
                    .tabItem {
                        Label("Debug", systemImage: "ladybug")
                    }
                    .tag(PreferencesTab.debug)
            }
        }
        .runicTypography()
        .tabViewStyle(.automatic)
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

    private func ensureValidTabSelection() {
        if !self.settings.debugMenuEnabled, self.selection.tab == .debug {
            self.selection.tab = .general
        }
    }
}
