import AppKit
import RunicCore
import RunicMacroSupport
import SwiftUI

@ProviderImplementationRegistration
struct CopilotProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .copilot
    let supportsLoginFlow: Bool = true

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "copilot-api-token",
                title: "GitHub Login",
                subtitle: "Stored in Keychain (encrypted). Sign in via GitHub Device Flow below.",
                kind: .secure,
                placeholder: "Sign in via button below",
                binding: context.stringBinding(\.copilotAPIToken),
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "copilot-login",
                        title: "Sign in with GitHub",
                        style: .bordered,
                        isVisible: { context.settings.copilotAPIToken.isEmpty },
                        perform: {
                            let didLogin = await CopilotLoginFlow.run(settings: context.settings)
                            guard didLogin else { return }
                            await context.store.refresh(trigger: .login)
                        }),
                    ProviderSettingsActionDescriptor(
                        id: "copilot-relogin",
                        title: "Sign in again",
                        style: .link,
                        isVisible: { !context.settings.copilotAPIToken.isEmpty },
                        perform: {
                            let didLogin = await CopilotLoginFlow.run(settings: context.settings)
                            guard didLogin else { return }
                            await context.store.refresh(trigger: .login)
                        }),
                ],
                isVisible: nil),
        ]
    }

    @MainActor
    func runLoginFlow(context: ProviderLoginContext) async -> Bool {
        let didLogin = await CopilotLoginFlow.run(settings: context.controller.settings)
        guard didLogin else { return false }
        await context.controller.store.refresh(trigger: .login)
        return true
    }
}
