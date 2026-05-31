import Foundation
import Testing
@testable import RunicCore

struct CostUsageScannerTests {
    @Test
    func `codex daily report parses token counts and caches`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }

        let day = try env.makeLocalNoon(year: 2025, month: 12, day: 20)
        let iso0 = env.isoString(for: day)
        let iso1 = env.isoString(for: day.addingTimeInterval(1))
        let iso2 = env.isoString(for: day.addingTimeInterval(2))

        let model = "openai/gpt-5.2-codex"
        let turnContext: [String: Any] = [
            "type": "turn_context",
            "timestamp": iso0,
            "payload": [
                "model": model,
            ],
        ]
        let firstTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso1,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 100,
                        "cached_input_tokens": 20,
                        "output_tokens": 10,
                    ],
                    "model": model,
                ],
            ],
        ]

        let fileURL = try env.writeCodexSessionFile(
            day: day,
            filename: "session.jsonl",
            contents: env.jsonl([turnContext, firstTokenCount]))

        var options = CostUsageScanner.Options(
            codexSessionsRoot: env.codexSessionsRoot,
            claudeProjectsRoots: nil,
            cacheRoot: env.cacheRoot)
        options.refreshMinIntervalSeconds = 0

        let first = CostUsageScanner.loadDailyReport(
            provider: .codex,
            since: day,
            until: day,
            now: day,
            options: options)
        #expect(first.data.count == 1)
        #expect(first.data[0].modelsUsed == ["gpt-5.2"])
        #expect(first.data[0].totalTokens == 110)
        #expect((first.data[0].costUSD ?? 0) > 0)

        let secondTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso2,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 160,
                        "cached_input_tokens": 40,
                        "output_tokens": 16,
                    ],
                    "model": model,
                ],
            ],
        ]
        try env.jsonl([turnContext, firstTokenCount, secondTokenCount])
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let second = CostUsageScanner.loadDailyReport(
            provider: .codex,
            since: day,
            until: day,
            now: day,
            options: options)
        #expect(second.data.count == 1)
        #expect(second.data[0].totalTokens == 176)
        #expect((second.data[0].costUSD ?? 0) > (first.data[0].costUSD ?? 0))
    }

    @Test
    func `codex incremental parsing uses previous totals`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }

        let day = try env.makeLocalNoon(year: 2025, month: 12, day: 20)
        let iso0 = env.isoString(for: day)
        let iso1 = env.isoString(for: day.addingTimeInterval(1))
        let iso2 = env.isoString(for: day.addingTimeInterval(2))

        let model = "openai/gpt-5.2-codex"
        let normalized = CostUsagePricing.normalizeCodexModel(model)
        let turnContext: [String: Any] = [
            "type": "turn_context",
            "timestamp": iso0,
            "payload": [
                "model": model,
            ],
        ]
        let firstTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso1,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 100,
                        "cached_input_tokens": 20,
                        "output_tokens": 10,
                    ],
                    "model": model,
                ],
            ],
        ]

        let fileURL = try env.writeCodexSessionFile(
            day: day,
            filename: "session.jsonl",
            contents: env.jsonl([turnContext, firstTokenCount]))

        let range = CostUsageScanner.CostUsageDayRange(since: day, until: day)
        let first = CostUsageScanner.parseCodexFile(fileURL: fileURL, range: range)
        #expect(first.parsedBytes > 0)
        #expect(first.lastTotals?.input == 100)
        #expect(first.lastTotals?.cached == 20)
        #expect(first.lastTotals?.output == 10)

        let secondTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso2,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 160,
                        "cached_input_tokens": 40,
                        "output_tokens": 16,
                    ],
                    "model": model,
                ],
            ],
        ]
        try env.jsonl([turnContext, firstTokenCount, secondTokenCount])
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let delta = CostUsageScanner.parseCodexFile(
            fileURL: fileURL,
            range: range,
            startOffset: first.parsedBytes,
            initialModel: first.lastModel,
            initialTotals: first.lastTotals)
        let dayKey = CostUsageScanner.CostUsageDayRange.dayKey(from: day)
        let packed = delta.days[dayKey]?[normalized] ?? []
        #expect(packed.count >= 3)
        #expect(packed[0] == 60)
        #expect(packed[1] == 20)
        #expect(packed[2] == 6)
    }

    @Test
    func `codex incremental parsing counts cumulative token reset as fresh epoch`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }

        let day = try env.makeLocalNoon(year: 2025, month: 12, day: 20)
        let iso0 = env.isoString(for: day)
        let iso1 = env.isoString(for: day.addingTimeInterval(1))
        let iso2 = env.isoString(for: day.addingTimeInterval(2))

        let model = "openai/gpt-5.2-codex"
        let normalized = CostUsagePricing.normalizeCodexModel(model)
        let turnContext: [String: Any] = [
            "type": "turn_context",
            "timestamp": iso0,
            "payload": [
                "model": model,
            ],
        ]
        let firstTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso1,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 300,
                        "cached_input_tokens": 50,
                        "output_tokens": 40,
                    ],
                    "model": model,
                ],
            ],
        ]

        let fileURL = try env.writeCodexSessionFile(
            day: day,
            filename: "reset-session.jsonl",
            contents: env.jsonl([turnContext, firstTokenCount]))

        let range = CostUsageScanner.CostUsageDayRange(since: day, until: day)
        let first = CostUsageScanner.parseCodexFile(fileURL: fileURL, range: range)
        #expect(first.parsedBytes > 0)
        #expect(first.lastTotals?.input == 300)
        #expect(first.lastTotals?.cached == 50)
        #expect(first.lastTotals?.output == 40)

        let resetTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso2,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 80,
                        "cached_input_tokens": 10,
                        "output_tokens": 12,
                    ],
                    "model": model,
                ],
            ],
        ]
        try env.jsonl([turnContext, firstTokenCount, resetTokenCount])
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let delta = CostUsageScanner.parseCodexFile(
            fileURL: fileURL,
            range: range,
            startOffset: first.parsedBytes,
            initialModel: first.lastModel,
            initialTotals: first.lastTotals)
        let dayKey = CostUsageScanner.CostUsageDayRange.dayKey(from: day)
        let packed = delta.days[dayKey]?[normalized] ?? []
        #expect(packed.count >= 3)
        #expect(packed[0] == 80)
        #expect(packed[1] == 10)
        #expect(packed[2] == 12)
    }

    @Test
    func `codex incremental parsing handles partial cumulative counter regression per field`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }

        let day = try env.makeLocalNoon(year: 2025, month: 12, day: 20)
        let iso0 = env.isoString(for: day)
        let iso1 = env.isoString(for: day.addingTimeInterval(1))
        let iso2 = env.isoString(for: day.addingTimeInterval(2))

        let model = "openai/gpt-5.2-codex"
        let normalized = CostUsagePricing.normalizeCodexModel(model)
        let turnContext: [String: Any] = [
            "type": "turn_context",
            "timestamp": iso0,
            "payload": [
                "model": model,
            ],
        ]
        let firstTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso1,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 300,
                        "cached_input_tokens": 50,
                        "output_tokens": 40,
                    ],
                    "model": model,
                ],
            ],
        ]

        let fileURL = try env.writeCodexSessionFile(
            day: day,
            filename: "partial-regression-session.jsonl",
            contents: env.jsonl([turnContext, firstTokenCount]))

        let range = CostUsageScanner.CostUsageDayRange(since: day, until: day)
        let first = CostUsageScanner.parseCodexFile(fileURL: fileURL, range: range)
        #expect(first.parsedBytes > 0)

        let partialRegressionTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso2,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 330,
                        "cached_input_tokens": 10,
                        "output_tokens": 45,
                    ],
                    "model": model,
                ],
            ],
        ]
        try env.jsonl([turnContext, firstTokenCount, partialRegressionTokenCount])
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let delta = CostUsageScanner.parseCodexFile(
            fileURL: fileURL,
            range: range,
            startOffset: first.parsedBytes,
            initialModel: first.lastModel,
            initialTotals: first.lastTotals)
        let dayKey = CostUsageScanner.CostUsageDayRange.dayKey(from: day)
        let packed = delta.days[dayKey]?[normalized] ?? []
        #expect(packed.count >= 3)
        #expect(packed[0] == 30)
        #expect(packed[1] == 10)
        #expect(packed[2] == 5)
    }

    @Test
    func `day key from timestamp matches ISO parsing`() {
        let timestamps = [
            "2025-12-20T23:59:59Z",
            "2025-12-20T23:59:59+02:00",
        ]

        for ts in timestamps {
            let expected = CostUsageScanner.dayKeyFromParsedISO(ts)
            let fast = CostUsageScanner.dayKeyFromTimestamp(ts)
            #expect(fast == expected)
        }
    }
}
