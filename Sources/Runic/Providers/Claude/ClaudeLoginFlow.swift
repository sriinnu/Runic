import RunicCore

@MainActor
extension StatusItemController {
    func runClaudeLoginFlow() async {
        let phaseHandler: @Sendable (ClaudeLoginRunner.Phase) -> Void = { [weak self] phase in
            Task { @MainActor in
                switch phase {
                case .requesting: self?.loginPhase = .requesting
                case .waitingBrowser: self?.loginPhase = .waitingBrowser
                }
            }
        }
        let result = await ClaudeLoginRunner.run(timeout: 120, onPhaseChange: phaseHandler)
        guard !Task.isCancelled else { return }
        self.loginPhase = .idle
        self.presentClaudeLoginResult(result)
        let outcome = self.describe(result.outcome)
        let length = result.output.count
        self.loginLogger.info("Claude login", metadata: ["outcome": outcome, "length": "\(length)"])
        print("[Runic] Claude login outcome=\(outcome) len=\(length)")
        if case .success = result.outcome {
            // The CLI just rewrote its Keychain item, so Runic's cached copy is
            // stale and its ACL grant is gone. Refill it here, where the user is
            // present and a single authorization dialog is expected — every
            // later refresh then reads Runic's own item and never prompts.
            ClaudeOAuthCredentialCache.clear()
            _ = try? ClaudeOAuthCredentialsStore.loadAllowingInteraction()
            self.postLoginNotification(for: .claude)
        }
    }
}
