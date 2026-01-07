@testable import Runic

struct NoopMiniMaxTokenStore: MiniMaxTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}
