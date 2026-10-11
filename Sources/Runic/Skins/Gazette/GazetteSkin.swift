import RunicCore
import SwiftUI

/// The printed edition. Pages come from `GazetteMenuCardViews.swift` and the
/// kit from `RunicGazetteChrome.swift`; the chrome slots the shared surfaces
/// still gate on `isGazette` move here as they are migrated.
struct GazetteSkin: RunicSkin {
    static let skinID = "gazette"
    var id: String {
        Self.skinID
    }

    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView? {
        AnyView(GazetteUsageCard(model: model, width: width))
    }

    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView? {
        AnyView(GazetteOverviewBody(view: view))
    }

    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView? {
        AnyView(
            GazetteFooter(
                byline: "By \(RunicSkinImprint.author)",
                bylineURL: RunicSkinImprint.authorURL,
                imprint: "Runic \(RunicVersion.marketing) \u{00B7} \(RunicGazette.edition)",
                buttonTitle: "About \u{2192}",
                action: context.openAbout)
                .frame(width: context.width)
                .padding(.top, RunicSpacing.xxs))
    }

    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome? {
        // A 10pt corner inside a 1pt ink border, whatever the theme's corner
        // multiplier says.
        RunicSkinPopoverChrome(cornerRadius: 10, strokeWidth: 1, strokeColor: palette.primaryText)
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        // Newsprint has no boxes to inset from: panel text shares the page
        // margin with the rules.
        RunicSpacing.xxs
    }

    var showsTabTray: Bool {
        false
    }
}
