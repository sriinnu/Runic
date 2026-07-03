import Foundation
import Testing
@testable import Runic

struct CustomProviderUsageDisplayTests {
    @Test
    func `percent rounds instead of truncating`() {
        #expect(CustomProviderUsageDisplay.percentUsed(used: 99.9, quota: 100) == 100)
        #expect(CustomProviderUsageDisplay.percentUsed(used: 45.4, quota: 100) == 45)
        #expect(CustomProviderUsageDisplay.percentUsed(used: 45.5, quota: 100) == 46)
    }

    @Test
    func `percent clamps to 0 through 100`() {
        #expect(CustomProviderUsageDisplay.percentUsed(used: 15, quota: 10) == 100)
        #expect(CustomProviderUsageDisplay.percentUsed(used: -5, quota: 100) == 0)
    }

    @Test
    func `zero or negative quota yields zero`() {
        #expect(CustomProviderUsageDisplay.percentUsed(used: 5, quota: 0) == 0)
        #expect(CustomProviderUsageDisplay.percentUsed(used: 5, quota: -10) == 0)
    }
}
