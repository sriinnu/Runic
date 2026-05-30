import Foundation
import RunicCore
import Silo

extension UsageStore {
    private var codexBrowserCookieOrder: BrowserCookieImportOrder {
        self.metadata(for: .codex).browserCookieOrder ?? Browser.defaultImportOrder
    }

    func refreshCreditsIfNeeded() async {
        guard self.isEnabled(.codex) else { return }
        do {
            let credits = try await self.codexFetcher.loadLatestCredits()
            await MainActor.run {
                self.credits = credits
                self.lastCreditsError = nil
                self.lastCreditsSnapshot = credits
                self.creditsFailureStreak = 0
            }
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("data not available yet") {
                await MainActor.run {
                    if let cached = self.lastCreditsSnapshot {
                        self.credits = cached
                        self.lastCreditsError = nil
                    } else {
                        self.credits = nil
                        self.lastCreditsError = "Codex credits are still loading; will retry shortly."
                    }
                }
                return
            }

            await MainActor.run {
                self.creditsFailureStreak += 1
                if let cached = self.lastCreditsSnapshot {
                    self.credits = cached
                    let stamp = cached.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    self.lastCreditsError =
                        "Last Codex credits refresh failed: \(message). Cached values from \(stamp)."
                } else {
                    self.lastCreditsError = message
                    self.credits = nil
                }
            }
        }
    }

    private func openAIDashboardFriendlyError(
        body: String,
        targetEmail: String?,
        cookieImportStatus: String?) -> String?
    {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = cookieImportStatus?.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return [
                "OpenAI web dashboard returned an empty page.",
                "Sign in to chatgpt.com and re-enable “Access OpenAI via web”.",
            ].joined(separator: " ")
        }

        let lower = trimmed.lowercased()
        let looksLikePublicLanding = lower.contains("skip to content")
            && (lower.contains("about") || lower.contains("openai") || lower.contains("chatgpt"))
        let looksLoggedOut = lower.contains("sign in")
            || lower.contains("log in")
            || lower.contains("create account")
            || lower.contains("continue with google")
            || lower.contains("continue with apple")
            || lower.contains("continue with microsoft")

