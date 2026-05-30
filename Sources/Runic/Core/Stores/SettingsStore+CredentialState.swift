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
