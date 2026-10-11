import Foundation
import Testing
@testable import Runic

/// A theme names its kit in `style.skin`; the registry must hand back that
/// kit, never the silent fallback. Catches a typo in a theme file and a skin
/// that was written but never registered.
struct RunicSkinRegistryTests {
    @MainActor
    @Test
    func `every bundled theme resolves to the skin it names`() {
        for theme in Theme.allCases {
            let palette = theme.palette
            let skin = RunicSkinRegistry.skin(for: palette)
            #expect(skin.id == palette.skinID, "\(theme.rawValue) asks for \(palette.skinID), got \(skin.id)")
        }
    }

    @Test
    func `skin ids are unique and the registry lists every kit`() {
        let ids = RunicSkinRegistry.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.contains(StandardSkin.skinID))
        #expect(ids.contains(GazetteSkin.skinID))
        #expect(ids.contains(SumiSkin.skinID))
    }

    @MainActor
    @Test
    func `gazette and sumi keep their kits, the rest draw standard`() {
        #expect(Theme.gazette.palette.skinID == GazetteSkin.skinID)
        #expect(Theme.sumi.palette.skinID == SumiSkin.skinID)
        #expect(Theme.system.palette.skinID == StandardSkin.skinID)
        #expect(Theme.terminal.palette.skinID == StandardSkin.skinID)
    }

    @Test
    func `an unknown skin id falls back to the standard kit`() {
        var style = RunicThemeStyle.standard
        style.skin = "no-such-kit"
        var palette = Theme.system.palette
        palette.style = style
        #expect(RunicSkinRegistry.skin(for: palette).id == StandardSkin.skinID)
    }

    @Test
    func `keyValue splits a labelled insight line`() {
        let pair = RunicSumi.keyValue("Context health: max ctx ~272K")
        #expect(pair?.key == "Context health")
        #expect(pair?.value == "max ctx ~272K")
        #expect(RunicSumi.keyValue("Effective retained context after compaction is not inferred: yes") == nil)
        #expect(RunicSumi.keyValue("no colon here") == nil)
    }

    @Test
    func `front page headline follows the average`() {
        #expect(RunicSumi.headline(forAverage: nil) == "No quota yet")
        #expect(RunicSumi.headline(forAverage: 81) == "Running hot")
        #expect(RunicSumi.headline(forAverage: 50) == "Steady")
        #expect(RunicSumi.headline(forAverage: 12) == "Plenty left")
        #expect(RunicSumi.headline(forAverage: 99) == "Spent")
    }
}
