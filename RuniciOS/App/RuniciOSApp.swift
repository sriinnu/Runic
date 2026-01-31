import SwiftUI
import RunicCore

@main
struct RuniciOSApp: App {
    @StateObject private var usageStore = iOSUsageStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var alertManager = AlertManager()
    @StateObject private var syncEngine = iCloudSyncEngine()

    init() {
        // Configure app on launch
        configureAppearance()
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(usageStore)
                .environmentObject(settingsStore)
                .environmentObject(alertManager)
                .environmentObject(syncEngine)
                .onAppear {
                    Task {
                        await usageStore.initialRefresh()
                        await syncEngine.startSync()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        await usageStore.refresh()
                    }
                }
        }
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    private func registerBackgroundTasks() {
        // Register background refresh task
        // BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.sriinnu.runic.refresh") { ... }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var usageStore: iOSUsageStore
    @EnvironmentObject var alertManager: AlertManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Main providers list
            ProviderListView()
                .tabItem {
                    Label("Providers", systemImage: "server.rack")
                }
                .tag(0)

            // Model usage breakdown
            ModelUsageView()
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
                .tag(1)

            // Project tracking
            ProjectTrackingView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(2)

            // Alerts
            AlertsView()
                .tabItem {
                    Label("Alerts", systemImage: "bell.badge")
                }
                .badge(alertManager.activeAlerts.count)
                .tag(3)

            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .overlay(alignment: .top) {
            // Active alerts banner
            if let alert = alertManager.activeAlerts.first {
                AlertBannerView(alert: alert)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
