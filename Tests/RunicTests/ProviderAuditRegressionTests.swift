import Foundation
import Testing
@testable import RunicCore

struct CoreAndRPCRegressionTests {
    @Test
    func `usageSnapshot codable roundTrip preserves additionalWindows and preferredQuotaWindow`() throws {
        let now = Date(timeIntervalSince1970: 1_795_590_000)
        let primary = RateWindow(
            usedPercent: 2.24,
            windowMinutes: 300,
            resetsAt: now,
            resetDescription: nil,
            label: "Gemini 5h")
        let secondary = RateWindow(
            usedPercent: 3.78,
            windowMinutes: 10080,
            resetsAt: now,
            resetDescription: nil,
            label: "Gemini Weekly")
        let tertiary = RateWindow(
            usedPercent: 0,
            windowMinutes: 300,
            resetsAt: nil,
            resetDescription: nil,
            label: "Claude & GPT 5h")
        let fourth = RateWindow(
            usedPercent: 45.41,
            windowMinutes: 10080,
            resetsAt: now,
            resetDescription: nil,
            label: "Claude & GPT Weekly")
        let snapshot = UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            additionalWindows: [fourth],
            updatedAt: now,
            identity: ProviderIdentitySnapshot(
                providerID: .antigravity,
                accountEmail: "dev@example.com",
                accountOrganization: nil,
                loginMethod: "Google AI Ultra"))

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: data)

        #expect(decoded.additionalWindows == [fourth])
        #expect(decoded.allWindows.map(\.label) == [
            "Gemini 5h",
            "Gemini Weekly",
            "Claude & GPT 5h",
            "Claude & GPT Weekly",
        ])
        #expect(decoded.scoped(to: .antigravity).additionalWindows == [fourth])
        #expect(decoded.preferredQuotaWindow(for: .antigravity)?.label == "Gemini 5h")

        // Exercise copy-constructor path when identity has a different providerID.
        let foreignSnapshot = UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            additionalWindows: [fourth],
            updatedAt: now,
            identity: ProviderIdentitySnapshot(
                providerID: .claude,
                accountEmail: "dev@example.com",
                accountOrganization: nil,
                loginMethod: "Max"))
        let rescoped = foreignSnapshot.scoped(to: .antigravity)
        #expect(rescoped.identity?.providerID == .antigravity)
        #expect(rescoped.additionalWindows == [fourth])
    }

    @Test
    func `preferredQuotaWindow skips limitless wallets and picks factory premium`() {
        let now = Date(timeIntervalSince1970: 1_795_590_000)
        let balanceOnly = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: $12.00",
                hasKnownLimit: false),
            secondary: nil,
            updatedAt: now)
        #expect(balanceOnly.preferredQuotaWindow(for: .vercelai) == nil)

        let openRouterWithKeyLimit = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: $12.00",
                hasKnownLimit: false),
            secondary: RateWindow(
                usedPercent: 25,
                windowMinutes: 1440,
                resetsAt: now,
                resetDescription: nil,
                label: "Key limit",
                hasKnownLimit: true),
            updatedAt: now)
        #expect(openRouterWithKeyLimit.preferredQuotaWindow(for: .openrouter)?.label == "Key limit")

        let factory = UsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 43200, resetsAt: nil, resetDescription: nil),
            secondary: RateWindow(usedPercent: 40, windowMinutes: 43200, resetsAt: nil, resetDescription: nil),
            updatedAt: now)
        #expect(factory.preferredQuotaWindow(for: .factory)?.usedPercent == 40)
    }

    @Test
    func `providerFetchPipeline preserves primary error across unavailable fallback`() async {
        struct PrimaryBoom: LocalizedError, Equatable {
            var errorDescription: String? {
                "primary auth expired"
            }
        }
        struct FailingPrimaryStrategy: ProviderFetchStrategy {
            let id = "primary.fail"
            let kind: ProviderFetchKind = .api
            func isAvailable(_ context: ProviderFetchContext) async -> Bool {
                true
            }

            func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
                throw PrimaryBoom()
            }

            func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
                true
            }
        }
        struct UnavailableFallbackStrategy: ProviderFetchStrategy {
            let id = "fallback.unavailable"
            let kind: ProviderFetchKind = .cli
            func isAvailable(_ context: ProviderFetchContext) async -> Bool {
                false
            }

            func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
                throw PrimaryBoom()
            }

            func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
                false
            }
        }
        let dummyContext = ProviderFetchContext(
            runtime: .app,
            sourceMode: .auto,
            includeCredits: false,
            webTimeout: 10,
            webDebugDumpHTML: false,
            verbose: false,
            env: [:],
            settings: nil,
            fetcher: UsageFetcher(environment: [:]),
            claudeFetcher: ClaudeUsageFetcher())
        let pipeline = ProviderFetchPipeline(
            resolveStrategies: { _ in [FailingPrimaryStrategy(), UnavailableFallbackStrategy()] },
            strategyTimeout: 2)

        let outcome = await pipeline.fetch(context: dummyContext, provider: .antigravity)
        if case let .failure(error) = outcome.result {
            #expect(error.localizedDescription == "primary auth expired")
        } else {
            Issue.record("Expected primary error to be preserved when fallback is unavailable")
        }
    }

    @Test
    func `codexRPCClient handles multiRequest buffered responses`() async throws {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-mock-codex-rpc-\(UUID().uuidString).sh")
        let script = """
        #!/bin/sh
        while IFS= read -r line; do
          case "$line" in
            *initialize*)
              echo '{"id":1,"result":{"userAgent":"mock-codex"}}'
              ;;
            *rateLimits*read*)
              echo '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":12.5,"windowDurationMins":300}}}}'
              exit 0
              ;;
          esac
        done
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let rpc = try CodexRPCClient(executable: scriptURL.path, arguments: [], requestTimeout: 3.0)
        defer { rpc.shutdown() }
        try await rpc.initialize(clientName: "runic-test", clientVersion: "1.0")
        let response = try await rpc.fetchRateLimits()
        #expect(response.rateLimits.primary?.usedPercent == 12.5)
        #expect(response.rateLimits.primary?.windowDurationMins == 300)
    }

    @Test
    func `codexRPCClient times out cleanly on hanging process`() async throws {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-hang-codex-rpc-\(UUID().uuidString).sh")
        let script = """
        #!/bin/sh
        sleep 10
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let rpc = try CodexRPCClient(executable: scriptURL.path, arguments: [], requestTimeout: 0.25)
        defer { rpc.shutdown() }
        let start = Date()
        do {
            try await rpc.initialize(clientName: "runic-test", clientVersion: "1.0")
            Issue.record("Expected CodexRPCClient to throw timedOut")
        } catch let error as RPCWireError {
            #expect(error == .timedOut("initialize"))
            #expect(Date().timeIntervalSince(start) < 2.5)
        }
    }

    @Test
    func `codexRPCClient propagates cancellation and double shutdown is safe`() async throws {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-cancel-codex-rpc-\(UUID().uuidString).sh")
        let script = """
        #!/bin/sh
        sleep 10
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let rpc = try CodexRPCClient(executable: scriptURL.path, arguments: [], requestTimeout: 5.0)
        let task = Task {
            try await rpc.initialize(clientName: "runic-test", clientVersion: "1.0")
        }
        try? await Task.sleep(for: .milliseconds(80))
        task.cancel()
        do {
            try await task.value
            Issue.record("Expected CodexRPCClient to throw CancellationError")
        } catch is CancellationError {
            // Expected cancellation propagation.
        }
        rpc.shutdown()
        rpc.shutdown()
    }

    @Test
    func `ttyCommandRunner updateRecentText preserves markers across split utf8 chunks`() {
        var state = TTYCommandRunner.GenericCaptureState(maxNeedle: 32)
        let chunk = Data([0x80, 0x94] + Array("───\r\n? for shortcuts".utf8))
        TTYCommandRunner.updateRecentText(chunk, state: &state)
        #expect(state.recentText.contains("? for shortcuts"))
    }
}

struct MiniMaxAndProviderAuditTests {
    @Test
    func `minimax millisecond timestamps convert subMillion remains_time and fallback from model_remains`() throws {
        let now = Date(timeIntervalSince1970: 1_783_555_200)
        let json = """
        {
          "base_resp": { "status_code": 0, "status_msg": "success" },
          "model_remains": [
            {
              "model_name": "MiniMax-M2",
              "current_interval_total_count": 100,
              "current_interval_usage_count": 25,
              "start_time": 1783555200000,
              "end_time": 1783573200000,
              "remains_time": 600000
            }
          ]
        }
        """
        let parsed = try MiniMaxWebParsing.parseRemainsResponse(Data(json.utf8), now: now)
        #expect(parsed.usedPercent == 75)
        #expect(parsed.windowMinutes == 300)
        #expect(parsed.resetsAt == now.addingTimeInterval(600))

        let expiredJSON = """
        { "base_resp": { "status_code": 1004, "status_msg": "not logged in" } }
        """
        do {
            _ = try MiniMaxWebParsing.parseRemainsResponse(Data(expiredJSON.utf8), now: now)
            Issue.record("Expected notLoggedIn on status_code 1004")
        } catch let MiniMaxWebUsageError.notLoggedIn(message) {
            #expect(message == "not logged in")
        }

        // M6: Percentage-only MiniMax quota (total == 0) remains valid, selected, and omits "0 / 0 remaining".
        let percentOnlyJSON = """
        {
          "base_resp": { "status_code": 0, "status_msg": "success" },
          "model_remains": [
            {
              "model_name": "MiniMax-M2.5",
              "current_interval_total_count": 0,
              "current_interval_usage_count": 0,
              "current_interval_remaining_percent": 80.0,
              "current_weekly_total_count": 0,
              "current_weekly_remaining_percent": 90.0
            }
          ]
        }
        """
        let apiParsed = try MiniMaxUsageFetcher.parseUsageResponse(Data(percentOnlyJSON.utf8), now: now)
        #expect(apiParsed.isValid == true)
        let apiSnap = apiParsed.toUsageSnapshot()
        #expect(apiSnap.primary.usedPercent == 20)
        #expect(apiSnap.primary.resetDescription == nil)
        #expect(apiSnap.secondary?.usedPercent == 10)
        #expect(apiSnap.secondary?.resetDescription == nil)
    }

    @Test
    func `gemini collects multiple distinct PATH binaries and keeps 4+ models`() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runic-gemini-\(UUID().uuidString)")
        let binA = root.appendingPathComponent("binA")
        let binB = root.appendingPathComponent("binB")
        let binC = root.appendingPathComponent("binC")
        let binD = root.appendingPathComponent("binD")
        try fm.createDirectory(at: binA, withIntermediateDirectories: true)
        try fm.createDirectory(at: binB, withIntermediateDirectories: true)
        try fm.createDirectory(at: binC, withIntermediateDirectories: true)
        try fm.createDirectory(at: binD.appendingPathComponent("gemini"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let wrapperA = binA.appendingPathComponent("gemini")
        let realB = binB.appendingPathComponent("gemini")
        let symlinkB = binC.appendingPathComponent("gemini")
        try "#!/bin/sh\n".write(to: wrapperA, atomically: true, encoding: .utf8)
        try "#!/bin/sh\n".write(to: realB, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperA.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: realB.path)
        try fm.createSymbolicLink(atPath: symlinkB.path, withDestinationPath: realB.path)

        let candidates = GeminiStatusProbe.collectGeminiBinaryCandidates(
            env: ["PATH": "\(binD.path):\(binA.path):\(binB.path):\(binC.path):\(binA.path)"],
            loginPATH: [binB.path],
            fileManager: fm,
            home: root.path,
            includeSystemFallbacks: false)
        #expect(candidates == [realB.path, wrapperA.path])
        #expect(!candidates.contains(symlinkB.path))
        #expect(!candidates.contains(binD.appendingPathComponent("gemini").path))

        let snap = GeminiStatusSnapshot(
            modelQuotas: [
                GeminiModelQuota(modelId: "gemini-2.5-pro", percentLeft: 80, resetTime: nil, resetDescription: nil),
                GeminiModelQuota(modelId: "gemini-2.5-flash", percentLeft: 90, resetTime: nil, resetDescription: nil),
                GeminiModelQuota(
                    modelId: "gemini-2.5-flash-lite",
                    percentLeft: 95,
                    resetTime: nil,
                    resetDescription: nil),
                GeminiModelQuota(modelId: "gemini-2.0-pro", percentLeft: 70, resetTime: nil, resetDescription: nil),
            ],
            rawText: "",
            accountEmail: nil,
            accountPlan: nil).toUsageSnapshot()
        #expect(snap.allWindows.count == 4)
        #expect(snap.additionalWindows?.count == 1)
    }

    @Test
    func `copilot parses day reset dates and partitions unlimited quotas after limited ones`() throws {
        let fetcher = CopilotUsageFetcher(token: "test-token")
        let date = fetcher.parseDate("2026-12-01")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        #expect(date != nil)
        if let date {
            let comps = utc.dateComponents([.year, .month, .day, .hour], from: date)
            #expect(comps.year == 2026 && comps.month == 12 && comps.day == 1 && comps.hour == 0)
        }

        let payload = """
        {
          "copilot_plan": "individual",
          "quota_reset_date": "2026-12-01",
          "quota_snapshots": {
            "premium_interactions": {
              "quota_id": "premium_interactions",
              "entitlement": 300,
              "remaining": 150,
              "percent_remaining": 50.0,
              "unlimited": false
            },
            "completions": {
              "quota_id": "completions",
              "unlimited": true
            },
            "chat": {
              "quota_id": "chat",
              "entitlement": 100,
              "remaining": 80,
              "percent_remaining": 80.0,
              "unlimited": false
            }
          }
        }
        """
        let decoded = try JSONDecoder().decode(CopilotUsageResponse.self, from: Data(payload.utf8))
        let snapshot = try fetcher.makeSnapshot(from: decoded)
        #expect(snapshot.primary.label == "premium interactions")
        #expect(snapshot.secondary?.label == "chat")
        #expect(snapshot.tertiary?.label == "completions")
        #expect(snapshot.tertiary?.hasKnownLimit == false)
        #expect(snapshot.tertiary?.resetDescription == "Unlimited")

        // Distinct slots lacking `quota_id` remain distinct even when both are unlimited.
        let unnamedPayload = """
        {
          "copilot_plan": "individual",
          "quota_snapshots": {
            "completions": { "unlimited": true },
            "chat": { "unlimited": true }
          }
        }
        """
        let unnamedDecoded = try JSONDecoder().decode(CopilotUsageResponse.self, from: Data(unnamedPayload.utf8))
        let unnamedSnap = try fetcher.makeSnapshot(from: unnamedDecoded)
        #expect(unnamedSnap.allWindows.count == 2)
    }

    @Test
    func `muse parses single window output, handles lossy utf8, and propagates cancellation`() async throws {
        let singleWindow = """
        Muse Code High Usage
        Current 24% used · Resets at 7:39 PM
        """
        let snapshot = try MuseCodeCLIUsageFetcher.parse(text: singleWindow)
        #expect(snapshot.primary.usedPercent == 24)
        #expect(snapshot.primary.resetsAt != nil)
        #expect(snapshot.secondary == nil)

        // Truncated trailing multi-byte sequence does not drop the valid prefix.
        let bytes = Array("Current 10% used ".utf8) + [0xE2, 0x96]
        let decoded = MuseCodeCLIUsageFetcher.decodeLossyText(Data(bytes))
        #expect(decoded.contains("Current 10% used"))

        // H5: Cancelling the caller task aborts the PTY subprocess cleanly.
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-mock-muse-\(UUID().uuidString).sh")
        let script = """
        #!/bin/sh
        echo "Muse Code"
        sleep 10
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let task = Task {
            try await MuseCodeCLIUsageFetcher.load(binary: scriptURL.path, env: [:])
        }
        try? await Task.sleep(for: .milliseconds(80))
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected MuseCodeCLIUsageFetcher to throw CancellationError")
        } catch is CancellationError {
            // Expected cancellation propagation.
        }
    }

    @Test
    func `ollamacloud extracts request counts and gates web enrichment to default auto app`() throws {
        let json = """
        {
          "totals": { "request_count": 42 },
          "buckets": [
            { "range": "24h", "request_count": 12 }
          ],
          "limits": {
            "session": { "usage": 0.25 },
            "weekly": { "usage": 0.5 },
            "monthly": { "usage": 0.1 }
          }
        }
        """
        let usage = try OllamaCloudUsage.parse(Data(json.utf8))
        let snapshot = usage.toUsageSnapshot()
        #expect(snapshot.allWindows.count == 3)

        let counterOnlyJSON = """
        {
          "totals": { "request_count": 17 }
        }
        """
        let emptyUsage = try OllamaCloudUsage.parse(Data(counterOnlyJSON.utf8))
        let counterSnap = emptyUsage.toUsageSnapshot()
        #expect(counterSnap.primary.hasKnownLimit == false)
        #expect(counterSnap.primary.resetDescription == "17 requests")

        // H4: Web enrichment runs ONLY on default account in `.app` + `.auto` mode.
        let fetcher = UsageFetcher(environment: [:])
        let defaultAutoContext = ProviderFetchContext(
            runtime: .app,
            sourceMode: .auto,
            includeCredits: false,
            webTimeout: 10,
            webDebugDumpHTML: false,
            verbose: false,
            env: [:],
            settings: nil,
            fetcher: fetcher,
            claudeFetcher: ClaudeUsageFetcher(),
            account: AccountID(kind: .ollamacloud))
        let secondaryAccountContext = ProviderFetchContext(
            runtime: .app,
            sourceMode: .auto,
            includeCredits: false,
            webTimeout: 10,
            webDebugDumpHTML: false,
            verbose: false,
            env: [:],
            settings: nil,
            fetcher: fetcher,
            claudeFetcher: ClaudeUsageFetcher(),
            account: AccountID(kind: .ollamacloud, slug: "work"))
        let cliModeContext = ProviderFetchContext(
            runtime: .app,
            sourceMode: .cli,
            includeCredits: false,
            webTimeout: 10,
            webDebugDumpHTML: false,
            verbose: false,
            env: [:],
            settings: nil,
            fetcher: fetcher,
            claudeFetcher: ClaudeUsageFetcher(),
            account: AccountID(kind: .ollamacloud))
        #expect(OllamaCloudAPIFetchStrategy.shouldEnrichFromWeb(context: defaultAutoContext, usage: emptyUsage) == true)
        #expect(
            OllamaCloudAPIFetchStrategy
                .shouldEnrichFromWeb(context: secondaryAccountContext, usage: emptyUsage) == false)
        #expect(OllamaCloudAPIFetchStrategy.shouldEnrichFromWeb(context: cliModeContext, usage: emptyUsage) == false)
    }

    @Test
    func `claude parses fable label and deduplicates flat and scoped weekly model windows`() throws {
        let text = """
        Current session
        [████      ] 20% used

        Current Fable
        [██        ] 10% used
        Resets Oct 10 at 2:00 AM
        """
        let parsed = try ClaudeStatusProbe.parse(text: text)
        #expect(parsed.opusLabel == "Fable")
        #expect(parsed.opusPercentLeft == 90)

        let oauthJSON = """
        {
          "five_hour": { "utilization": 15.0, "resets_at": "2026-12-01T05:00:00Z" },
          "seven_day": { "utilization": 40.0, "resets_at": "2026-12-07T00:00:00Z" },
          "seven_day_opus": { "utilization": 10.0, "resets_at": "2026-12-07T00:00:00Z" },
          "seven_day_sonnet": { "utilization": 22.0, "resets_at": "2026-12-07T00:00:00Z" },
          "limits": [
            {
              "kind": "weekly",
              "group": "weekly",
              "percent": 22.0,
              "resets_at": "2026-12-07T00:00:00Z",
              "is_active": true,
              "scope": { "model": { "id": "claude-sonnet-4", "display_name": "Sonnet" } }
            },
            {
              "kind": "weekly",
              "group": "weekly",
              "percent": 5.0,
              "resets_at": "2026-12-07T00:00:00Z",
              "is_active": true,
              "scope": { "model": { "id": "claude-haiku-4", "display_name": "Haiku" } }
            }
          ]
        }
        """
        let oauth = try ClaudeUsageFetcher._mapOAuthUsageForTesting(
            Data(oauthJSON.utf8),
            rateLimitTier: "default_claude_max_5x")
        #expect(oauth.primary.usedPercent == 15)
        #expect(oauth.secondary?.usedPercent == 40)
        // Opus + Sonnet + Haiku (scoped Sonnet weekly deduplicated against flat seven_day_sonnet).
        #expect(oauth.opus?.label == "Sonnet")
        #expect(oauth.additionalWindows?.map(\.label) == ["Opus", "Haiku weekly"])
    }

    @Test
    func `codex decodes fractional used_percent and additional_rate_limits`() throws {
        let json = """
        {
          "plan_type": "pro",
          "rate_limit": {
            "primary_window": { "used_percent": 12.75, "reset_at": 1795590000, "limit_window_seconds": 18000 }
          },
          "additional_rate_limits": [
            {
              "limit_name": "GPT-5.3 Codex Spark",
              "metered_feature": "codex_spark",
              "rate_limit": {
                "primary_window": { "used_percent": 4.5, "reset_at": 1795590000, "limit_window_seconds": 18000 },
                "secondary_window": { "used_percent": 9.25, "reset_at": 1796194800, "limit_window_seconds": 604800 }
              }
            },
            {
              "limit_name": "Deep Research",
              "metered_feature": "deep_research",
              "rate_limit": {
                "secondary_window": { "used_percent": 20.0, "reset_at": 1796194800, "limit_window_seconds": 604800 }
              }
            }
          ]
        }
        """
        let decoded = try CodexOAuthUsageFetcher._decodeUsageResponseForTesting(Data(json.utf8))
        #expect(decoded.rateLimit?.primaryWindow?.usedPercent == 12.75)
        let extras = CodexOAuthFetchStrategy.additionalWindows(decoded.additionalRateLimits)
        #expect(extras.count == 2)
        #expect(extras.first?.label == "GPT-5.3 Codex Spark weekly")
        #expect(extras.first?.usedPercent == 9.25)
        #expect(extras.last?.label == "Deep Research weekly")
    }

    @Test
    func `openrouter and vercelai wallets stay limitless while openrouter exposes periodic fallback`() throws {
        let creditsJSON = """
        { "data": { "total_credits": 100.0, "total_usage": 25.0 } }
        """
        let keyJSON = """
        {
          "data": {
            "label": "sk-or-test",
            "usage": 5.0,
            "limit": 20.0,
            "usage_daily": 1.0,
            "limit_reset": "daily",
            "is_free_tier": false
          }
        }
        """
        let credits = try JSONDecoder().decode(OpenRouterCreditsResponse.self, from: Data(creditsJSON.utf8))
        let key = try JSONDecoder().decode(OpenRouterKeyInfoResponse.self, from: Data(keyJSON.utf8))
        let snap = credits.toUsageSnapshot(keyInfo: key)
        #expect(snap.primary.hasKnownLimit == false)
        #expect(snap.secondary?.hasKnownLimit != false)
        #expect(snap.secondary?.usedPercent == 5.0)
        #expect(snap.identity?.loginMethod != nil)

        let vercelJSON = """
        { "balance": "14.50", "total_used": "5.50" }
        """
        let vercel = try JSONDecoder().decode(VercelAICreditsResponse.self, from: Data(vercelJSON.utf8))
        let vercelSnap = vercel.toUsageSnapshot()
        #expect(vercelSnap.primary.hasKnownLimit == false)
        #expect(vercelSnap.balance?.available == 14.50)
    }

    @Test
    func `qwen, zai, and kimi normalize urls, weeks/ms units, contiguous slots, and CN identities`() throws {
        let url = QwenUsageFetcher.usageURL(baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1")
        #expect(url?.absoluteString == "https://dashscope.aliyuncs.com/api/v1/usage")
        #expect(
            QwenUsageFetcher.usageURL(baseURL: "https://dashscope.aliyuncs.com/api/v1")?
                .absoluteString == "https://dashscope.aliyuncs.com/api/v1/usage")
        #expect(
            QwenUsageFetcher.usageURL(baseURL: "https://dashscope.aliyuncs.com/api/v1/usage")?
                .absoluteString == "https://dashscope.aliyuncs.com/api/v1/usage")

        let qwenSnap = QwenUsageSnapshot(
            modelEntries: [],
            totalInputTokens: 0,
            totalOutputTokens: 0,
            totalTokens: 0,
            totalRequests: 0,
            totalEstimatedCostUSD: 0,
            updatedAt: Date(),
            endpointUnavailable: true).toUsageSnapshot(providerID: .qwenCN)
        #expect(qwenSnap.primary.resetDescription == "Connected · no usage endpoint")
        #expect(qwenSnap.identity?.providerID == .qwenCN)

        #expect(ZaiLimitUnit(rawValue: 6) == .weeks)
        let rawLimitJSON = """
        { "type": "TIME_LIMIT", "unit": 6, "number": 1, "percentage": 12.5 }
        """
        let decodedRaw = try JSONDecoder().decode(ZaiLimitRaw.self, from: Data(rawLimitJSON.utf8))
        let entry = try #require(decodedRaw.toLimitEntry())
        #expect(entry.unit == .weeks)
        #expect(entry.windowMinutes == 10080)
        #expect(entry.percentage == 12.5)

        let extraA = ZaiLimitEntry(
            type: .tokensLimit,
            unit: .days,
            number: 30,
            usage: 100,
            currentValue: 10,
            remaining: 90,
            percentage: 10,
            usageDetails: [],
            nextResetTime: nil)
        let extraB = ZaiLimitEntry(
            type: .timeLimit,
            unit: .hours,
            number: 24,
            usage: 50,
            currentValue: 5,
            remaining: 45,
            percentage: 10,
            usageDetails: [],
            nextResetTime: nil)
        let extraC = ZaiLimitEntry(
            type: .tokensLimit,
            unit: .hours,
            number: 5,
            usage: 20,
            currentValue: 4,
            remaining: 16,
            percentage: 20,
            usageDetails: [],
            nextResetTime: nil)
        let zaiSnap = ZaiUsageSnapshot(
            tokenLimit: entry,
            timeLimit: nil,
            extraLimits: [extraA, extraB, extraC],
            planName: "Pro",
            updatedAt: Date()).toUsageSnapshot(providerID: .zaiCN)
        // M7: Contiguous promotion fills secondary -> tertiary -> additionalWindows without leaving secondary nil.
        #expect(zaiSnap.secondary?.windowMinutes == 30 * 1440)
        #expect(zaiSnap.tertiary?.windowMinutes == 24 * 60)
        #expect(zaiSnap.additionalWindows?.count == 1)
        #expect(zaiSnap.identity?.providerID == .zaiCN)

        // Low: Kimi TIME_UNIT_MILLISECOND converts via 60,000 ms/min instead of matching SECOND.
        let kimiJSON = """
        {
          "limits": [
            {
              "window": { "duration": 18000000, "timeUnit": "TIME_UNIT_MILLISECOND" },
              "detail": { "limit": 100, "used": 25 }
            }
          ]
        }
        """
        let kimiSnap = try KimiCodeUsageFetcher.parse(Data(kimiJSON.utf8))
        #expect(kimiSnap.primary.windowMinutes == 300)
        #expect(kimiSnap.primary.usedPercent == 25)
    }

    @Test
    func `azure, localLLM, stepfun, deepseek, auggie, factory and siliconflow guards hold`() async throws {
        #expect(
            AzureUsageFetcher.deploymentsURL(
                endpoint: "http://insecure.example.com",
                apiVersion: "2024-10-21") == nil)
        #expect(
            AzureUsageFetcher.deploymentsURL(
                endpoint: "https:///openai/deployments",
                apiVersion: "2024-10-21") == nil)
        #expect(
            AzureUsageFetcher.deploymentsURL(
                endpoint: "https://my.openai.azure.com/openai/deployments",
                apiVersion: "2024-10-21")?.path == "/openai/deployments")

        #expect(throws: (any Error).self) {
            _ = try LocalLLMUsageFetcher.parseOllamaModels(Data("{}".utf8))
        }
        #expect(throws: (any Error).self) {
            _ = try LocalLLMUsageFetcher.parseOpenAIModels(Data("{}".utf8))
        }
        #expect(throws: (any Error).self) {
            _ = try StepFunUsageFetcher.parseAccount(data: Data("not-json".utf8))
        }
        let stepFunNonFinite = try StepFunUsageFetcher.parseAccount(
            data: Data(#"{"balance": " Infinity ", "flag": true, "available_balance": " 12.5 "}"#.utf8))
        #expect(stepFunNonFinite.availableBalance == 12.5)
        let stepFunNaN = try StepFunUsageFetcher.parseAccount(data: Data(#"{"balance": "NaN"}"#.utf8))
        #expect(stepFunNaN.availableBalance == nil)

        let deepSeekJSON = """
        {
          "is_available": false,
          "balance_infos": [{ "currency": "  ", "total_balance": "0.00" }]
        }
        """
        let deepSeekSnap = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: Data(deepSeekJSON.utf8))
            .toUsageSnapshot()
        #expect(deepSeekSnap.primary.hasKnownLimit == false)
        #expect(deepSeekSnap.balance?.currency == nil)
        #expect(deepSeekSnap.balance?.blocksAPICalls == true)

        // M8: Funded blank-currency entry is not duplicated in resetDescription.
        let fundedBlankCurrency = """
        {
          "is_available": true,
          "balance_infos": [{ "currency": "  ", "total_balance": "12.50" }]
        }
        """
        let fundedSnap = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: Data(fundedBlankCurrency.utf8))
            .toUsageSnapshot()
        #expect(fundedSnap.primary.resetDescription == "Balance: 12.50")

        // Nested summary object paired with breakdown array must not double-count metrics.
        let auggieJSON = """
        {
          "summary": { "total_requests": 5, "total_tokens": 100 },
          "daily": [
            { "total_requests": 3, "total_tokens": 60 },
            { "total_requests": 2, "total_tokens": 40 }
          ]
        }
        """
        let auggieParsed = try AuggieUsageFetcher.parseDailyUsageResponse(Data(auggieJSON.utf8))
        #expect(auggieParsed.requestCount == 5)
        #expect(auggieParsed.totalTokens == 100)
        #expect(auggieParsed.toUsageSnapshot().primary.hasKnownLimit == false)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-factory-session-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let writerStore = FactorySessionStore(fileURL: tempFile)
        await writerStore.setRefreshToken("ref-1")
        // Cold reader must load existing disk state before writing so unrelated keys stay intact.
        let coldStore = FactorySessionStore(fileURL: tempFile)
        await coldStore.setBearerToken("tok-1")
        #expect(await coldStore.getRefreshToken() == "ref-1")
        #expect(await coldStore.getBearerToken() == "tok-1")
        await coldStore.setBearerToken(nil)
        #expect(FileManager.default.fileExists(atPath: tempFile.path))
        await coldStore.setRefreshToken(nil)
        #expect(!FileManager.default.fileExists(atPath: tempFile.path))

        let cursorProbe = CursorStatusProbe()
        let cursorSummary = try JSONDecoder().decode(
            CursorUsageSummary.self,
            from: Data(#"{"isUnlimited":true,"limitType":"unlimited","individualUsage":{"plan":{"limit":1000}}}"#.utf8))
        let cursorSnap = cursorProbe.parseUsageSummary(cursorSummary, userInfo: nil).toUsageSnapshot()
        #expect(cursorSnap.primary.hasKnownLimit == false)

        // M10: Tests never touch real ~/Library/Application Support/Runic/diagnostics.
        let diagDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-sf-diag-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: diagDir) }
        let trace = SiliconFlowConsoleTrace()
        trace.finish(
            china: false,
            isConnect: false,
            failure: "401 unauthorized",
            diagnosticsDirectory: diagDir,
            writeToDisk: true)
        #expect(SiliconFlowConsoleTrace.lastFailure(china: false) != nil)
        #expect(FileManager.default.fileExists(atPath: diagDir.appendingPathComponent("siliconflow-console.json").path))
        SiliconFlowConsoleTrace.clearFailure(china: false)
        #expect(SiliconFlowConsoleTrace.lastFailure(china: false) == nil)
    }
}
