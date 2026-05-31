import RunicCore
import SwiftUI

struct ProviderUsageStatus {
    let text: String
    let style: Style

    enum Style {
        case success
        case error
        case neutral
    }
}

enum ProviderListMetrics {
    static let contentInset: CGFloat = 16
    static let listHeaderCornerRadius: CGFloat = RunicCornerRadius.md
    static let listHeaderPadding: EdgeInsets = .init(
        top: RunicSpacing.xs,
        leading: RunicSpacing.md,
        bottom: RunicSpacing.xs,
        trailing: RunicSpacing.md)
    static let listHeaderBackgroundOpacity: Double = 0.26
    static let listHeaderBorderOpacity: Double = 0.2
    static let rowSpacing: CGFloat = RunicSpacing.sm
    static let reorderHandleSize: CGFloat = 12
    static let reorderDotSize: CGFloat = 4
    static let reorderDotSpacing: CGFloat = 4
    static let rowInsets = EdgeInsets(
        top: RunicSpacing.xxs,
        leading: contentInset,
        bottom: RunicSpacing.xxs,
        trailing: contentInset)
    static let sectionEdgeInset: CGFloat = RunicSpacing.md
    static let dividerBottomInset: CGFloat = RunicSpacing.xxs
    static let checkboxSize: CGFloat = 20
    static let iconSize: CGFloat = 34
    static let dividerLeadingInset: CGFloat = contentInset
    static let dividerTrailingInset: CGFloat = contentInset
    static let providerCardPadding = EdgeInsets(
        top: RunicSpacing.sm,
        leading: RunicSpacing.sm,
        bottom: RunicSpacing.sm,
        trailing: RunicSpacing.sm)
    static let providerCardBackgroundOpacity: Double = 0.55
    static let providerCardBorderOpacity: Double = 0.25
    static let providerCardCornerRadius: CGFloat = RunicCornerRadius.md
    static let providerInsightsCardCornerRadius: CGFloat = RunicCornerRadius.sm
    static let providerInsightsGridItemMinWidth: CGFloat = 210
    static let providerInsightsChipCornerRadius: CGFloat = RunicCornerRadius.sm
    static let providerInsightsChipSpacing: CGFloat = RunicSpacing.xxs
    static let providerInsightsChipPadding: CGFloat = RunicSpacing.xs

    static let supplementalCardPadding = EdgeInsets(
        top: RunicSpacing.sm,
        leading: RunicSpacing.sm,
        bottom: RunicSpacing.sm,
        trailing: RunicSpacing.sm)
    static let supplementalCardBackgroundOpacity: Double = 0.28
    static let supplementalCardBorderOpacity: Double = 0.18
    static let fieldMaxWidth: CGFloat = 420
    static let errorCardPadding: CGFloat = RunicSpacing.sm
    static let statusBadgePaddingH: CGFloat = RunicSpacing.xs
    static let statusBadgePaddingV: CGFloat = RunicSpacing.xxxs
    static let errorCardCornerRadius: CGFloat = RunicCornerRadius.sm
    static let insightsCardPadding: CGFloat = RunicSpacing.xs
    static let insightsLineSpacing: CGFloat = RunicSpacing.xxxs
    static let insightsLabelWidth: CGFloat = 84
    static let sidebarStatusLabelWidth: CGFloat = 62
    static let sidebarCardCornerRadius: CGFloat = RunicCornerRadius.md
    static let sidebarCardPadding: CGFloat = RunicSpacing.md
    static let sidebarCardBackgroundOpacity: Double = 0.36
    static let sidebarCardBorderOpacity: Double = 0.22
    static let sidebarMicroCardCornerRadius: CGFloat = RunicCornerRadius.sm
    static let sidebarMicroCardBackgroundOpacity: Double = 0.52
    static let sidebarMicroCardBorderOpacity: Double = 0.2
    static let sidebarSectionSpacing: CGFloat = RunicSpacing.md
    static let sidebarContentGap: CGFloat = RunicSpacing.sm
}
