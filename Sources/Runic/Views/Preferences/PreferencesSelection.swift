import Foundation
import Observation

@MainActor
@Observable
final class PreferencesSelection {
    var tab: PreferencesTab = .general
}

enum PreferencesTab: String, Hashable, CaseIterable, Identifiable {
    case general
    case providers
    case analytics
    case sync
    case performance
    case about
    case debug

    var id: String { self.rawValue }

    static let windowWidth: CGFloat = 560
    static let windowHeight: CGFloat = 726

    var preferredHeight: CGFloat { PreferencesTab.windowHeight }
}
