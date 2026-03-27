import Foundation

/// **Runic Spacing System**
/// Defines global spacing constants following a 4pt grid system.
/// All spacing values are multiples of 4 for consistent visual rhythm.
enum RunicSpacing {
    // MARK: - Base Spacing Scale

    /// Extra extra extra small spacing (2pt)
    static let xxxs: CGFloat = 2

    /// Extra extra small spacing (4pt)
    static let xxs: CGFloat = 4

    /// Extra small spacing (8pt)
    static let xs: CGFloat = 8

    /// Small spacing (12pt)
    static let sm: CGFloat = 12

    /// Medium spacing (16pt)
    static let md: CGFloat = 16

    /// Large spacing (24pt)
    static let lg: CGFloat = 24

    /// Extra large spacing (32pt)
    static let xl: CGFloat = 32

    /// Extra extra large spacing (48pt)
    static let xxl: CGFloat = 48

    // MARK: - Semantic Spacing

    /// Horizontal padding for menu content
    static let menuHorizontalPadding: CGFloat = sm // 12pt

    /// Vertical padding for menu content
    static let menuVerticalPadding: CGFloat = xs // 8pt

    /// Spacing between cards in menu
    static let cardSpacing: CGFloat = xs // 8pt

    /// Spacing between major sections
    static let sectionSpacing: CGFloat = lg // 24pt

    // MARK: - Preferences Spacing

    /// Compact spacing (6pt) - Used between sm and xs, common in preference toggles
    static let compact: CGFloat = 6

    /// Standardized spacing for toggle rows
    static let toggleRowSpacing: CGFloat = xs // 8pt

    /// Spacing after section headers
    static let sectionHeaderSpacing: CGFloat = md // 16pt

    /// Spacing within stepper controls
    static let stepperControlSpacing: CGFloat = xs // 8pt

    // MARK: - Chart Metrics

    /// Standard height for chart views in menus
    static let chartHeight: CGFloat = 130

    /// Diameter for legend dot indicators
    static let chartLegendDot: CGFloat = 7
}
