@testable import Runic

struct NoopZaiTokenStore: ZaiTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_: String?) throws {}
}
