import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct CursorProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .cursor
    let supportsLoginFlow: Bool = true

    @MainActor
    func runLoginFlow(context: ProviderLoginContext) async -> Bool {
        await context.controller.runCursorLoginFlow()
        return true
    }
}
