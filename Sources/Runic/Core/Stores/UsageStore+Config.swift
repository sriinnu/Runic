import Foundation
import RunicCore

@MainActor
extension UsageStore {
    /// Apply a loaded config's non-empty overrides into settings.
    ///
    /// The config file is authoritative for the values it specifies. Empty or absent
    /// values leave the existing setting untouched, so a seeded or empty config never
    /// wipes a value the user set in the UI. Overall precedence:
    /// config (non-empty) > UI setting > environment > built-in default.
    func applyConfigToSettings(_ config: RunicConfig) {
        if let endpoint = config.providers["qwen"]?.endpoint,
           !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            self.settings.qwenBaseURL = endpoint
        }
        if let endpoint = config.providers["qwenCN"]?.endpoint,
           !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            self.settings.qwenCNBaseURL = endpoint
        }
        if !config.logPaths.isEmpty {
            self.settings.otelGenAILogPaths = config.logPaths.joined(separator: "\n")
        }
        self.appliedConfig = config
        Task { await self.recomputeQuotaGauges() }
    }

    /// Called by the config-file watcher when `config.json` changes: apply, then re-fetch
    /// so the new endpoints/log paths take effect immediately — no relaunch, no rebuild.
    func configChanged(_ config: RunicConfig) async {
        self.applyConfigToSettings(config)
        await self.refresh(trigger: .configFile)
    }
}
