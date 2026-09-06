import Foundation

struct SettingsStoreCredentialValues {
    var zaiAPIToken = ""
    var minimaxAPIToken = ""
    var minimaxCookieHeader = ""
    var minimaxGroupID = ""
    var copilotAPIToken = ""
    var openRouterAPIToken = ""
    var vercelAIAPIToken = ""
    var groqAPIToken = ""
    var deepSeekAPIToken = ""
    var fireworksAPIToken = ""
    var mistralAPIToken = ""
    var perplexityAPIToken = ""
    var kimiAPIToken = ""
    var kimiCNAPIToken = ""
    var zaiCNAPIToken = ""
    var minimaxCNAPIToken = ""
    var stepfunAPIToken = ""
    var stepfunCNAPIToken = ""
    var auggieAPIToken = ""
    var togetherAPIToken = ""
    var cohereAPIToken = ""
    var xaiAPIToken = ""
    var cerebrasAPIToken = ""
    var qwenAPIToken = ""
    var qwenCNAPIToken = ""
    var sambaNovaAPIToken = ""
    var azureOpenAIAPIToken = ""
}

extension SettingsStore {
    /// z.ai API token (stored in Keychain).
    var zaiAPIToken: String {
        get { self.credentialValues.zaiAPIToken }
        set {
            self.credentialValues.zaiAPIToken = newValue
            self.schedulePersistZaiAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "zai")
        }
    }

    /// MiniMax API token (stored in Keychain).
    var minimaxAPIToken: String {
        get { self.credentialValues.minimaxAPIToken }
        set {
            self.credentialValues.minimaxAPIToken = newValue
            self.schedulePersistMiniMaxAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "minimax")
        }
    }

    /// MiniMax manual Cookie header (stored in Keychain).
    var minimaxCookieHeader: String {
        get { self.credentialValues.minimaxCookieHeader }
        set {
            self.credentialValues.minimaxCookieHeader = newValue
            self.schedulePersistMiniMaxCookieHeader()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "minimax")
        }
    }

    /// MiniMax Group ID (stored in Keychain).
    var minimaxGroupID: String {
        get { self.credentialValues.minimaxGroupID }
        set {
            self.credentialValues.minimaxGroupID = newValue
            self.schedulePersistMiniMaxGroupID()
        }
    }

    /// Copilot API token (stored in Keychain).
    var copilotAPIToken: String {
        get { self.credentialValues.copilotAPIToken }
        set {
            self.credentialValues.copilotAPIToken = newValue
            self.schedulePersistCopilotAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "copilot")
        }
    }

    /// OpenRouter API key (stored in Keychain).
    var openRouterAPIToken: String {
        get { self.credentialValues.openRouterAPIToken }
        set {
            self.credentialValues.openRouterAPIToken = newValue
            self.schedulePersistOpenRouterAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "openrouter")
        }
    }

    /// Vercel AI Gateway API key (stored in Keychain).
    var vercelAIAPIToken: String {
        get { self.credentialValues.vercelAIAPIToken }
        set {
            self.credentialValues.vercelAIAPIToken = newValue
            self.schedulePersistVercelAIAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "vercelai")
        }
    }

    /// Groq API key (stored in Keychain).
    var groqAPIToken: String {
        get { self.credentialValues.groqAPIToken }
        set {
            self.credentialValues.groqAPIToken = newValue
            self.schedulePersistGroqAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "groq")
        }
    }

    /// DeepSeek API key (stored in Keychain).
    var deepSeekAPIToken: String {
        get { self.credentialValues.deepSeekAPIToken }
        set {
            self.credentialValues.deepSeekAPIToken = newValue
            self.schedulePersistDeepSeekAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "deepseek")
        }
    }

    /// Fireworks API key (stored in Keychain).
    var fireworksAPIToken: String {
        get { self.credentialValues.fireworksAPIToken }
        set {
            self.credentialValues.fireworksAPIToken = newValue
            self.schedulePersistFireworksAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "fireworks")
        }
    }

    /// Mistral API key (stored in Keychain).
    var mistralAPIToken: String {
        get { self.credentialValues.mistralAPIToken }
        set {
            self.credentialValues.mistralAPIToken = newValue
            self.schedulePersistMistralAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "mistral")
        }
    }

    /// Perplexity API key (stored in Keychain).
    var perplexityAPIToken: String {
        get { self.credentialValues.perplexityAPIToken }
        set {
            self.credentialValues.perplexityAPIToken = newValue
            self.schedulePersistPerplexityAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "perplexity")
        }
    }

    /// Kimi API key (stored in Keychain).
    var kimiAPIToken: String {
        get { self.credentialValues.kimiAPIToken }
        set {
            self.credentialValues.kimiAPIToken = newValue
            self.schedulePersistKimiAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "kimi")
        }
    }

    /// Kimi China (api.moonshot.cn) API key (stored in Keychain).
    var kimiCNAPIToken: String {
        get { self.credentialValues.kimiCNAPIToken }
        set {
            self.credentialValues.kimiCNAPIToken = newValue
            self.schedulePersistKimiCNAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "kimi-cn")
        }
    }

    /// GLM China (open.bigmodel.cn) API token (stored in Keychain).
    var zaiCNAPIToken: String {
        get { self.credentialValues.zaiCNAPIToken }
        set {
            self.credentialValues.zaiCNAPIToken = newValue
            self.schedulePersistZaiCNAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "glm-cn")
        }
    }

    /// MiniMax China (minimaxi.com) API token (stored in Keychain).
    var minimaxCNAPIToken: String {
        get { self.credentialValues.minimaxCNAPIToken }
        set {
            self.credentialValues.minimaxCNAPIToken = newValue
            self.schedulePersistMiniMaxCNAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "minimax-cn")
        }
    }

    /// StepFun global (platform.stepfun.ai) API key (stored in Keychain).
    var stepfunAPIToken: String {
        get { self.credentialValues.stepfunAPIToken }
        set {
            self.credentialValues.stepfunAPIToken = newValue
            self.schedulePersistStepFunAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "stepfun")
        }
    }

    /// StepFun China (platform.stepfun.com) API key (stored in Keychain).
    var stepfunCNAPIToken: String {
        get { self.credentialValues.stepfunCNAPIToken }
        set {
            self.credentialValues.stepfunCNAPIToken = newValue
            self.schedulePersistStepFunCNAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "stepfun-cn")
        }
    }

    /// Auggie API token (stored in Keychain).
    var auggieAPIToken: String {
        get { self.credentialValues.auggieAPIToken }
        set {
            self.credentialValues.auggieAPIToken = newValue
            self.schedulePersistAuggieAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "auggie")
        }
    }

    /// Together API key (stored in Keychain).
    var togetherAPIToken: String {
        get { self.credentialValues.togetherAPIToken }
        set {
            self.credentialValues.togetherAPIToken = newValue
            self.schedulePersistTogetherAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "together")
        }
    }

    /// Cohere API key (stored in Keychain).
    var cohereAPIToken: String {
        get { self.credentialValues.cohereAPIToken }
        set {
            self.credentialValues.cohereAPIToken = newValue
            self.schedulePersistCohereAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "cohere")
        }
    }

    /// xAI API key (stored in Keychain).
    var xaiAPIToken: String {
        get { self.credentialValues.xaiAPIToken }
        set {
            self.credentialValues.xaiAPIToken = newValue
            self.schedulePersistXAiAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "xai")
        }
    }

    /// Cerebras API key (stored in Keychain).
    var cerebrasAPIToken: String {
        get { self.credentialValues.cerebrasAPIToken }
        set {
            self.credentialValues.cerebrasAPIToken = newValue
            self.schedulePersistCerebrasAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "cerebras")
        }
    }

    /// Qwen DashScope API key (stored in Keychain).
    var qwenAPIToken: String {
        get { self.credentialValues.qwenAPIToken }
        set {
            self.credentialValues.qwenAPIToken = newValue
            self.schedulePersistQwenAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "qwen")
        }
    }

    /// Qwen DashScope China (dashscope.aliyuncs.com) API key (stored in Keychain).
    var qwenCNAPIToken: String {
        get { self.credentialValues.qwenCNAPIToken }
        set {
            self.credentialValues.qwenCNAPIToken = newValue
            self.schedulePersistQwenCNAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "qwen-cn")
        }
    }

    /// SambaNova API key (stored in Keychain).
    var sambaNovaAPIToken: String {
        get { self.credentialValues.sambaNovaAPIToken }
        set {
            self.credentialValues.sambaNovaAPIToken = newValue
            self.schedulePersistSambaNovaAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "sambanova")
        }
    }

    /// Azure OpenAI API key (stored in Keychain).
    var azureOpenAIAPIToken: String {
        get { self.credentialValues.azureOpenAIAPIToken }
        set {
            self.credentialValues.azureOpenAIAPIToken = newValue
            self.schedulePersistAzureOpenAIAPIToken()
            self.autoEnableProviderIfCredentialPresent(newValue, cliName: "azure")
        }
    }

    private func autoEnableProviderIfCredentialPresent(_ value: String, cliName: String) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.autoEnableProviderIfNeeded(cliName: cliName)
    }
}
