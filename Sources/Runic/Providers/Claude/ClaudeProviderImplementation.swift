import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct ClaudeProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .claude
    let supportsLoginFlow: Bool = true

    @MainActor
    func runLoginFlow(context: ProviderLoginContext) async -> Bool {
        await context.controller.runClaudeLoginFlow()
        return true
    }
}
