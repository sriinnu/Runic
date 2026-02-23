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

struct NoopDeepSeekTokenStore: DeepSeekTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopFireworksTokenStore: FireworksTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopMistralTokenStore: MistralTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopPerplexityTokenStore: PerplexityTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopKimiTokenStore: KimiTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopAuggieTokenStore: AuggieTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopTogetherTokenStore: TogetherTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopCohereTokenStore: CohereTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopXAITokenStore: XAITokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopCerebrasTokenStore: CerebrasTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}

struct NoopSambaNovaTokenStore: SambaNovaTokenStoring {
    func loadToken() throws -> String? { nil }
    func storeToken(_ token: String?) throws {
        _ = token
    }
}
