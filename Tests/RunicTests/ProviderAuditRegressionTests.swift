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
    }

    @Test
    func `gemini collects multiple distinct PATH binaries and keeps 4+ models`() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runic-gemini-\(UUID().uuidString)")
        let binA = root.appendingPathComponent("binA")
        let binB = root.appendingPathComponent("binB")
        try fm.createDirectory(at: binA, withIntermediateDirectories: true)
        try fm.createDirectory(at: binB, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let wrapperA = binA.appendingPathComponent("gemini")
        let realB = binB.appendingPathComponent("gemini")
        let symlinkB = binA.appendingPathComponent("gemini-alias")
        try "#!/bin/sh\n".write(to: wrapperA, atomically: true, encoding: .utf8)
        try "#!/bin/sh\n".write(to: realB, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperA.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: realB.path)
        try fm.createSymbolicLink(atPath: symlinkB.path, withDestinationPath: realB.path)

        let candidates = GeminiStatusProbe.collectGeminiBinaryCandidates(
            env: ["PATH": "\(binA.path):\(binB.path):\(binA.path)"],
            loginPATH: [binB.path],
            fileManager: fm,
            home: root.path)
        #expect(candidates.contains(wrapperA.path))
        #expect(candidates.contains(realB.path))
        #expect(candidates.count(where: { $0 == realB.path }) == 1)

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
    }

    @Test
    func `muse parses single window output and handles lossy utf8 safely`() throws {
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
    }

    @Test
    func `ollamacloud extracts request counts when limits lack usage percentages`() throws {
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
        let counterSnap = try OllamaCloudUsage.parse(Data(counterOnlyJSON.utf8)).toUsageSnapshot()
        #expect(counterSnap.primary.hasKnownLimit == false)
        #expect(counterSnap.primary.resetDescription == "17 requests")
    }

    @Test
    func `claude parses fable label and oauth retains both sonnet and opus alongside session/weekly`() throws {
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
          "seven_day_sonnet": { "utilization": 22.0, "resets_at": "2026-12-07T00:00:00Z" }
        }
        """
        let oauth = try ClaudeUsageFetcher._mapOAuthUsageForTesting(
            Data(oauthJSON.utf8),
            rateLimitTier: "default_claude_max_5x")
        #expect(oauth.primary.usedPercent == 15)
        #expect(oauth.secondary?.usedPercent == 40)
        #expect(oauth.opus != nil)
        #expect(oauth.additionalWindows?.isEmpty == false)
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
    func `qwen and zai normalize urls, weeks unit, fractional percents, and CN identities`() throws {
        let url = QwenUsageFetcher.usageURL(baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1")
        #expect(url?.absoluteString == "https://dashscope.aliyuncs.com/api/v1/usage")

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
        let zaiSnap = ZaiUsageSnapshot(
            tokenLimit: entry,
            timeLimit: nil,
            extraLimits: [extraA, extraB],
            planName: "Pro",
            updatedAt: Date()).toUsageSnapshot(providerID: .zaiCN)
        #expect(zaiSnap.tertiary != nil)
        #expect(zaiSnap.additionalWindows?.count == 1)
        #expect(zaiSnap.identity?.providerID == .zaiCN)
    }

    @Test
    func `azure, localLLM, stepfun, deepseek, auggie, factory and siliconflow guards hold`() async throws {
        #expect(
            AzureUsageFetcher.deploymentsURL(
                endpoint: "http://insecure.example.com",
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

        let auggieSnap = AuggieUsageMetrics(requestCount: 5, totalTokens: 100, inputTokens: 60, outputTokens: 40)
            .toUsageSnapshot()
        #expect(auggieSnap.primary.hasKnownLimit == false)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-factory-session-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let store = FactorySessionStore(fileURL: tempFile)
        await store.setBearerToken("tok-1")
        #expect(FileManager.default.fileExists(atPath: tempFile.path))
        await store.clearSession()
        #expect(!FileManager.default.fileExists(atPath: tempFile.path))

        let cursorProbe = CursorStatusProbe()
        let cursorSummary = try JSONDecoder().decode(
            CursorUsageSummary.self,
            from: Data(#"{"limitType":"unlimited","individualUsage":{"plan":{"limit":0}}}"#.utf8))
        let cursorSnap = cursorProbe.parseUsageSummary(cursorSummary, userInfo: nil).toUsageSnapshot()
        #expect(cursorSnap.primary.hasKnownLimit == false)

        let trace = SiliconFlowConsoleTrace()
        trace.finish(china: false, isConnect: false, failure: "401 unauthorized")
        #expect(SiliconFlowConsoleTrace.lastFailure(china: false) != nil)
        SiliconFlowConsoleTrace.clearFailure(china: false)
        #expect(SiliconFlowConsoleTrace.lastFailure(china: false) == nil)
    }
}
