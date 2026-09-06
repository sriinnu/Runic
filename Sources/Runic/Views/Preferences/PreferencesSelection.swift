import Foundation
import Observation
import RunicCore

@MainActor
@Observable
final class PreferencesSelection {
    var tab: PreferencesTab = .general
    /// Provider to focus when the Providers pane opens in sidebar layout
    /// (deep links, screenshot renders). A China slot selects its brand row and
    /// flips the region switch to China.
    var provider: UsageProvider?
}

enum PreferencesTab: String, Hashable, CaseIterable, Identifiable {
    case general
    case providers
    case analytics
    case sync
    case performance
    case about
    case debug

    var id: String {
        self.rawValue
    }

    static let windowWidth: CGFloat = 560
    static let windowHeight: CGFloat = 726

    var preferredHeight: CGFloat {
        PreferencesTab.windowHeight
    }
}
