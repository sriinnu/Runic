import SwiftUI

extension EnvironmentValues {
    @Entry var menuItemHighlighted: Bool = false
}

enum MenuHighlightStyle {
    static let selectionText = Color(nsColor: .selectedMenuItemTextColor)

    static func error(_ highlighted: Bool, theme _: RunicThemePalette) -> Color {
        highlighted ? self.selectionText : RunicColors.error
    }
}
