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
        self.credentialPersistTasks.zai?.cancel()
        let tokenStore = self.credentialStores.zai
        self.credentialPersistTasks.zai = self.makeCredentialPersistTask(
            value: self.zaiAPIToken,
            loggerName: "zai-token-store",
            failureMessage: "Failed to persist z.ai token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistMiniMaxAPIToken() {
        self.credentialPersistTasks.minimax?.cancel()
        let tokenStore = self.credentialStores.minimax
        self.credentialPersistTasks.minimax = self.makeCredentialPersistTask(
            value: self.minimaxAPIToken,
            loggerName: "minimax-token-store",
            failureMessage: "Failed to persist MiniMax token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistMiniMaxCookieHeader() {
        self.credentialPersistTasks.minimaxCookieHeader?.cancel()
        let store = self.credentialStores.minimaxCookieHeader
        self.credentialPersistTasks.minimaxCookieHeader = self.makeCredentialPersistTask(
            value: self.minimaxCookieHeader,
            loggerName: "minimax-cookie-store",
            failureMessage: "Failed to persist MiniMax cookie header")
        { header in
            try store.storeHeader(header)
        }
    }

    func schedulePersistMiniMaxGroupID() {
        self.credentialPersistTasks.minimaxGroupID?.cancel()
        let groupStore = self.credentialStores.minimaxGroupID
        self.credentialPersistTasks.minimaxGroupID = self.makeCredentialPersistTask(
            value: self.minimaxGroupID,
            loggerName: "minimax-groupid-store",
            failureMessage: "Failed to persist MiniMax Group ID")
        { groupID in
            try groupStore.storeGroupID(groupID)
        }
    }

    func schedulePersistCopilotAPIToken() {
        self.credentialPersistTasks.copilot?.cancel()
        let tokenStore = self.credentialStores.copilot
        self.credentialPersistTasks.copilot = self.makeCredentialPersistTask(
            value: self.copilotAPIToken,
            loggerName: "copilot-token-store",
            failureMessage: "Failed to persist Copilot token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistOpenRouterAPIToken() {
        self.credentialPersistTasks.openRouter?.cancel()
        let tokenStore = self.credentialStores.openRouter
        self.credentialPersistTasks.openRouter = self.makeCredentialPersistTask(
            value: self.openRouterAPIToken,
            loggerName: "openrouter-token-store",
            failureMessage: "Failed to persist OpenRouter token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistVercelAIAPIToken() {
        self.credentialPersistTasks.vercelAI?.cancel()
        let tokenStore = self.credentialStores.vercelAI
        self.credentialPersistTasks.vercelAI = self.makeCredentialPersistTask(
            value: self.vercelAIAPIToken,
            loggerName: "vercelai-token-store",
            failureMessage: "Failed to persist Vercel AI token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistGroqAPIToken() {
        self.credentialPersistTasks.groq?.cancel()
        let tokenStore = self.credentialStores.groq
        self.credentialPersistTasks.groq = self.makeCredentialPersistTask(
            value: self.groqAPIToken,
            loggerName: "groq-token-store",
            failureMessage: "Failed to persist Groq token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistDeepSeekAPIToken() {
        self.credentialPersistTasks.deepSeek?.cancel()
        let tokenStore = self.credentialStores.deepSeek
        self.credentialPersistTasks.deepSeek = self.makeCredentialPersistTask(
            value: self.deepSeekAPIToken,
            loggerName: "deepseek-token-store",
            failureMessage: "Failed to persist DeepSeek token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistFireworksAPIToken() {
        self.credentialPersistTasks.fireworks?.cancel()
        let tokenStore = self.credentialStores.fireworks
        self.credentialPersistTasks.fireworks = self.makeCredentialPersistTask(
            value: self.fireworksAPIToken,
            loggerName: "fireworks-token-store",
            failureMessage: "Failed to persist Fireworks token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistMistralAPIToken() {
        self.credentialPersistTasks.mistral?.cancel()
        let tokenStore = self.credentialStores.mistral
        self.credentialPersistTasks.mistral = self.makeCredentialPersistTask(
            value: self.mistralAPIToken,
            loggerName: "mistral-token-store",
            failureMessage: "Failed to persist Mistral token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistPerplexityAPIToken() {
        self.credentialPersistTasks.perplexity?.cancel()
        let tokenStore = self.credentialStores.perplexity
        self.credentialPersistTasks.perplexity = self.makeCredentialPersistTask(
            value: self.perplexityAPIToken,
            loggerName: "perplexity-token-store",
            failureMessage: "Failed to persist Perplexity token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistKimiAPIToken() {
        self.credentialPersistTasks.kimi?.cancel()
        let tokenStore = self.credentialStores.kimi
        self.credentialPersistTasks.kimi = self.makeCredentialPersistTask(
            value: self.kimiAPIToken,
            loggerName: "kimi-token-store",
            failureMessage: "Failed to persist Kimi token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistAuggieAPIToken() {
        self.credentialPersistTasks.auggie?.cancel()
        let tokenStore = self.credentialStores.auggie
        self.credentialPersistTasks.auggie = self.makeCredentialPersistTask(
            value: self.auggieAPIToken,
            loggerName: "auggie-token-store",
            failureMessage: "Failed to persist Auggie token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistTogetherAPIToken() {
        self.credentialPersistTasks.together?.cancel()
        let tokenStore = self.credentialStores.together
        self.credentialPersistTasks.together = self.makeCredentialPersistTask(
            value: self.togetherAPIToken,
            loggerName: "together-token-store",
            failureMessage: "Failed to persist Together token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistCohereAPIToken() {
        self.credentialPersistTasks.cohere?.cancel()
        let tokenStore = self.credentialStores.cohere
        self.credentialPersistTasks.cohere = self.makeCredentialPersistTask(
            value: self.cohereAPIToken,
            loggerName: "cohere-token-store",
            failureMessage: "Failed to persist Cohere token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistXAiAPIToken() {
        self.credentialPersistTasks.xai?.cancel()
        let tokenStore = self.credentialStores.xai
        self.credentialPersistTasks.xai = self.makeCredentialPersistTask(
            value: self.xaiAPIToken,
            loggerName: "xai-token-store",
            failureMessage: "Failed to persist xAI token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistCerebrasAPIToken() {
        self.credentialPersistTasks.cerebras?.cancel()
        let tokenStore = self.credentialStores.cerebras
        self.credentialPersistTasks.cerebras = self.makeCredentialPersistTask(
            value: self.cerebrasAPIToken,
            loggerName: "cerebras-token-store",
            failureMessage: "Failed to persist Cerebras token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistSambaNovaAPIToken() {
        self.credentialPersistTasks.sambaNova?.cancel()
        let tokenStore = self.credentialStores.sambaNova
        self.credentialPersistTasks.sambaNova = self.makeCredentialPersistTask(
            value: self.sambaNovaAPIToken,
            loggerName: "sambanova-token-store",
            failureMessage: "Failed to persist SambaNova token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistAzureOpenAIAPIToken() {
        self.credentialPersistTasks.azureOpenAI?.cancel()
        let tokenStore = self.credentialStores.azureOpenAI
        self.credentialPersistTasks.azureOpenAI = self.makeCredentialPersistTask(
            value: self.azureOpenAIAPIToken,
            loggerName: "azure-openai-token-store",
            failureMessage: "Failed to persist Azure OpenAI token")
        { token in
            try tokenStore.storeToken(token)
        }
    }

    func schedulePersistQwenAPIToken() {
        self.credentialPersistTasks.qwen?.cancel()
        let tokenStore = self.credentialStores.qwen
        self.credentialPersistTasks.qwen = self.makeCredentialPersistTask(
            value: self.qwenAPIToken,
            loggerName: "qwen-token-store",
            failureMessage: "Failed to persist Qwen token")
        { token in
            try tokenStore.storeToken(token)
        }
    }
}
