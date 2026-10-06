import Foundation

public protocol ClaudeUsageFetching: Sendable {
    func loadLatestUsage(model: String) async throws -> ClaudeUsageSnapshot
    func debugRawProbe(model: String) async -> String
    func detectVersion() -> String?
}

public struct ClaudeUsageSnapshot: Sendable {
    public let primary: RateWindow
    public let secondary: RateWindow?
    public let opus: RateWindow?
    public let providerCost: ProviderCostSnapshot?
    public let updatedAt: Date
    public let accountEmail: String?
    public let accountOrganization: String?
    public let loginMethod: String?
    public let rawText: String?
    /// Banked "reset your limits" grants, when the source reports them.
    public let resetCredits: UsageResetCredits?
    /// True when the OAuth path had no usable token and the numbers were read
    /// through the Claude CLI instead (no cost block, no reset credits).
    public var servedByCLIFallback = false

    public init(
        primary: RateWindow,
        secondary: RateWindow?,
        opus: RateWindow?,
        providerCost: ProviderCostSnapshot? = nil,
        updatedAt: Date,
        accountEmail: String?,
        accountOrganization: String?,
        loginMethod: String?,
        rawText: String?,
        resetCredits: UsageResetCredits? = nil)
    {
        self.resetCredits = resetCredits
        self.primary = primary
        self.secondary = secondary
        self.opus = opus
        self.providerCost = providerCost
        self.updatedAt = updatedAt
        self.accountEmail = accountEmail
        self.accountOrganization = accountOrganization
        self.loginMethod = loginMethod
        self.rawText = rawText
    }
}

extension ClaudeUsageSnapshot {
    /// The claude.ai prepaid balance, merged into the usage-credits cost (or a
    /// balance-only cost when the OAuth reply had no spend block).
    func with(creditBalance: ClaudeMoney) -> ClaudeUsageSnapshot {
        let currency = creditBalance.currency ?? self.providerCost?.currencyCode ?? "USD"
        var cost: ProviderCostSnapshot
        if let existing = self.providerCost, existing.currencyCode == currency {
            cost = existing
        } else if let existing = self.providerCost, existing.used > 0 || existing.limit > 0 {
            // Real spend in another currency: never print one currency's
            // amount with the other's symbol.
            return self
        } else {
            // No spend yet: take the balance's currency (claude.ai bills in the
            // account's own currency; the OAuth block defaults to USD).
            cost = ProviderCostSnapshot(
                used: 0,
                limit: 0,
                currencyCode: currency,
                period: "Monthly",
                updatedAt: self.updatedAt)
            cost.isEnabled = self.providerCost?.isEnabled
        }
        cost.balance = creditBalance.value
        var copy = ClaudeUsageSnapshot(
            primary: self.primary,
            secondary: self.secondary,
            opus: self.opus,
            providerCost: cost,
            updatedAt: self.updatedAt,
            accountEmail: self.accountEmail,
            accountOrganization: self.accountOrganization,
            loginMethod: self.loginMethod,
            rawText: self.rawText,
            resetCredits: self.resetCredits)
        copy.servedByCLIFallback = self.servedByCLIFallback
        return copy
    }

    func with(resetCredits: UsageResetCredits?) -> ClaudeUsageSnapshot {
        var copy = ClaudeUsageSnapshot(
            primary: self.primary,
            secondary: self.secondary,
            opus: self.opus,
            providerCost: self.providerCost,
            updatedAt: self.updatedAt,
            accountEmail: self.accountEmail,
            accountOrganization: self.accountOrganization,
            loginMethod: self.loginMethod,
            rawText: self.rawText,
            resetCredits: resetCredits)
        copy.servedByCLIFallback = self.servedByCLIFallback
        return copy
    }
}

public enum ClaudeUsageError: LocalizedError, Sendable {
    case claudeNotInstalled
    case parseFailed(String)
    case oauthFailed(String)

