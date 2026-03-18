import SwiftUI

/// Animation presets used across the Runic UI.
enum RunicAnimation {
    // MARK: - Spring Presets

    /// Standard appear animation for progress bars and chart elements.
    static let barAppear: Animation = .spring(response: 0.6, dampingFraction: 0.75)

    /// Value-change animation for progress bars.
    static let barUpdate: Animation = .spring(response: 0.5, dampingFraction: 0.8)

    /// Menu content fade when switching providers.
    static let providerSwitch: Animation = .easeInOut(duration: 0.25)

    /// Highlight state transitions on menu items.
    static let highlight: Animation = .easeOut(duration: 0.12)

    // MARK: - Transition Durations

    /// Duration for sheen / gloss sweeps on progress bars.
    static let sheenDuration: Double = 0.9

    /// Delay before sheen resets after sweeping.
    static let sheenResetDelay: Duration = .seconds(1.1)

    /// Duration for copy-confirmation checkmark display.
    static let copyFeedbackDuration: Duration = .seconds(0.9)

    /// Fade-out duration for copy confirmation revert.
    static let copyFeedbackFadeOut: Animation = .easeOut(duration: 0.2)

    // MARK: - Skeleton / Loading

    /// Continuous shimmer animation for loading skeletons.
    static let shimmer: Animation = .easeInOut(duration: 1.5).repeatForever(autoreverses: false)

    /// Subtle hover feedback on interactive elements.
    static let hoverFeedback: Animation = .easeInOut(duration: 0.15)

    // MARK: - Chart Interaction

    /// Fade animation for chart interaction hints.
    static let chartHintFade: Animation = .easeOut(duration: 0.4)

    // MARK: - Menu Card Entrance

    /// Staggered spring entrance for menu card sections.
    static let cardEntrance: Animation = .spring(response: 0.45, dampingFraction: 0.82)

    /// Base delay between staggered card section entrances.
    static let cardEntranceStagger: Double = 0.06
}
