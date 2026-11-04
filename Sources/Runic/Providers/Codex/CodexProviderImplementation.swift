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

    /// API credits live on platform.openai.com, apart from the ChatGPT login
    /// Codex uses. That dashboard's API takes a bearer token rather than cookies,
    /// so a browser's cookies can't help: this always signs in inside Runic.
    @MainActor
    func settingsToggles(context: ProviderSettingsContext) -> [ProviderSettingsToggleDescriptor] {
        let capture = WebSignInWindow.HeaderCapture(
            siteHost: "platform.openai.com",
            apiPrefix: OpenAIPlatformCredits.apiPrefix)
        return [
            BrowserSignInToggle.descriptor(
                id: "codex-api-credits",
                title: "API credit balance from OpenAI",
                subtitle: "Shows what's left of your OpenAI API credits and when the next grant expires. API keys "
                    + "can't read this, so turning it on asks you to sign in to platform.openai.com once in a Runic "
                    + "window. Runic keeps that login's token in its own Keychain item, sends it only to "
                    + "api.openai.com, and asks you to sign in again when it expires.",
                hooks: BrowserSignInToggle.Hooks(
                    site: "platform.openai.com",
                    isConnected: { OpenAIPlatformCredits.isConnected },
                    connect: { throw OpenAIPlatformCredits.Failure.needsSignIn },
                    disconnect: { OpenAIPlatformCredits.disconnect() },
                    lastFailure: { OpenAIPlatformCredits.lastFailure },
                    signIn: WebSignInWindow.Step(
                        site: "platform.openai.com",
                        url: OpenAIPlatformCredits.signInURL,
                        validate: { _ in
                            guard let headers = capture.headers else { return nil }
                            return await OpenAIPlatformCredits.validate(
                                authorization: headers.authorization,
                                organization: headers.organization)
                        },
                        headerCapture: capture)),
                context: context),
        ]
    }
}
