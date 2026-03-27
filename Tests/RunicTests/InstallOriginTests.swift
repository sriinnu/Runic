import Foundation
import Testing
@testable import Runic

struct InstallOriginTests {
    @Test
    func `detects homebrew caskroom`() {
        #expect(
            InstallOrigin
                .isHomebrewCask(
                    appBundleURL: URL(fileURLWithPath: "/opt/homebrew/Caskroom/runic/1.0.0/Runic.app")))
        #expect(
            InstallOrigin
                .isHomebrewCask(appBundleURL: URL(fileURLWithPath: "/usr/local/Caskroom/runic/1.0.0/Runic.app")))
        #expect(!InstallOrigin.isHomebrewCask(appBundleURL: URL(fileURLWithPath: "/Applications/Runic.app")))
    }
}
