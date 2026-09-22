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

    /// A `/login` in the terminal rewrites the CLI's Keychain item behind
    /// Runic's back; re-read it here, off the main actor since it may prompt.
    func prepareManualReload() async {
        await Task.detached(priority: .userInitiated) {
            ClaudeOAuthCredentialsStore.reloadIfSourceChanged()
        }.value
    }
}
