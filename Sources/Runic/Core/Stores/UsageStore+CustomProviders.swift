import Foundation
import RunicCore

extension UsageStore {
    /// Refresh all enabled custom providers.
    func refreshCustomProviders() async {
        let providers = CustomProviderStore.getEnabledProviders()
        await withTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask {
                    await self.refreshCustomProvider(id: provider.id)
                }
            }
        }
    }

    /// Refresh a single custom provider.
    func refreshCustomProvider(id: String) async {
        guard let config = CustomProviderStore.getProvider(id: id), config.enabled else {
            return
        }

        let fetcher = GenericProviderFetcher(config: config)
        let startTime = Date()
        let requestID = UUID().uuidString
        let providerLabel = Self.customProviderMetricLabel(config)

        do {
            let usageData = try await fetcher.fetchUsage()
            let endTime = Date()

            await self.trackLatency(
                provider: .openrouter,
                providerLabel: providerLabel,
                requestID: requestID,
                startTime: startTime,
                endTime: endTime,
                success: true)

            let snapshot = CustomProviderSnapshot.from(usageData: usageData.toCustomUsageData(), config: config)
            await MainActor.run {
                self.customProviderSnapshots[id] = snapshot
                self.customProviderErrors.removeValue(forKey: id)
            }
        } catch {
            let endTime = Date()

            await self.trackLatency(
                provider: .openrouter,
                providerLabel: providerLabel,
                requestID: requestID,
                startTime: startTime,
                endTime: endTime,
                success: false)
            await self.trackError(provider: .openrouter, providerLabel: providerLabel, error: error)

            await MainActor.run {
                self.customProviderErrors[id] = error.localizedDescription
            }
        }
    }

    /// Clear a custom provider snapshot.
    func clearCustomProviderSnapshot(id: String) {
        self.customProviderSnapshots.removeValue(forKey: id)
        self.customProviderErrors.removeValue(forKey: id)
    }
}
