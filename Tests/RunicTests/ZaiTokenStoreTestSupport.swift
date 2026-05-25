@testable import Runic

struct NoopZaiTokenStore: ZaiTokenStoring {
    func loadToken() throws -> String? {
        nil
    }

    func storeToken(_: String?) throws {}
}

final class CountingZaiTokenStore: ZaiTokenStoring, @unchecked Sendable {
    private(set) var loadCount = 0

    func loadToken() throws -> String? {
        self.loadCount += 1
        return "saved-token"
    }

    func storeToken(_: String?) throws {}
}
