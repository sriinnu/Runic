import Foundation

/// Corner radius tokens replacing scattered literal values throughout the UI.
enum RunicCornerRadius {
    /// 4pt — badges, small tags, inline controls
    static let xs: CGFloat = 4
    /// 6pt — list rows, compact cards, buttons
    static let sm: CGFloat = 6
    /// 8pt — standard cards, menu sections
    static let md: CGFloat = 8
    /// 12pt — prominent panels, avatar frames, provider cards
    static let lg: CGFloat = 12
    /// 16pt — large icons, about pane, hero elements
    static let xl: CGFloat = 16
}