    public var errorDescription: String? {
        switch self {
        case .claudeNotInstalled:
            "Claude CLI is not installed. Install it from https://docs.claude.ai/claude-code."
        case let .parseFailed(details):
            "Could not parse Claude usage: \(details)"
        case let .oauthFailed(details):
            details
        }
    }
}

public struct ClaudeUsageFetcher: ClaudeUsageFetching, Sendable {
    private let environment: [String: String]
    private let dataSource: ClaudeUsageDataSource
    private let useWebExtras: Bool
    private static let log = RunicLog.logger("claude-usage")

    /// Creates a new ClaudeUsageFetcher.
    /// - Parameters:
    ///   - environment: Process environment (default: current process environment)
    ///   - dataSource: Usage data source (default: OAuth API).
    ///   - useWebExtras: If true, attempts to enrich usage with Claude web data (cookies).
    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        dataSource: ClaudeUsageDataSource = .oauth,
        useWebExtras: Bool = false)
    {
        self.environment = environment
        self.dataSource = dataSource
        self.useWebExtras = useWebExtras
    }

    // MARK: - Parsing helpers

    public static func parse(json: Data) -> ClaudeUsageSnapshot? {
        guard let output = String(data: json, encoding: .utf8) else { return nil }
        return try? Self.parse(output: output)
    }

    private static func parse(output: String) throws -> ClaudeUsageSnapshot {
        guard
            let data = output.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ClaudeUsageError.parseFailed(output.prefix(500).description)
        }

        if let ok = obj["ok"] as? Bool, !ok {
            let hint = obj["hint"] as? String ?? (obj["pane_preview"] as? String ?? "")
            throw ClaudeUsageError.parseFailed(hint)
        }

        func firstWindowDict(_ keys: [String]) -> [String: Any]? {
            for key in keys {
                if let dict = obj[key] as? [String: Any] { return dict }
            }
            return nil
        }

        func makeWindow(_ dict: [String: Any]?) -> RateWindow? {
            guard let dict else { return nil }
            let pct = (dict["pct_used"] as? NSNumber)?.doubleValue ?? 0
            let resetText = dict["resets"] as? String
            return RateWindow(
                usedPercent: pct,
                windowMinutes: nil,
                resetsAt: Self.parseReset(text: resetText),
                resetDescription: resetText)
        }

        guard let session = makeWindow(firstWindowDict(["session_5h"])) else {
            throw ClaudeUsageError.parseFailed("missing session data")
        }
        let weekAll = makeWindow(firstWindowDict(["week_all_models", "week_all"]))

        let rawEmail = (obj["account_email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (rawEmail?.isEmpty ?? true) ? nil : rawEmail
        let rawOrg = (obj["account_org"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let org = (rawOrg?.isEmpty ?? true) ? nil : rawOrg
        let loginMethod = (obj["login_method"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let opusWindow: RateWindow? = {
            let candidates = firstWindowDict([
                "week_sonnet",
                "week_sonnet_only",
                "week_opus",
            ])
            guard let opus = candidates else { return nil }
            let pct = (opus["pct_used"] as? NSNumber)?.doubleValue ?? 0
            let resets = opus["resets"] as? String
            return RateWindow(
                usedPercent: pct,
                windowMinutes: nil,
                resetsAt: Self.parseReset(text: resets),
                resetDescription: resets)
        }()
        return ClaudeUsageSnapshot(
            primary: session,
            secondary: weekAll,
            opus: opusWindow,
            providerCost: nil,
            updatedAt: Date(),
            accountEmail: email,
            accountOrganization: org,
            loginMethod: loginMethod,
            rawText: output)
    }

    private static func parseReset(text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        let parts = text.split(separator: "(")
        let timePart = parts.first?.trimmingCharacters(in: .whitespaces)
        let tzPart = parts.count > 1
            ? parts[1].replacingOccurrences(of: ")", with: "").trimmingCharacters(in: .whitespaces)
            : nil
        let tz = tzPart.flatMap(TimeZone.init(identifier:))
        let formats = ["ha", "h:mma", "MMM d 'at' ha", "MMM d 'at' h:mma"]
        for format in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = tz ?? TimeZone.current
            df.dateFormat = format
            if let t = timePart, let date = df.date(from: t) { return date }
        }
        return nil
    }

    // MARK: - Public API

    public func detectVersion() -> String? {
        // Avoid leaking terminal control sequences (some `claude` builds write to /dev/tty even when stdout is piped).
        guard TTYCommandRunner.which("claude") != nil else { return nil }
        do {
            let out = try TTYCommandRunner().run(
                binary: "claude",
                send: "",
                options: TTYCommandRunner.Options(
                    timeout: 5.0,
                    extraArgs: ["--allowed-tools", "", "--version"],
                    initialDelay: 0.0)).text
            return TextParsing.stripANSICodes(out).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    public func debugRawProbe(model: String = "sonnet") async -> String {
        do {
            let snap = try await self.loadViaPTY(model: model, timeout: 10)
            let opus = snap.opus?.remainingPercent ?? -1
            let email = snap.accountEmail ?? "nil"
            let org = snap.accountOrganization ?? "nil"
            let weekly = snap.secondary?.remainingPercent ?? -1
            return """
            session_left=\(snap.primary.remainingPercent) weekly_left=\(weekly)
            opus_left=\(opus) email \(email) org \(org)
            \(snap)
            """
        } catch {
            return "Probe failed: \(error)"
        }
    }

    public func loadLatestUsage(model: String = "sonnet") async throws -> ClaudeUsageSnapshot {
        switch self.dataSource {
        case .oauth:
            var snap: ClaudeUsageSnapshot
            do {
                snap = try await self.loadViaOAuth()
            } catch let gap as OAuthCredentialGap {
                snap = try await self.loadViaCLIFallback(model: model, gap: gap)
            }
            snap = await self.applyWebExtrasIfNeeded(to: snap)
            return await ClaudeWebResets.attach(to: snap)
        case .web:
            return try await self.loadViaWebAPI()
        case .cli:
            do {
                var snap = try await self.loadViaPTY(model: model, timeout: 10)
                snap = await self.applyWebExtrasIfNeeded(to: snap)
                return snap
            } catch {
                var snap = try await self.loadViaPTY(model: model, timeout: 24)
                snap = await self.applyWebExtrasIfNeeded(to: snap)
                return snap
            }
        }
    }

    // MARK: - OAuth API path

    /// The OAuth path never got a usable token: Runic's copy is missing or past
    /// expiry, or the server rejected it. Everything else (scope, parse,
    /// network) is a failure the CLI would not fix, so it is not a gap.
    struct OAuthCredentialGap: Error {
        let underlying: ClaudeUsageError
    }

    private func loadViaOAuth() async throws -> ClaudeUsageSnapshot {
        let creds: ClaudeOAuthCredentials
        do {
            creds = try ClaudeOAuthCredentialsStore.load()
        } catch {
            throw OAuthCredentialGap(underlying: .oauthFailed(error.localizedDescription))
        }
        if creds.isExpired {
            throw OAuthCredentialGap(underlying: .oauthFailed("Claude OAuth token expired. Run `claude` to refresh."))
        }
        // The usage endpoint requires user:profile scope.
        if !creds.scopes.contains("user:profile") {
            throw ClaudeUsageError.oauthFailed(
                "Claude OAuth token missing 'user:profile' scope (has: \(creds.scopes.joined(separator: ", "))). "
                    + "Rate limit data unavailable.")
        }
        do {
            let usage = try await ClaudeOAuthUsageFetcher.fetchUsage(accessToken: creds.accessToken)
            return try Self.mapOAuthUsage(usage, credentials: creds)
        } catch ClaudeOAuthFetchError.unauthorized {
            throw OAuthCredentialGap(
                underlying: .oauthFailed(ClaudeOAuthFetchError.unauthorized.localizedDescription))
        } catch let error as ClaudeUsageError {
            throw error
        } catch {
            throw ClaudeUsageError.oauthFailed(error.localizedDescription)
        }
    }

    /// Runic's copy of the CLI token lasts about eight hours and cannot be
    /// renewed without a Keychain dialog, so instead of erroring until the user
    /// presses reload, read the numbers through the CLI itself — it refreshes
    /// its own token silently. The CLI session is torn down right after: a
    /// background refresh must not leave a Node process resident between ticks.
    /// On failure the OAuth error is what surfaces; it names the real fix.
    private func loadViaCLIFallback(model: String, gap: OAuthCredentialGap) async throws -> ClaudeUsageSnapshot {
        // The login-shell PATH (where `claude` usually lives) is captured in the
        // background at launch; the first refresh can land before it is known.
        await Self.awaitLoginShellPATH()
        guard TTYCommandRunner.which("claude") != nil else { throw gap.underlying }
        // Two attempts: the first launch of the CLI on a cold, busy machine can
        // miss the prompt; a fresh session right after usually lands.
        for attempt in 1...2 {
            do {
                var snap = try await self.loadViaPTY(model: model, timeout: 24)
                await ClaudeCLISession.shared.reset()
                snap.servedByCLIFallback = true
                Self.log.info("Claude OAuth copy unavailable; usage read through the CLI")
                return snap
            } catch {
                await ClaudeCLISession.shared.reset()
                Self.log.warning("Claude CLI fallback attempt \(attempt) failed: \(error.localizedDescription)")
                Self.recordFallbackFailure(attempt: attempt, error: error, gap: gap)
            }
        }
        throw gap.underlying
    }

    /// Unified-log bodies are private, so keep the last fallback failure where
    /// the user can read it: `~/Library/Application Support/Runic/diagnostics`.
    /// Error descriptions only — no token, account or screen text.
    private static func recordFallbackFailure(attempt: Int, error: Error, gap: OAuthCredentialGap) {
        let shape: [String: Any] = [
            "at": ISO8601DateFormatter().string(from: Date()),
            "attempt": attempt,
            "cancelled": Task.isCancelled,
            "oauthGap": gap.underlying.localizedDescription,
            "cliError": String(describing: error),
        ]
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Runic/diagnostics", isDirectory: true),
            let json = try? JSONSerialization.data(withJSONObject: shape, options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? json.write(to: directory.appendingPathComponent("claude-cli-fallback-\(attempt).json"), options: .atomic)
    }

    private static func mapOAuthUsage(
        _ usage: OAuthUsageResponse,
        credentials: ClaudeOAuthCredentials) throws -> ClaudeUsageSnapshot
    {
        func makeWindow(_ window: OAuthUsageWindow?, windowMinutes: Int?) -> RateWindow? {
            guard let window,
                  let utilization = window.utilization
            else { return nil }
            let resetDate = ClaudeOAuthUsageFetcher.parseISO8601Date(window.resetsAt)
            let resetDescription = resetDate.map(Self.formatResetDate)
            return RateWindow(
                usedPercent: utilization,
                windowMinutes: windowMinutes,
                resetsAt: resetDate,
                resetDescription: resetDescription)
        }

        guard let primary = makeWindow(usage.fiveHour, windowMinutes: 5 * 60) else {
            throw ClaudeUsageError.parseFailed("missing session data")
        }

        let weekly = makeWindow(usage.sevenDay, windowMinutes: 7 * 24 * 60)
        let modelSpecific = makeWindow(
            usage.sevenDaySonnet ?? usage.sevenDayOpus,
            windowMinutes: 7 * 24 * 60) ?? Self.scopedLimitWindow(usage.limits)

        return ClaudeUsageSnapshot(
            primary: primary,
            secondary: weekly,
            opus: modelSpecific,
            providerCost: usage.spend?.costSnapshot ?? Self.oauthExtraUsageCost(usage.extraUsage),
            updatedAt: Date(),
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: Self.inferPlan(rateLimitTier: credentials.rateLimitTier),
            rawText: nil,
            resetCredits: usage.cedarEmber?.resetCredits())
    }

    /// A model-scoped weekly limit from the `limits` list (a promotional
    /// model's own allowance), labelled with the model name so the card and
    /// the Resets panel show it as its own window.
    static func scopedLimitWindow(_ limits: [OAuthLimitEntry]?) -> RateWindow? {
        guard let limits else { return nil }
        let scoped = limits.filter { $0.scopedModelName != nil && $0.percent != nil }
        guard let entry = scoped.first(where: { $0.isActive == true }) ?? scoped.first,
              let percent = entry.percent,
              let model = entry.scopedModelName else { return nil }
        let resetDate = ClaudeOAuthUsageFetcher.parseISO8601Date(entry.resetsAt)
        let isWeekly = (entry.group ?? entry.kind ?? "").lowercased().contains("week")
        return RateWindow(
            usedPercent: percent,
            windowMinutes: isWeekly ? 7 * 24 * 60 : nil,
            resetsAt: resetDate,
            resetDescription: resetDate.map(Self.formatResetDate),
            label: isWeekly ? "\(model) weekly" : model)
    }

    private static func oauthExtraUsageCost(_ extra: OAuthExtraUsage?) -> ProviderCostSnapshot? {
        guard let extra, extra.isEnabled == true else { return nil }
        guard let used = extra.usedCredits,
              let limit = extra.monthlyLimit else { return nil }
        let currency = extra.currency?.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = (currency?.isEmpty ?? true) ? "USD" : currency!
        return ProviderCostSnapshot(
            used: used,
            limit: limit,
            currencyCode: code,
            period: "Monthly",
            resetsAt: nil,
            updatedAt: Date())
    }

    private static func inferPlan(rateLimitTier: String?) -> String? {
        let tier = rateLimitTier?.lowercased() ?? ""
        if tier.contains("max") { return "Claude Max" }
        if tier.contains("pro") { return "Claude Pro" }
        if tier.contains("team") { return "Claude Team" }
        if tier.contains("enterprise") { return "Claude Enterprise" }
        return nil
    }

    // MARK: - Web API path (uses browser cookies)

    private func loadViaWebAPI() async throws -> ClaudeUsageSnapshot {
        let webData = try await ClaudeWebAPIFetcher.fetchUsage { msg in
            Self.log.debug(msg)
        }
        // Convert web API data to ClaudeUsageSnapshot format
        let primary = RateWindow(
            usedPercent: webData.sessionPercentUsed,
            windowMinutes: 5 * 60,
            resetsAt: webData.sessionResetsAt,
            resetDescription: webData.sessionResetsAt.map { Self.formatResetDate($0) })

        let secondary: RateWindow? = webData.weeklyPercentUsed.map { pct in
            RateWindow(
                usedPercent: pct,
                windowMinutes: 7 * 24 * 60,
                resetsAt: webData.weeklyResetsAt,
                resetDescription: webData.weeklyResetsAt.map { Self.formatResetDate($0) })
        }

        let opus: RateWindow? = webData.opusPercentUsed.map { opusPct in
            RateWindow(
                usedPercent: opusPct,
                windowMinutes: 7 * 24 * 60,
                resetsAt: webData.weeklyResetsAt,
                resetDescription: webData.weeklyResetsAt.map { Self.formatResetDate($0) })
        }

        return ClaudeUsageSnapshot(
            primary: primary,
            secondary: secondary,
            opus: opus,
            providerCost: webData.extraUsageCost,
            updatedAt: Date(),
            accountEmail: webData.accountEmail,
            accountOrganization: webData.accountOrganization,
            loginMethod: webData.loginMethod,
            rawText: nil,
            resetCredits: webData.resetCredits)
    }

    private static func formatResetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mma"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    // MARK: - PTY-based probe (no tmux)

    private func loadViaPTY(model: String, timeout: TimeInterval = 10) async throws -> ClaudeUsageSnapshot {
        guard TTYCommandRunner.which("claude") != nil else { throw ClaudeUsageError.claudeNotInstalled }
        let probe = ClaudeStatusProbe(claudeBinary: "claude", timeout: timeout)
        let snap = try await probe.fetch()

        guard let sessionPctLeft = snap.sessionPercentLeft else {
            throw ClaudeUsageError.parseFailed("missing session data")
        }

        func makeWindow(pctLeft: Int?, reset: String?) -> RateWindow? {
            guard let left = pctLeft else { return nil }
            let used = max(0, min(100, 100 - Double(left)))
            let resetClean = reset?.trimmingCharacters(in: .whitespacesAndNewlines)
            return RateWindow(
                usedPercent: used,
                windowMinutes: nil,
                resetsAt: ClaudeStatusProbe.parseResetDate(from: resetClean),
                resetDescription: resetClean)
        }

        let primary = makeWindow(pctLeft: sessionPctLeft, reset: snap.primaryResetDescription)!
        let weekly = makeWindow(pctLeft: snap.weeklyPercentLeft, reset: snap.secondaryResetDescription)
        let opus = makeWindow(pctLeft: snap.opusPercentLeft, reset: snap.opusResetDescription)

        return ClaudeUsageSnapshot(
            primary: primary,
            secondary: weekly,
            opus: opus,
            providerCost: nil,
            updatedAt: Date(),
            accountEmail: snap.accountEmail,
            accountOrganization: snap.accountOrganization,
            loginMethod: snap.loginMethod,
            rawText: snap.rawText)
    }

    private static func awaitLoginShellPATH() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            LoginShellPathCache.shared.captureOnce { _ in continuation.resume() }
        }
    }

    private func applyWebExtrasIfNeeded(to snapshot: ClaudeUsageSnapshot) async -> ClaudeUsageSnapshot {
        guard self.useWebExtras, self.dataSource != .web else { return snapshot }
        do {
            let webData = try await ClaudeWebAPIFetcher.fetchUsage { msg in
                Self.log.debug(msg)
            }
            // Only merge cost extras; keep identity fields from the primary data source.
            if snapshot.providerCost == nil, let extra = webData.extraUsageCost {
                return ClaudeUsageSnapshot(
                    primary: snapshot.primary,
                    secondary: snapshot.secondary,
                    opus: snapshot.opus,
                    providerCost: extra,
                    updatedAt: snapshot.updatedAt,
                    accountEmail: snapshot.accountEmail,
                    accountOrganization: snapshot.accountOrganization,
                    loginMethod: snapshot.loginMethod,
                    rawText: snapshot.rawText,
                    resetCredits: snapshot.resetCredits)
            }
        } catch {
            Self.log.debug("Claude web extras fetch failed: \(error.localizedDescription)")
        }
        return snapshot
    }

    // MARK: - Process helpers

    private static func which(_ tool: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [tool]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !path.isEmpty else { return nil }
        return path
    }

    private static func readString(cmd: String, args: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cmd)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

#if DEBUG
extension ClaudeUsageFetcher {
    public static func _mapOAuthUsageForTesting(
        _ data: Data,
        rateLimitTier: String? = nil) throws -> ClaudeUsageSnapshot
    {
        let usage = try ClaudeOAuthUsageFetcher.decodeUsageResponse(data)
        let creds = ClaudeOAuthCredentials(
            accessToken: "test",
            refreshToken: nil,
            expiresAt: Date().addingTimeInterval(3600),
            scopes: [],
            rateLimitTier: rateLimitTier)
        return try Self.mapOAuthUsage(usage, credentials: creds)
    }
}
#endif
