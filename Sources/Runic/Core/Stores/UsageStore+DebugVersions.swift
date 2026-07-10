import Foundation
import RunicCore

extension UsageStore {
    func detectVersions() {
        Task.detached { [claudeFetcher] in
            let codexVer = ProviderVersionDetector.codexVersion()
            let claudeVer = claudeFetcher.detectVersion()
            let geminiVer = ProviderVersionDetector.geminiVersion()
            let antigravityVer = await AntigravityStatusProbe.detectVersion()
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
