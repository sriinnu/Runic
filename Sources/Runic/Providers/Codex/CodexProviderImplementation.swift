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

    @MainActor
    func settingsToggles(context: ProviderSettingsContext) -> [ProviderSettingsToggleDescriptor] {
        [
            ProviderSettingsToggleDescriptor(
                id: "codex-openai-web-access",
                title: "Access OpenAI via web",
                subtitle: "Enable credits history and usage breakdown via browser cookies.",
                binding: context.boolBinding(\.openAIWebAccessEnabled),
                statusText: {
                    context.store.openAIDashboardCookieImportStatus ?? context.store.lastOpenAIDashboardError
                },
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "codex-import-openai-web-cookies",
                        title: "Import Browser Cookies Now",
                        style: .bordered,
                        isVisible: nil,
                        perform: {
                            await context.store.importOpenAIDashboardBrowserCookiesNow()
                        }),
                ],
                isVisible: nil,
                onChange: nil,
                onAppDidBecomeActive: nil,
                onAppearWhenEnabled: nil),
        ]
    }
}
