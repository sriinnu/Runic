import Foundation
import RunicCore
import Testing

struct MuseCodeCLIUsageFetcherTests {
    @Test
    func `parses subscription quota without model API headers`() throws {
        let text = """
        Muse Code High Usage
        Current 24% used · Resets at 7:39 PM
        Weekly 8% used · Resets Oct 5 at 2:00 AM
        """
        let snapshot = try MuseCodeCLIUsageFetcher.parse(text: text)
        #expect(snapshot.primary.usedPercent == 24)
        #expect(snapshot.primary.windowMinutes == 300)
        #expect(snapshot.secondary?.usedPercent == 8)
        #expect(snapshot.secondary?.windowMinutes == 10080)
        #expect(snapshot.primary.resetDescription?.contains("7:39 PM") == true)
    }

    @Test
    func `refuses unrelated or incomplete terminal output`() {
        #expect(throws: MuseCodeCLIUsageFetcher.Error.self) {
            try MuseCodeCLIUsageFetcher.parse(text: "Muse Code ready; /usage")
        }
        #expect(throws: MuseCodeCLIUsageFetcher.Error.self) {
            try MuseCodeCLIUsageFetcher.parse(text: "Current 24% used · Weekly 8% used")
        }
    }

    @Test
    func `restores spacing in compact terminal reset labels`() throws {
        let text = """
        Muse Code High Usage
        Current 25% used · Resetsat7:39PM
        Weekly 9% used · ResetsOct5at2:00AM
        """
        let snapshot = try MuseCodeCLIUsageFetcher.parse(text: text)
        #expect(snapshot.primary.resetDescription == "Resets at 7:39 PM")
        #expect(snapshot.secondary?.resetDescription == "Resets Oct 5 at 2:00 AM")
    }
}
