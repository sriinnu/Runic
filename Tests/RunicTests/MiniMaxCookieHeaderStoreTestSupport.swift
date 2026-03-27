@testable import Runic

struct NoopMiniMaxCookieHeaderStore: MiniMaxCookieHeaderStoring {
    func loadHeader() throws -> String? {
        nil
    }

    func storeHeader(_ header: String?) throws {
        _ = header
    }
}
