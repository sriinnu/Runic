import Foundation
import RunicCore

/// Prepaid providers (DeepSeek, Kimi, StepFun...) only report a balance, so
/// spend today / this month is the difference between readings. Readings used
/// to come from refreshes alone, and with refresh on Manual (or switched to
/// Manual after idle) a week could hold two of them — the Spend row stayed
/// empty. This loop takes a reading on its own cadence regardless of the
/// refresh mode. Balance endpoints are one cheap GET, and every key they use
/// is Runic-owned, so it never prompts.
extension UsageStore {
    static let balanceSampleInterval: TimeInterval = 20 * 60
    /// Seeds the loop before any snapshot exists (fresh launch in Manual mode).
    static let knownBalanceProviders: Set<UsageProvider> = [
        .deepseek, .kimi, .kimiCN, .stepfun, .stepfunCN, .openrouter, .vercelai, .cline,
    ]

    func startBalanceSampler() {
        self.balanceSamplerTask?.cancel()
        self.balanceSamplerTask = Task.detached(priority: .utility) { [weak self] in
            // A short delay lets launch-time work settle, then one baseline
            // reading so the next one already yields a spend figure.
            try? await Task.sleep(for: .seconds(60))
            while !Task.isCancelled {
                await self?.sampleBalances()
                try? await Task.sleep(for: .seconds(Self.balanceSampleInterval))
            }
        }
    }

    func balanceSampleTargets() -> [UsageProvider] {
        self.enabledProviders().filter { provider in
            if let snapshot = self.snapshots[provider] { return snapshot.balance != nil }
            return Self.knownBalanceProviders.contains(provider)
        }
    }

    private func sampleBalances() async {
        for provider in self.balanceSampleTargets() where !self.refreshingProviders.contains(provider) {
            guard !Task.isCancelled else { return }
            await self.refreshProvider(provider, trigger: .autoTimer)
        }
    }
}
