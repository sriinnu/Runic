import Foundation
import RunicCore

@MainActor
extension UsageStore {
    private static let autoEnableLog = RunicLog.logger("provider-auto-enable")

    /// Switch on every provider that has a credential in the environment but has
    /// never been toggled by the user. Runs once at startup so an exported
    /// `KIMI_API_KEY` / `DASHSCOPE_API_KEY` / `DEEPSEEK_API_KEY` is enough to add
    /// the provider; nobody should have to find the toggle. Environment only:
    /// keys saved through Preferences auto-enable at save time, and a bulk
    /// keychain sweep at launch is exactly the kind of read that triggers ACL
    /// prompts. Copilot is skipped — its resolver accepts a generic
    /// `GITHUB_TOKEN`, which says nothing about Copilot use. Explicit user
    /// choices are never overridden: `autoEnableProviderIfNeeded` is a no-op once
    /// a toggle has been saved.
    func autoEnableProvidersWithCredentials() {
        var enabled: [String] = []
        for provider in UsageProvider.allCases where provider != .copilot {
            let metadata = self.metadata(for: provider)
            guard !metadata.defaultEnabled,
                  !self.settings.hasSavedProviderToggle(cliName: metadata.cliName),
                  ProviderTokenResolver.credentialResolution(
                      for: provider, environment: self.processEnvironment, allowKeychain: false) != nil
            else { continue }
            self.settings.autoEnableProviderIfNeeded(cliName: metadata.cliName)
            enabled.append(metadata.displayName)
        }
        if !enabled.isEmpty {
            Self.autoEnableLog.info("Auto-enabled providers with credentials: \(enabled.joined(separator: ", "))")
        }
    }

    /// Same rule for evidence that arrives from logs: usage attributed to a
    /// provider (qwen/glm/kimi/deepseek calls routed through Claude Code) turns
    /// that provider on if the user never decided otherwise.
    func autoEnableProviderWithLedgerData(_ provider: UsageProvider) {
        let metadata = self.metadata(for: provider)
        guard !metadata.defaultEnabled,
              !self.settings.hasSavedProviderToggle(cliName: metadata.cliName)
        else { return }
        self.settings.autoEnableProviderIfNeeded(cliName: metadata.cliName)
        Self.autoEnableLog.info("Auto-enabled \(metadata.displayName): usage found in logs.")
    }
}
