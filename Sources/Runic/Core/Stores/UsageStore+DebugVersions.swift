import Foundation
import RunicCore

extension UsageStore {
    func detectVersions() {
        Task.detached { [claudeFetcher] in
            let codexVer = ProviderVersionDetector.codexVersion()
            let claudeVer = claudeFetcher.detectVersion()
            let geminiVer = ProviderVersionDetector.geminiVersion()
            let desktopVer = await AntigravityStatusProbe.detectVersion()
            let cliVer = await AntigravityCLIProbe.detectVersion()
            let antigravityVer: String? = switch (desktopVer, cliVer) {
            case let (.some(desktop), .some(cli)): "\(desktop) · agy \(cli)"
            case let (.some(desktop), nil): desktop
            case let (nil, .some(cli)): "agy \(cli)"
            case (nil, nil): nil
            }
            await MainActor.run {
                self.codexVersion = codexVer
                self.claudeVersion = claudeVer
                self.geminiVersion = geminiVer
                self.zaiVersion = nil
                self.antigravityVersion = antigravityVer
            }
        }
    }
}
