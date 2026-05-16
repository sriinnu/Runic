import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct LocalLLMProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .localLLM
}
