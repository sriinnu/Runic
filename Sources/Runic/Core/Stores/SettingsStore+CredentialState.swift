import Foundation

struct SettingsStoreCredentialStores {
    let zai: any ZaiTokenStoring
    let minimax: any MiniMaxTokenStoring
    let minimaxCookieHeader: any MiniMaxCookieHeaderStoring
    let minimaxGroupID: any MiniMaxGroupIDStoring
    let copilot: any CopilotTokenStoring
    let openRouter: any OpenRouterTokenStoring
    let vercelAI: any VercelAITokenStoring
    let groq: any GroqTokenStoring
    let deepSeek: any DeepSeekTokenStoring
    let fireworks: any FireworksTokenStoring
    let mistral: any MistralTokenStoring
    let perplexity: any PerplexityTokenStoring
    let kimi: any KimiTokenStoring
    let auggie: any AuggieTokenStoring
    let together: any TogetherTokenStoring
    let cohere: any CohereTokenStoring
    let xai: any XAITokenStoring
    let cerebras: any CerebrasTokenStoring
    let sambaNova: any SambaNovaTokenStoring
    let qwen: any QwenTokenStoring
    let azureOpenAI: any AzureOpenAITokenStoring
}

extension SettingsStore {
    convenience init(
        userDefaults: UserDefaults = .standard,
        zaiTokenStore: any ZaiTokenStoring = KeychainZaiTokenStore(),
        minimaxTokenStore: any MiniMaxTokenStoring = KeychainMiniMaxTokenStore(),
        minimaxCookieHeaderStore: any MiniMaxCookieHeaderStoring = KeychainMiniMaxCookieHeaderStore(),
        minimaxGroupIDStore: any MiniMaxGroupIDStoring = KeychainMiniMaxGroupIDStore(),
        copilotTokenStore: any CopilotTokenStoring = KeychainCopilotTokenStore(),
        openRouterTokenStore: any OpenRouterTokenStoring = KeychainOpenRouterTokenStore(),
        vercelAITokenStore: any VercelAITokenStoring = KeychainVercelAITokenStore(),
        groqTokenStore: any GroqTokenStoring = KeychainGroqTokenStore(),
        deepSeekTokenStore: any DeepSeekTokenStoring = KeychainDeepSeekTokenStore(),
        fireworksTokenStore: any FireworksTokenStoring = KeychainFireworksTokenStore(),
        mistralTokenStore: any MistralTokenStoring = KeychainMistralTokenStore(),
        perplexityTokenStore: any PerplexityTokenStoring = KeychainPerplexityTokenStore(),
        kimiTokenStore: any KimiTokenStoring = KeychainKimiTokenStore(),
        auggieTokenStore: any AuggieTokenStoring = KeychainAuggieTokenStore(),
        togetherTokenStore: any TogetherTokenStoring = KeychainTogetherTokenStore(),
        cohereTokenStore: any CohereTokenStoring = KeychainCohereTokenStore(),
        xaiTokenStore: any XAITokenStoring = KeychainXAITokenStore(),
        cerebrasTokenStore: any CerebrasTokenStoring = KeychainCerebrasTokenStore(),
        sambaNovaTokenStore: any SambaNovaTokenStoring = KeychainSambaNovaTokenStore(),
        qwenTokenStore: any QwenTokenStoring = KeychainQwenTokenStore(),
        azureOpenAITokenStore: any AzureOpenAITokenStoring = KeychainAzureOpenAITokenStore())
    {
        self.init(
            userDefaults: userDefaults,
            credentialStores: SettingsStoreCredentialStores(
                zai: zaiTokenStore,
                minimax: minimaxTokenStore,
                minimaxCookieHeader: minimaxCookieHeaderStore,
                minimaxGroupID: minimaxGroupIDStore,
                copilot: copilotTokenStore,
                openRouter: openRouterTokenStore,
                vercelAI: vercelAITokenStore,
                groq: groqTokenStore,
                deepSeek: deepSeekTokenStore,
                fireworks: fireworksTokenStore,
                mistral: mistralTokenStore,
                perplexity: perplexityTokenStore,
                kimi: kimiTokenStore,
                auggie: auggieTokenStore,
                together: togetherTokenStore,
                cohere: cohereTokenStore,
                xai: xaiTokenStore,
                cerebras: cerebrasTokenStore,
                sambaNova: sambaNovaTokenStore,
                qwen: qwenTokenStore,
                azureOpenAI: azureOpenAITokenStore))
    }
}

struct SettingsStoreCredentialPersistTasks {
    var zai: Task<Void, Never>?
    var minimax: Task<Void, Never>?
    var minimaxCookieHeader: Task<Void, Never>?
    var minimaxGroupID: Task<Void, Never>?
    var copilot: Task<Void, Never>?
    var openRouter: Task<Void, Never>?
    var vercelAI: Task<Void, Never>?
    var groq: Task<Void, Never>?
    var deepSeek: Task<Void, Never>?
    var fireworks: Task<Void, Never>?
    var mistral: Task<Void, Never>?
    var perplexity: Task<Void, Never>?
    var kimi: Task<Void, Never>?
    var auggie: Task<Void, Never>?
    var together: Task<Void, Never>?
    var cohere: Task<Void, Never>?
    var xai: Task<Void, Never>?
    var cerebras: Task<Void, Never>?
    var sambaNova: Task<Void, Never>?
    var qwen: Task<Void, Never>?
    var azureOpenAI: Task<Void, Never>?
}
