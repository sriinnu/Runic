import Foundation

enum InstallOrigin {
    static let homebrewCask = "sriinnu/tap/runic"

    static var homebrewUpgradeCommand: String {
        "brew upgrade --cask \(self.homebrewCask)"
    }

    static var homebrewUpdaterUnavailableReason: String {
        "Updates managed by Homebrew. Run: \(self.homebrewUpgradeCommand)"
    }

    static func isHomebrewCask(appBundleURL: URL) -> Bool {
        let resolved = appBundleURL.resolvingSymlinksInPath()
        let path = resolved.path
        return path.contains("/Caskroom/") || path.contains("/Homebrew/Caskroom/")
    }
}
