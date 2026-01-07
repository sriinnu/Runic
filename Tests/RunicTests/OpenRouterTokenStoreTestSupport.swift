@testable import Runic

struct NoopOpenRouterTokenStore: OpenRouterTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopGroqTokenStore: GroqTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}
