import AppKit
import SwiftUI
import Testing
@testable import Runic

struct ThemeColorTokenTests {
    private func rgb(_ color: Color, appearance: NSAppearance.Name) -> [Int] {
        var out: [Int] = []
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
            out = [c.redComponent, c.greenComponent, c.blueComponent].map { Int(($0 * 255).rounded()) }
        }
        return out
    }

    @MainActor
    @Test
    func `a light|dark pair follows the appearance`() throws {
        let color = try #require(Color(colorToken: "#102030|#A0B0C0"))
        #expect(self.rgb(color, appearance: .aqua) == [0x10, 0x20, 0x30])
        #expect(self.rgb(color, appearance: .darkAqua) == [0xA0, 0xB0, 0xC0])
    }

    @Test
    func `a pair with a bad half is rejected`() {
        #expect(Color(colorToken: "#102030|nope") == nil)
    }
}
