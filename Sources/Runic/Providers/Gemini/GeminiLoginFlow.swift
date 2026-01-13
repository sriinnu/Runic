import RunicCore

@MainActor
extension StatusItemController {
    func runGeminiLoginFlow() async {
        let store = self.store
        let result = await GeminiLoginRunner.run {
            Task { @MainActor in
                await store.refresh(trigger: .login, forceTokenUsage: true)
                print("[Runic] Auto-refreshed after Gemini auth")
            }
        }
        guard !Task.isCancelled else { return }
        self.loginPhase = .idle
        self.presentGeminiLoginResult(result)
        let outcome = self.describe(result.outcome)
        self.loginLogger.info("Gemini login", metadata: ["outcome": outcome])
        print("[Runic] Gemini login outcome=\(outcome)")
    }
}
