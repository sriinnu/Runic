import Foundation
import RunicCore

extension SettingsStore {
    private func makeCredentialPersistTask(
        value: String,
        loggerName: String,
        failureMessage: String,
        persist: @escaping @Sendable (String) throws -> Void) -> Task<Void, Never>
    {
        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let error: (any Error)? = await Task.detached(priority: .utility) { () -> (any Error)? in
                do {
                    try persist(value)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let error {
                // Keep value in memory; persist best-effort.
                RunicLog.logger(loggerName).error("\(failureMessage): \(error)")
            }
        }
    }

    func schedulePersistZaiAPIToken() {
        self.zaiTokenPersistTask?.cancel()
        let tokenStore = self.zaiTokenStore
        self.zaiTokenPersistTask = self.makeCredentialPersistTask(
            value: self.zaiAPIToken,
            loggerName: "zai-token-store",
            failureMessage: "Failed to persist z.ai token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistMiniMaxAPIToken() {
        self.minimaxTokenPersistTask?.cancel()
        let tokenStore = self.minimaxTokenStore
        self.minimaxTokenPersistTask = self.makeCredentialPersistTask(
            value: self.minimaxAPIToken,
            loggerName: "minimax-token-store",
            failureMessage: "Failed to persist MiniMax token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistMiniMaxCookieHeader() {
        self.minimaxCookieHeaderPersistTask?.cancel()
        let store = self.minimaxCookieHeaderStore
        self.minimaxCookieHeaderPersistTask = self.makeCredentialPersistTask(
            value: self.minimaxCookieHeader,
            loggerName: "minimax-cookie-store",
            failureMessage: "Failed to persist MiniMax cookie header") { header in
                try store.storeHeader(header)
            }
    }

    func schedulePersistMiniMaxGroupID() {
        self.minimaxGroupIDPersistTask?.cancel()
        let groupStore = self.minimaxGroupIDStore
        self.minimaxGroupIDPersistTask = self.makeCredentialPersistTask(
            value: self.minimaxGroupID,
            loggerName: "minimax-groupid-store",
            failureMessage: "Failed to persist MiniMax Group ID") { groupID in
                try groupStore.storeGroupID(groupID)
            }
    }

    func schedulePersistCopilotAPIToken() {
        self.copilotTokenPersistTask?.cancel()
        let tokenStore = self.copilotTokenStore
        self.copilotTokenPersistTask = self.makeCredentialPersistTask(
            value: self.copilotAPIToken,
            loggerName: "copilot-token-store",
            failureMessage: "Failed to persist Copilot token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistOpenRouterAPIToken() {
        self.openRouterTokenPersistTask?.cancel()
        let tokenStore = self.openRouterTokenStore
        self.openRouterTokenPersistTask = self.makeCredentialPersistTask(
            value: self.openRouterAPIToken,
            loggerName: "openrouter-token-store",
            failureMessage: "Failed to persist OpenRouter token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistVercelAIAPIToken() {
        self.vercelAITokenPersistTask?.cancel()
        let tokenStore = self.vercelAITokenStore
        self.vercelAITokenPersistTask = self.makeCredentialPersistTask(
            value: self.vercelAIAPIToken,
            loggerName: "vercelai-token-store",
            failureMessage: "Failed to persist Vercel AI token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistGroqAPIToken() {
        self.groqTokenPersistTask?.cancel()
        let tokenStore = self.groqTokenStore
        self.groqTokenPersistTask = self.makeCredentialPersistTask(
            value: self.groqAPIToken,
            loggerName: "groq-token-store",
            failureMessage: "Failed to persist Groq token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistDeepSeekAPIToken() {
        self.deepSeekTokenPersistTask?.cancel()
        let tokenStore = self.deepSeekTokenStore
        self.deepSeekTokenPersistTask = self.makeCredentialPersistTask(
            value: self.deepSeekAPIToken,
            loggerName: "deepseek-token-store",
            failureMessage: "Failed to persist DeepSeek token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistFireworksAPIToken() {
        self.fireworksTokenPersistTask?.cancel()
        let tokenStore = self.fireworksTokenStore
        self.fireworksTokenPersistTask = self.makeCredentialPersistTask(
            value: self.fireworksAPIToken,
            loggerName: "fireworks-token-store",
            failureMessage: "Failed to persist Fireworks token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistMistralAPIToken() {
        self.mistralTokenPersistTask?.cancel()
        let tokenStore = self.mistralTokenStore
        self.mistralTokenPersistTask = self.makeCredentialPersistTask(
            value: self.mistralAPIToken,
            loggerName: "mistral-token-store",
            failureMessage: "Failed to persist Mistral token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistPerplexityAPIToken() {
        self.perplexityTokenPersistTask?.cancel()
        let tokenStore = self.perplexityTokenStore
        self.perplexityTokenPersistTask = self.makeCredentialPersistTask(
            value: self.perplexityAPIToken,
            loggerName: "perplexity-token-store",
            failureMessage: "Failed to persist Perplexity token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistKimiAPIToken() {
        self.kimiTokenPersistTask?.cancel()
        let tokenStore = self.kimiTokenStore
        self.kimiTokenPersistTask = self.makeCredentialPersistTask(
            value: self.kimiAPIToken,
            loggerName: "kimi-token-store",
            failureMessage: "Failed to persist Kimi token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistAuggieAPIToken() {
        self.auggieTokenPersistTask?.cancel()
        let tokenStore = self.auggieTokenStore
        self.auggieTokenPersistTask = self.makeCredentialPersistTask(
            value: self.auggieAPIToken,
            loggerName: "auggie-token-store",
            failureMessage: "Failed to persist Auggie token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistTogetherAPIToken() {
        self.togetherTokenPersistTask?.cancel()
        let tokenStore = self.togetherTokenStore
        self.togetherTokenPersistTask = self.makeCredentialPersistTask(
            value: self.togetherAPIToken,
            loggerName: "together-token-store",
            failureMessage: "Failed to persist Together token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistCohereAPIToken() {
        self.cohereTokenPersistTask?.cancel()
        let tokenStore = self.cohereTokenStore
        self.cohereTokenPersistTask = self.makeCredentialPersistTask(
            value: self.cohereAPIToken,
            loggerName: "cohere-token-store",
            failureMessage: "Failed to persist Cohere token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistXAiAPIToken() {
        self.xaiTokenPersistTask?.cancel()
        let tokenStore = self.xaiTokenStore
        self.xaiTokenPersistTask = self.makeCredentialPersistTask(
            value: self.xaiAPIToken,
            loggerName: "xai-token-store",
            failureMessage: "Failed to persist xAI token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistCerebrasAPIToken() {
        self.cerebrasTokenPersistTask?.cancel()
        let tokenStore = self.cerebrasTokenStore
        self.cerebrasTokenPersistTask = self.makeCredentialPersistTask(
            value: self.cerebrasAPIToken,
            loggerName: "cerebras-token-store",
            failureMessage: "Failed to persist Cerebras token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistSambaNovaAPIToken() {
        self.sambaNovaTokenPersistTask?.cancel()
        let tokenStore = self.sambaNovaTokenStore
        self.sambaNovaTokenPersistTask = self.makeCredentialPersistTask(
            value: self.sambaNovaAPIToken,
            loggerName: "sambanova-token-store",
            failureMessage: "Failed to persist SambaNova token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistAzureOpenAIAPIToken() {
        self.azureOpenAITokenPersistTask?.cancel()
        let tokenStore = self.azureOpenAITokenStore
        self.azureOpenAITokenPersistTask = self.makeCredentialPersistTask(
            value: self.azureOpenAIAPIToken,
            loggerName: "azure-openai-token-store",
            failureMessage: "Failed to persist Azure OpenAI token") { token in
                try tokenStore.storeToken(token)
            }
    }

    func schedulePersistQwenAPIToken() {
        self.qwenTokenPersistTask?.cancel()
        let tokenStore = self.qwenTokenStore
        self.qwenTokenPersistTask = self.makeCredentialPersistTask(
            value: self.qwenAPIToken,
            loggerName: "qwen-token-store",
            failureMessage: "Failed to persist Qwen token") { token in
                try tokenStore.storeToken(token)
            }
    }
}
