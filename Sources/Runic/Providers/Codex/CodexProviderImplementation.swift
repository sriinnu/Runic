import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct CodexProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .codex
    let supportsLoginFlow: Bool = true

    @MainActor
    func runLoginFlow(context: ProviderLoginContext) async -> Bool {
        await context.controller.runCodexLoginFlow()
        return true
    }
}
