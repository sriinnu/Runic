import AppKit
import RunicCore

extension StatusItemController {
    @objc func runSwitchAccount(_ sender: NSMenuItem) {
        let rawProvider = sender.representedObject as? String
        let provider = rawProvider.flatMap(UsageProvider.init(rawValue:)) ?? self.lastMenuProvider ?? .codex
        self.runSwitchAccount(provider: provider)
    }

    func runSwitchAccount(provider: UsageProvider) {
        if self.loginTask != nil {
            self.loginLogger.info("Switch Account tap ignored: login already in-flight")
            print("[Runic] Switch Account ignored (busy)")
            return
        }

        self.loginLogger.info("Switch Account tapped", metadata: ["provider": provider.rawValue])
        print("[Runic] Switch Account tapped for provider=\(provider.rawValue)")

        self.loginTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.activeLoginProvider = nil
                self.loginTask = nil
            }
            self.activeLoginProvider = provider
            self.loginPhase = .requesting
            self.loginLogger.info("Starting login task", metadata: ["provider": provider.rawValue])
            print("[Runic] Starting login task for \(provider.rawValue)")

            let shouldRefresh = await self.runLoginFlow(provider: provider)
            if shouldRefresh {
                await self.store.refresh(trigger: .login, forceTokenUsage: true)
                print("[Runic] Triggered refresh after login")
            }
        }
    }

    func presentCodexLoginResult(_ result: CodexLoginRunner.Result) {
        switch result.outcome {
        case .success:
            return
        case .missingBinary:
            self.presentLoginAlert(
                title: "Codex CLI not found",
                message: "Install the Codex CLI (npm i -g @openai/codex) and try again.")
        case let .launchFailed(message):
            self.presentLoginAlert(title: "Could not start codex login", message: message)
        case .timedOut:
            self.presentLoginAlert(
                title: "Codex login timed out",
                message: self.trimmedLoginOutput(result.output))
        case let .failed(status):
            let statusLine = "codex login exited with status \(status)."
            let message = self.trimmedLoginOutput(result.output.isEmpty ? statusLine : result.output)
            self.presentLoginAlert(title: "Codex login failed", message: message)
        }
    }

    func presentClaudeLoginResult(_ result: ClaudeLoginRunner.Result) {
        switch result.outcome {
        case .success:
            return
        case .missingBinary:
            self.presentLoginAlert(
                title: "Claude CLI not found",
                message: "Install the Claude CLI (npm i -g @anthropic-ai/claude-cli) and try again.")
        case let .launchFailed(message):
            self.presentLoginAlert(title: "Could not start claude /login", message: message)
        case .timedOut:
            self.presentLoginAlert(
                title: "Claude login timed out",
                message: self.trimmedLoginOutput(result.output))
        case let .failed(status):
            let statusLine = "claude /login exited with status \(status)."
            let message = self.trimmedLoginOutput(result.output.isEmpty ? statusLine : result.output)
            self.presentLoginAlert(title: "Claude login failed", message: message)
        }
    }

    func presentGeminiLoginResult(_ result: GeminiLoginRunner.Result) {
        guard let info = Self.geminiLoginAlertInfo(for: result) else { return }
        self.presentLoginAlert(title: info.title, message: info.message)
    }

    struct LoginAlertInfo: Equatable {
        let title: String
        let message: String
    }

    nonisolated static func geminiLoginAlertInfo(for result: GeminiLoginRunner.Result) -> LoginAlertInfo? {
        switch result.outcome {
        case .success:
            nil
        case .missingBinary:
            LoginAlertInfo(
                title: "Gemini CLI not found",
                message: "Install the Gemini CLI (npm i -g @google/gemini-cli) and try again.")
        case let .launchFailed(message):
            LoginAlertInfo(title: "Could not open Terminal for Gemini", message: message)
        }
    }

    func presentCursorLoginResult(_ result: CursorLoginRunner.Result) {
        switch result.outcome {
        case .success:
            return
        case .cancelled:
            return
        case let .failed(message):
            self.presentLoginAlert(title: "Cursor login failed", message: message)
        }
    }

    func presentLoginAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func trimmedLoginOutput(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let limit = 600
        if trimmed.isEmpty { return "No output captured." }
        if trimmed.count <= limit { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return "\(trimmed[..<idx])…"
    }

    func postLoginNotification(for provider: UsageProvider) {
        let name = ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
        let title = "\(name) login successful"
        let body = "You can return to the app; authentication finished."
        AppNotifications.shared.post(idPrefix: "login-\(provider.rawValue)", title: title, body: body)
    }

    func describe(_ outcome: CodexLoginRunner.Result.Outcome) -> String {
        switch outcome {
        case .success: "success"
        case .timedOut: "timedOut"
        case let .failed(status): "failed(status: \(status))"
        case .missingBinary: "missingBinary"
        case let .launchFailed(message): "launchFailed(\(message))"
        }
    }

    func describe(_ outcome: ClaudeLoginRunner.Result.Outcome) -> String {
        switch outcome {
        case .success: "success"
        case .timedOut: "timedOut"
        case let .failed(status): "failed(status: \(status))"
        case .missingBinary: "missingBinary"
        case let .launchFailed(message): "launchFailed(\(message))"
        }
    }

    func describe(_ outcome: GeminiLoginRunner.Result.Outcome) -> String {
        switch outcome {
        case .success: "success"
        case .missingBinary: "missingBinary"
        case let .launchFailed(message): "launchFailed(\(message))"
        }
    }

    func describe(_ outcome: CursorLoginRunner.Result.Outcome) -> String {
        switch outcome {
        case .success: "success"
        case .cancelled: "cancelled"
        case let .failed(message): "failed(\(message))"
        }
    }
}
