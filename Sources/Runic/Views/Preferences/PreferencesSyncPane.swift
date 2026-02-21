import AppKit
import RunicCore
import SwiftUI

@MainActor
struct SyncPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    @State private var selectedSection: SyncSection = .integrations

    enum SyncSection: String, CaseIterable, Identifiable {
        case integrations
        case teams

        var id: String { self.rawValue }

        var label: String {
            switch self {
            case .integrations: return "Integrations"
            case .teams: return "Teams"
            }
        }

        var icon: String {
            switch self {
            case .integrations: return "link"
            case .teams: return "person.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sub-section picker
            Picker("", selection: self.$selectedSection) {
                ForEach(SyncSection.allCases) { section in
                    Label(section.label, systemImage: section.icon).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
            .padding(.top, PreferencesLayoutMetrics.paneVertical)
            .padding(.bottom, RunicSpacing.sm)

            // Content
            switch self.selectedSection {
            case .integrations:
                IntegrationsPane(settings: self.settings, store: self.store)
            case .teams:
                TeamManagementView(settings: self.settings, store: self.store)
            }
        }
    }
}
