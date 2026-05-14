import Foundation
import Testing
@testable import Runic

@Suite(.serialized)
struct RunicScreenshotModeTests {
    @Test
    func `leaves email unchanged when disabled`() {
        unsetenv("RUNIC_SCREENSHOT_MODE")

        #expect(RunicScreenshotMode.sanitize(email: "real-user@example.com") == "real-user@example.com")
    }

    @Test
    func `replaces email when enabled`() {
        setenv("RUNIC_SCREENSHOT_MODE", "1", 1)
        defer { unsetenv("RUNIC_SCREENSHOT_MODE") }

        #expect(RunicScreenshotMode.sanitize(email: "real-user@example.com") == "demo@runic.app")
    }
}
