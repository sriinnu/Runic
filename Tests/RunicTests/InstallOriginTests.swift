import Foundation
import Testing
@testable import Runic

@Suite
struct InstallOriginTests {
    @Test
    func detectsHomebrewCaskroom() {
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
