import Foundation

/// **Runic Spacing System**
/// Defines global spacing constants on a 4pt grid, with tiny optical
/// correction tokens for borders, glyph alignment, and compact controls.
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

    // MARK: - Menu Surface Spacing

    /// Outer inset for the menu popover content.
    static let menuOuterInset: CGFloat = md // 16pt

    /// Consistent inner inset for popover cards and panels.
    static let menuPanelInset: CGFloat = sm // 12pt

    /// Gap between sibling popover panels.
    static let menuPanelSpacing: CGFloat = sm // 12pt

    /// Gap between controls inside a popover panel.
    static let menuControlSpacing: CGFloat = xs // 8pt

    /// Small inset for section bodies inside a popover panel.
    static let menuPanelBodyInset: CGFloat = xs // 8pt

    /// Shared icon column width for menu rows and compact actions.
    static let menuIconColumnWidth: CGFloat = 20

    /// Compact icon column for action-list rows inside popover panels.
    static let menuActionIconColumnWidth: CGFloat = 16

    /// Tight icon-to-label gap for action-list rows.
    static let menuActionIconTextSpacing: CGFloat = xxs // 4pt

    /// Horizontal padding inside popover row controls.
    static let menuControlHorizontalPadding: CGFloat = xs // 8pt

    /// Leading offset from a panel's content edge to the readable text column.
    static let menuReadableColumnOffset: CGFloat =
        menuControlHorizontalPadding + menuIconColumnWidth + menuControlSpacing

    /// Vertical padding inside popover row controls.
    static let menuControlVerticalPadding: CGFloat = xxs + xxxs // 6pt

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