        guard looksLikePublicLanding || looksLoggedOut else { return nil }
        let emailLabel = targetEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLabel = (emailLabel?.isEmpty == false) ? emailLabel! : "your OpenAI account"
        if let status, !status.isEmpty {
            if status.contains("Browser cookies do not match Codex account")
                || status.contains("Browser cookie import failed")
            {
                return [
                    status,
                    "Sign in to chatgpt.com as \(targetLabel), then re-enable “Access OpenAI via web”.",
                ].joined(separator: " ")
            }
        }
        return [
            "OpenAI web dashboard returned a public page (not signed in).",
            "Sign in to chatgpt.com as \(targetLabel), then re-enable “Access OpenAI via web”.",
        ].joined(separator: " ")
    }

    private func applyOpenAIDashboard(_ dash: OpenAIDashboardSnapshot, targetEmail: String?) async {
        await MainActor.run {
            self.openAIDashboard = dash
            self.lastOpenAIDashboardError = nil
            self.lastOpenAIDashboardSnapshot = dash
            self.openAIDashboardRequiresLogin = false
            // Only fill gaps; OAuth/CLI remain the primary sources for usage + credits.
            if self.snapshots[.codex] == nil,
               let usage = dash.toUsageSnapshot(provider: .codex, accountEmail: targetEmail)
            {
                self.snapshots[.codex] = usage
                self.errors[.codex] = nil
                self.failureGates[.codex]?.recordSuccess()
                self.lastSourceLabels[.codex] = "openai-web"
            }
            if self.credits == nil, let credits = dash.toCreditsSnapshot() {
                self.credits = credits
                self.lastCreditsSnapshot = credits
                self.lastCreditsError = nil
                self.creditsFailureStreak = 0
            }
        }

        if let email = targetEmail, !email.isEmpty {
            OpenAIDashboardCacheStore.save(OpenAIDashboardCache(accountEmail: email, snapshot: dash))
        }
    }

    private func applyOpenAIDashboardFailure(message: String) async {
        await MainActor.run {
            if let cached = self.lastOpenAIDashboardSnapshot {
                self.openAIDashboard = cached
                let stamp = cached.updatedAt.formatted(date: .abbreviated, time: .shortened)
                self.lastOpenAIDashboardError =
                    "Last OpenAI dashboard refresh failed: \(message). Cached values from \(stamp)."
            } else {
                self.lastOpenAIDashboardError = message
                self.openAIDashboard = nil
            }
        }
    }

    private struct OpenAIDashboardRefreshContext {
        let targetEmail: String?
        let normalizedEmail: String?
        var effectiveEmail: String?
        let allowBrowserCookieImport: Bool
        let log: (String) -> Void
    }

    private struct OpenAIDashboardFetchResult {
        let dashboard: OpenAIDashboardSnapshot
        let effectiveEmail: String?
    }

    func refreshOpenAIDashboardIfNeeded(
        force: Bool = false,
        allowBrowserCookieImport: Bool = false) async
    {
        guard self.isEnabled(.codex), self.settings.openAIWebAccessEnabled else {
            self.clearOpenAIDashboardWebState()
            return
        }

        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        self.handleOpenAIWebTargetEmailChangeIfNeeded(targetEmail: targetEmail)

        guard !self.shouldSkipOpenAIDashboardRefresh(force: force, now: Date()) else { return }
        let log = self.startOpenAIDashboardRefreshLog()
        var context = OpenAIDashboardRefreshContext(
            targetEmail: targetEmail,
            normalizedEmail: self.normalizedEmail(targetEmail),
            effectiveEmail: targetEmail,
            allowBrowserCookieImport: allowBrowserCookieImport,
            log: log)
        context.effectiveEmail = await self.effectiveOpenAIDashboardEmailAfterAccountChange(context)

        do {
            let result = try await self.loadOpenAIDashboardMatchingAccount(context)
            if self.applyOpenAIDashboardMismatchIfNeeded(result.dashboard, expected: context.normalizedEmail) {
                return
            }
            await self.applyOpenAIDashboard(result.dashboard, targetEmail: result.effectiveEmail)
        } catch let OpenAIDashboardFetcher.FetchError.noDashboardData(body) {
            await self.handleOpenAIDashboardNoData(
                body: body,
                allowBrowserCookieImport: allowBrowserCookieImport,
                log: log)
        } catch OpenAIDashboardFetcher.FetchError.loginRequired {
            await self.handleOpenAIDashboardLoginRequired(
                allowBrowserCookieImport: allowBrowserCookieImport,
                log: log)
        } catch {
            await self.applyOpenAIDashboardFailure(message: error.localizedDescription)
        }
    }

    private func clearOpenAIDashboardWebState() {
        self.openAIDashboard = nil
        self.lastOpenAIDashboardError = nil
        self.lastOpenAIDashboardSnapshot = nil
        self.lastOpenAIDashboardTargetEmail = nil
        self.openAIDashboardRequiresLogin = false
        self.openAIDashboardCookieImportStatus = nil
        self.openAIDashboardCookieImportDebugLog = nil
        self.lastOpenAIDashboardCookieImportAttemptAt = nil
        self.lastOpenAIDashboardCookieImportEmail = nil
    }

    private func shouldSkipOpenAIDashboardRefresh(force: Bool, now: Date) -> Bool {
        guard !force,
              !self.openAIWebAccountDidChange,
              self.lastOpenAIDashboardError == nil,
              let snapshot = self.lastOpenAIDashboardSnapshot
        else {
            return false
        }
        let minInterval = max(self.settings.refreshFrequency.seconds ?? 0, 120)
        return now.timeIntervalSince(snapshot.updatedAt) < minInterval
    }

    private func startOpenAIDashboardRefreshLog() -> (String) -> Void {
        if self.openAIWebDebugLines.isEmpty {
            self.resetOpenAIWebDebugLog(context: "refresh")
        } else {
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            self.logOpenAIWeb("[\(stamp)] OpenAI web refresh start")
        }
        return { [weak self] line in
            guard let self else { return }
            self.logOpenAIWeb(line)
        }
    }

    private func normalizedEmail(_ email: String?) -> String? {
        email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func effectiveOpenAIDashboardEmailAfterAccountChange(
        _ context: OpenAIDashboardRefreshContext) async -> String?
    {
        guard self.openAIWebAccountDidChange,
              let targetEmail = context.targetEmail,
              !targetEmail.isEmpty
        else {
            return context.effectiveEmail
        }
        defer { self.openAIWebAccountDidChange = false }
        guard context.allowBrowserCookieImport,
              let imported = await self.importOpenAIDashboardCookiesIfNeeded(
                targetEmail: targetEmail,
                force: true)
        else {
            self.openAIDashboardCookieImportStatus =
                "Codex account changed; import browser cookies manually to refresh web extras."
            return context.effectiveEmail
        }
        return imported
    }

    private func loadOpenAIDashboardMatchingAccount(
        _ context: OpenAIDashboardRefreshContext) async throws -> OpenAIDashboardFetchResult
    {
        var context = context
        var dashboard = try await self.loadOpenAIDashboard(
            accountEmail: context.effectiveEmail,
            log: context.log,
            debugDumpHTML: false)

        if self.dashboardEmailMismatch(expected: context.normalizedEmail, actual: dashboard.signedInEmail) {
            context.effectiveEmail = await self.importedOpenAIDashboardEmailIfAllowed(
                targetEmail: context.targetEmail,
                currentEmail: context.effectiveEmail,
                allowBrowserCookieImport: context.allowBrowserCookieImport)
            dashboard = try await self.loadOpenAIDashboard(
                accountEmail: context.effectiveEmail,
                log: context.log,
                debugDumpHTML: false)
        }

        return OpenAIDashboardFetchResult(
            dashboard: dashboard,
            effectiveEmail: context.effectiveEmail)
    }

    private func importedOpenAIDashboardEmailIfAllowed(
        targetEmail: String?,
        currentEmail: String?,
        allowBrowserCookieImport: Bool) async -> String?
    {
        guard allowBrowserCookieImport,
              let imported = await self.importOpenAIDashboardCookiesIfNeeded(
                targetEmail: targetEmail,
                force: true)
        else {
            return currentEmail
        }
        return imported
    }

    private func loadOpenAIDashboard(
        accountEmail: String?,
        log: @escaping (String) -> Void,
        debugDumpHTML: Bool) async throws -> OpenAIDashboardSnapshot
    {
        try await OpenAIDashboardFetcher().loadLatestDashboard(
            accountEmail: accountEmail,
            logger: log,
            debugDumpHTML: debugDumpHTML)
    }

    private func applyOpenAIDashboardMismatchIfNeeded(
        _ dashboard: OpenAIDashboardSnapshot,
        expected normalizedEmail: String?) -> Bool
    {
        guard self.dashboardEmailMismatch(expected: normalizedEmail, actual: dashboard.signedInEmail) else {
            return false
        }
        let signedIn = dashboard.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        self.openAIDashboard = nil
        self.lastOpenAIDashboardError = [
            "OpenAI dashboard signed in as \(signedIn), but Codex uses \(normalizedEmail ?? "unknown").",
            "Switch accounts in your browser and re-enable “Access OpenAI via web”.",
        ].joined(separator: " ")
        self.openAIDashboardRequiresLogin = true
        return true
    }

    private func handleOpenAIDashboardNoData(
        body: String,
        allowBrowserCookieImport: Bool,
        log: @escaping (String) -> Void) async
    {
        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        let effectiveEmail = await self.importedOpenAIDashboardEmailIfAllowed(
            targetEmail: targetEmail,
            currentEmail: targetEmail,
            allowBrowserCookieImport: allowBrowserCookieImport)
        guard allowBrowserCookieImport else {
            let message = self.openAIDashboardNoDataMessage(body: body, targetEmail: targetEmail)
            await self.applyOpenAIDashboardFailure(message: message)
            return
        }

        do {
            let dashboard = try await self.loadOpenAIDashboard(
                accountEmail: effectiveEmail,
                log: log,
                debugDumpHTML: true)
            await self.applyOpenAIDashboard(dashboard, targetEmail: effectiveEmail)
        } catch let OpenAIDashboardFetcher.FetchError.noDashboardData(retryBody) {
            let finalBody = retryBody.isEmpty ? body : retryBody
            let message = self.openAIDashboardNoDataMessage(body: finalBody, targetEmail: targetEmail)
            await self.applyOpenAIDashboardFailure(message: message)
        } catch {
            await self.applyOpenAIDashboardFailure(message: error.localizedDescription)
        }
    }

    private func openAIDashboardNoDataMessage(body: String, targetEmail: String?) -> String {
        self.openAIDashboardFriendlyError(
            body: body,
            targetEmail: targetEmail,
            cookieImportStatus: self.openAIDashboardCookieImportStatus)
            ?? OpenAIDashboardFetcher.FetchError.noDashboardData(body: body).localizedDescription
    }

    private func handleOpenAIDashboardLoginRequired(
        allowBrowserCookieImport: Bool,
        log: @escaping (String) -> Void) async
    {
        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        let effectiveEmail = await self.importedOpenAIDashboardEmailIfAllowed(
            targetEmail: targetEmail,
            currentEmail: targetEmail,
            allowBrowserCookieImport: allowBrowserCookieImport)
        guard allowBrowserCookieImport else {
            self.applyOpenAIDashboardLoginRequired(message: [
                "OpenAI web access requires a signed-in chatgpt.com session.",
                "Use manual browser-cookie import to refresh web extras.",
            ].joined(separator: " "))
            return
        }

        do {
            let dashboard = try await self.loadOpenAIDashboard(
                accountEmail: effectiveEmail,
                log: log,
                debugDumpHTML: true)
            await self.applyOpenAIDashboard(dashboard, targetEmail: effectiveEmail)
        } catch OpenAIDashboardFetcher.FetchError.loginRequired {
            self.applyOpenAIDashboardLoginRequired(message: [
                "OpenAI web access requires a signed-in chatgpt.com session.",
                "Sign in using \(self.codexBrowserCookieOrder.loginHint), " +
                    "then re-enable “Access OpenAI via web”.",
            ].joined(separator: " "))
        } catch {
            await self.applyOpenAIDashboardFailure(message: error.localizedDescription)
        }
    }

    private func applyOpenAIDashboardLoginRequired(message: String) {
        self.lastOpenAIDashboardError = message
        self.openAIDashboard = self.lastOpenAIDashboardSnapshot
        self.openAIDashboardRequiresLogin = true
    }

    /// Detect Codex account email changes and clear stale OpenAI web state so the UI can't show the wrong user.
    /// This does not delete other per-email WebKit cookie stores (we keep multiple accounts around).
    func handleOpenAIWebTargetEmailChangeIfNeeded(targetEmail: String?) {
        let normalized = targetEmail?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let normalized, !normalized.isEmpty else { return }

        let previous = self.lastOpenAIDashboardTargetEmail
        self.lastOpenAIDashboardTargetEmail = normalized

        if let previous,
           !previous.isEmpty,
           previous != normalized
        {
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            self.logOpenAIWeb(
                "[\(stamp)] Codex account changed: \(previous) → \(normalized); " +
                    "clearing OpenAI web snapshot")
            self.openAIWebAccountDidChange = true
            self.openAIDashboard = nil
            self.lastOpenAIDashboardSnapshot = nil
            self.lastOpenAIDashboardError = nil
            self.openAIDashboardRequiresLogin = true
            self.openAIDashboardCookieImportStatus =
                "Codex account changed; import browser cookies manually to refresh web extras."
            self.lastOpenAIDashboardCookieImportAttemptAt = nil
            self.lastOpenAIDashboardCookieImportEmail = nil
        }
    }

    func importOpenAIDashboardBrowserCookiesNow() async {
        self.resetOpenAIWebDebugLog(context: "manual import")
        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        _ = await self.importOpenAIDashboardCookiesIfNeeded(targetEmail: targetEmail, force: true)
        await self.refreshOpenAIDashboardIfNeeded(force: true, allowBrowserCookieImport: false)
    }

    private func importOpenAIDashboardCookiesIfNeeded(targetEmail: String?, force: Bool) async -> String? {
        let normalizedTarget = targetEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowAnyAccount = normalizedTarget == nil || normalizedTarget?.isEmpty == true

        let now = Date()
        let lastEmail = self.lastOpenAIDashboardCookieImportEmail
        let lastAttempt = self.lastOpenAIDashboardCookieImportAttemptAt ?? .distantPast

        let shouldAttempt: Bool = if force {
            true
        } else {
            if allowAnyAccount {
                now.timeIntervalSince(lastAttempt) > 300
            } else {
                self.openAIDashboardRequiresLogin &&
                    (lastEmail?.lowercased() != normalizedTarget?.lowercased() || now
                        .timeIntervalSince(lastAttempt) > 300)
            }
        }

        guard shouldAttempt else { return normalizedTarget }
        self.lastOpenAIDashboardCookieImportEmail = normalizedTarget
        self.lastOpenAIDashboardCookieImportAttemptAt = now

        let stamp = now.formatted(date: .abbreviated, time: .shortened)
        let targetLabel = normalizedTarget ?? "unknown"
        self.logOpenAIWeb("[\(stamp)] import start (target=\(targetLabel))")

        do {
            let log: (String) -> Void = { [weak self] message in
                guard let self else { return }
                self.logOpenAIWeb(message)
            }

            let result = try await OpenAIDashboardBrowserCookieImporter()
                .importBestCookies(
                    intoAccountEmail: normalizedTarget,
                    allowAnyAccount: allowAnyAccount,
                    logger: log)
            let effectiveEmail = result.signedInEmail?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
                ? result.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
                : normalizedTarget
            self.lastOpenAIDashboardCookieImportEmail = effectiveEmail ?? normalizedTarget
            await MainActor.run {
                let signed = result.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchText = result.matchesCodexEmail ? "matches Codex" : "does not match Codex"
                if let signed, !signed.isEmpty {
                    self.openAIDashboardCookieImportStatus =
                        allowAnyAccount
                            ? [
                                "Using \(result.sourceLabel) cookies (\(result.cookieCount)).",
                                "Signed in as \(signed).",
                            ].joined(separator: " ")
                            : [
                                "Using \(result.sourceLabel) cookies (\(result.cookieCount)).",
                                "Signed in as \(signed) (\(matchText)).",
                            ].joined(separator: " ")
                } else {
                    self.openAIDashboardCookieImportStatus =
                        "Using \(result.sourceLabel) cookies (\(result.cookieCount))."
                }
            }
            return effectiveEmail
        } catch let err as OpenAIDashboardBrowserCookieImporter.ImportError {
            switch err {
            case let .noMatchingAccount(found):
                let foundText: String = if found.isEmpty {
                    "no signed-in session detected in \(self.codexBrowserCookieOrder.loginHint)"
                } else {
                    found
                        .sorted { lhs, rhs in
                            if lhs.sourceLabel == rhs.sourceLabel { return lhs.email < rhs.email }
                            return lhs.sourceLabel < rhs.sourceLabel
                        }
                        .map { "\($0.sourceLabel): \($0.email)" }
                        .joined(separator: " • ")
                }
                self.logOpenAIWeb("[\(stamp)] import mismatch: \(foundText)")
                await MainActor.run {
                    self.openAIDashboardCookieImportStatus = allowAnyAccount
                        ? [
                            "No signed-in OpenAI web session found.",
                            "Found \(foundText).",
                        ].joined(separator: " ")
                        : [
                            "Browser cookies do not match Codex account (\(normalizedTarget ?? "unknown")).",
                            "Found \(foundText).",
                        ].joined(separator: " ")
                    // Treat mismatch like "not logged in" for the current Codex account.
                    self.openAIDashboardRequiresLogin = true
                    self.openAIDashboard = nil
                }
            case .noCookiesFound,
                 .browserAccessDenied,
                 .dashboardStillRequiresLogin:
                self.logOpenAIWeb("[\(stamp)] import failed: \(err.localizedDescription)")
                await MainActor.run {
                    self.openAIDashboardCookieImportStatus =
                        "Browser cookie import failed: \(err.localizedDescription)"
                    self.openAIDashboardRequiresLogin = true
                }
            }
        } catch {
            self.logOpenAIWeb("[\(stamp)] import failed: \(error.localizedDescription)")
            await MainActor.run {
                self.openAIDashboardCookieImportStatus =
                    "Browser cookie import failed: \(error.localizedDescription)"
            }
        }
        return nil
    }

    private func resetOpenAIWebDebugLog(context: String) {
        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        self.openAIWebDebugLines.removeAll(keepingCapacity: true)
        self.openAIDashboardCookieImportDebugLog = nil
        self.logOpenAIWeb("[\(stamp)] OpenAI web \(context) start")
    }

    private func logOpenAIWeb(_ message: String) {
        self.openAIWebLogger.debug(message)
        self.openAIWebDebugLines.append(message)
        if self.openAIWebDebugLines.count > 240 {
            self.openAIWebDebugLines.removeFirst(self.openAIWebDebugLines.count - 240)
        }
        self.openAIDashboardCookieImportDebugLog = self.openAIWebDebugLines.joined(separator: "\n")
    }

    private func dashboardEmailMismatch(expected: String?, actual: String?) -> Bool {
        guard let expected, !expected.isEmpty else { return false }
        guard let raw = actual?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return false }
        return raw.lowercased() != expected.lowercased()
    }

    func codexAccountEmailForOpenAIDashboard() -> String? {
        let direct = self.snapshots[.codex]?.accountEmail(for: .codex)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct, !direct.isEmpty { return direct }
        let fallback = self.codexFetcher.loadAccountInfo().email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fallback, !fallback.isEmpty { return fallback }
        let cached = self.openAIDashboard?.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached, !cached.isEmpty { return cached }
        let imported = self.lastOpenAIDashboardCookieImportEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let imported, !imported.isEmpty { return imported }
        return nil
    }
}
