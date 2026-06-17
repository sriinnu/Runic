import Foundation
import RunicCore
import RunicMacroSupport

/// opencode is BYOK and history-only (usage comes from its local message log),
/// so there's no login flow and no API-key field to manage here.
@ProviderImplementationRegistration
struct OpencodeProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .opencode
}
