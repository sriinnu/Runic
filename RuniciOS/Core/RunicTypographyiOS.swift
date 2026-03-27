import SwiftUI

/// iOS font scale — mirrors the macOS RunicFont for cross-platform consistency.
enum RunicFont {
    static let caption2 = Font.system(.caption2, design: .monospaced)
    static let caption = Font.system(.caption, design: .monospaced)
    static let footnote = Font.system(.footnote, design: .monospaced)
    static let callout = Font.system(.callout, design: .monospaced)
    static let body = Font.system(.body, design: .monospaced)
    static let subheadline = Font.system(.subheadline, design: .monospaced)
    static let headline = Font.system(.headline, design: .monospaced)
    static let title3 = Font.system(.title3, design: .monospaced)
    static let title2 = Font.system(.title2, design: .monospaced)
    static let title = Font.system(.title, design: .monospaced)
    static let largeTitle = Font.system(.largeTitle, design: .monospaced)

    static func system(size: CGFloat) -> Font {
        Font.system(size: size, design: .monospaced)
    }

    static func system(size: CGFloat, weight: Font.Weight) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
}
