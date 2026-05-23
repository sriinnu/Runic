import Foundation
import Testing
@testable import RunicCore

struct OTelGenAILedgerAdapterTests {
    @Test
    func `parses flat gen AI payload into ledger entry`() throws {
        let payload = """
        {
          "timestamp": "2026-02-23T12:00:00Z",
          "attributes": {
            "gen_ai.system": "anthropic",
            "gen_ai.request.model": "claude-3-5-sonnet",
            "gen_ai.usage.input_tokens": 120,
            "gen_ai.usage.output_tokens": "80",
            "project.id": "proj-alpha",
            "project.name": "Alpha",
            "gen_ai.conversation.id": "session-1",
            "gen_ai.request.id": "request-1",
            "gen_ai.usage.cost": 0.42
          }
        }
        """
        let options = OTelGenAIIngestionOptions(enabled: true)
        let entries = try OTelGenAILedgerAdapter.parseData(Data(payload.utf8), options: options)

        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.provider == .claude)
        #expect(entry.model == "claude-3-5-sonnet")
        #expect(entry.inputTokens == 120)
        #expect(entry.outputTokens == 80)
        #expect(entry.projectID == "proj-alpha")
        #expect(entry.projectName == "Alpha")
        #expect(entry.sessionID == "session-1")
        #expect(entry.requestID == "request-1")
        #expect(abs((entry.costUSD ?? 0) - 0.42) < 0.000_001)
    }

    @Test
    func `parses OTLP resource spans payload`() throws {
        let payload = """
        {
          "resourceSpans": [
            {
              "resource": {
                "attributes": [
                  { "key": "project.name", "value": { "stringValue": "Telemetry Project" } }
                ]
              },
              "scopeSpans": [
                {
                  "spans": [
                    {
                      "name": "chat.completion",
                      "endTimeUnixNano": "1771828800000000000",
                      "attributes": [
                        { "key": "gen_ai.system", "value": { "stringValue": "openai" } },
                        { "key": "gen_ai.request.model", "value": { "stringValue": "gpt-5" } },
                        { "key": "gen_ai.usage.input_tokens", "value": { "intValue": "200" } },
                        { "key": "gen_ai.usage.output_tokens", "value": { "doubleValue": 50.0 } },
                        { "key": "project.id", "value": { "stringValue": "proj-otlp" } }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """
        let entries = try OTelGenAILedgerAdapter.parseData(
            Data(payload.utf8),
            options: OTelGenAIIngestionOptions(enabled: true))

        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.provider == .codex)
        #expect(entry.model == "gpt-5")
        #expect(entry.inputTokens == 200)
        #expect(entry.outputTokens == 50)
        #expect(entry.projectID == "proj-otlp")
        #expect(entry.projectName == "Telemetry Project")
    }

    @Test
    func `feature flag disables ingestion`() throws {
        let payload = """
        {"attributes":{"gen_ai.system":"openai","gen_ai.request.model":"gpt-5","gen_ai.usage.input_tokens":1}}
        """
        let entries = try OTelGenAILedgerAdapter.parseData(
            Data(payload.utf8),
            options: OTelGenAIIngestionOptions(enabled: false))
        #expect(entries.isEmpty)
    }

    @Test
    func `default provider backfills unknown provider`() throws {
        let payload = """
        {"attributes":{"gen_ai.request.model":"custom-model-v1","gen_ai.usage.input_tokens":9}}
        """
        let entries = try OTelGenAILedgerAdapter.parseData(
            Data(payload.utf8),
            options: OTelGenAIIngestionOptions(enabled: true, defaultProvider: .openrouter))

        #expect(entries.count == 1)
        #expect(entries.first?.provider == .openrouter)
        #expect(entries.first?.model == "custom-model-v1")
    }

    @Test
    func `maps all provider systems from telemetry`() throws {
        let systems: [(String, UsageProvider)] = [
            ("anthropic", .claude),
            ("openai", .codex),
            ("z.ai", .zai),
            ("google-gemini", .gemini),
            ("antigravity", .antigravity),
            ("cursor", .cursor),
            ("factory-ai", .factory),
            ("github-copilot", .copilot),
            ("minimax", .minimax),
            ("openrouter", .openrouter),
            ("vercel-ai-gateway", .vercelai),
            ("groq", .groq),
            ("deepseek", .deepseek),
            ("fireworks-ai", .fireworks),
            ("mistral", .mistral),
            ("perplexity", .perplexity),
            ("moonshot-ai", .kimi),
            ("auggie", .auggie),
            ("together", .together),
            ("cohere", .cohere),
            ("xai", .xai),
            ("cerebras", .cerebras),
            ("sambanova", .sambanova),
            ("azure-openai", .azure),
            ("aws-bedrock", .bedrock),
            ("vertex-ai", .vertexai),
            ("dashscope", .qwen),
            ("ollama", .localLLM),
            ("lm-studio", .localLLM),
        ]

        for (system, provider) in systems {
            let payload = """
            {"attributes":{"gen_ai.system":"\(system)","gen_ai.request.model":"model","gen_ai.usage.input_tokens":1}}
            """
            let entries = try OTelGenAILedgerAdapter.parseData(
                Data(payload.utf8),
                options: OTelGenAIIngestionOptions(enabled: true))
            #expect(entries.first?.provider == provider, "\(system) should map to \(provider.rawValue)")
        }
    }

    @Test
    func `marks compaction entries and aggregates compaction tax`() throws {
        let payload = """
        {"attributes":{
          "gen_ai.system":"anthropic",
          "gen_ai.request.model":"claude-opus-4-7",
          "gen_ai.usage.input_tokens":400,
          "gen_ai.usage.output_tokens":80,
          "gen_ai.query.source":"compact",
          "timestamp":"2026-05-15T12:00:00Z"
        }}
        """

        let entries = try OTelGenAILedgerAdapter.parseData(
            Data(payload.utf8),
            options: OTelGenAIIngestionOptions(enabled: true))

        let entry = try #require(entries.first)
        #expect(entry.provider == .claude)
        #expect(entry.source == .openTelemetry)
        #expect(entry.operationKind == .compaction)
        #expect(entry.isCompaction)
        #expect(entry.tokenProvenance?.source == .openTelemetry)
        #expect(entry.tokenProvenance?.confidence == .providerReported)

        let summaries = UsageLedgerAggregator.compactionSummaries(entries: entries)
        let summary = try #require(summaries.first)
        #expect(summary.provider == .claude)
        #expect(summary.eventCount == 1)
        #expect(summary.totals.totalTokens == 480)
        #expect(summary.totals.tokenProvenance?.source == .openTelemetry)
    }

    @Test
    func `parses vercel ai sdk and ollama style usage fields`() throws {
        let payload = """
        [
          {
            "timestamp": "2026-05-15T12:00:00Z",
            "attributes": {
              "gen_ai.system": "vercel-ai-gateway",
              "ai.usage.promptTokens": 20,
              "ai.usage.completionTokens": 30,
              "ai.usage.costUSD": 0.001
            }
          },
          {
            "timestamp": "2026-05-15T12:01:00Z",
            "attributes": {
              "gen_ai.system": "ollama",
              "model": "llama3.1",
              "prompt_eval_count": 11,
              "eval_count": 7
            }
          }
        ]
        """

        let entries = try OTelGenAILedgerAdapter.parseData(
            Data(payload.utf8),
            options: OTelGenAIIngestionOptions(enabled: true))

        #expect(entries.count == 2)
        #expect(entries[0].provider == .vercelai)
        #expect(entries[0].inputTokens == 20)
        #expect(entries[0].outputTokens == 30)
        #expect(abs((entries[0].costUSD ?? 0) - 0.001) < 0.000_001)
        #expect(entries[1].provider == .localLLM)
        #expect(entries[1].inputTokens == 11)
        #expect(entries[1].outputTokens == 7)
    }

    @Test
    func `collector writes sanitized metric jsonl without prompt content`() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-otel-\(UUID().uuidString)", isDirectory: true)
        let output = directory.appendingPathComponent("ingest.jsonl")
        let sink = OTelGenAIIngestionSink(configuration: OTelGenAICollectorConfiguration(outputFile: output))
        let payload = """
        {
          "timestamp": "2026-05-15T12:00:00Z",
          "attributes": {
            "gen_ai.system": "anthropic",
            "gen_ai.request.model": "claude-opus-4-7",
            "gen_ai.usage.input_tokens": 120,
            "gen_ai.usage.output_tokens": 40,
            "gen_ai.prompt": "secret prompt that must not be persisted",
            "gen_ai.completion": "secret response that must not be persisted"
          }
        }
        """

        let result = try await sink.ingest(Data(payload.utf8))
        let stored = try String(contentsOf: result.outputFile, encoding: .utf8)

        #expect(result.acceptedEntries == 1)
        #expect(stored.contains("secret prompt") == false)
        #expect(stored.contains("secret response") == false)
        #expect(stored.contains("input_tokens"))

        let source = OTelGenAIFileLedgerSource(
            files: [output],
            options: OTelGenAIIngestionOptions(enabled: true))
        let entries = try await source.loadEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.provider == .claude)
        #expect(entries.first?.totalTokens == 160)
    }

    @Test
    func `http ingest handler accepts otlp json requests`() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-http-otel-\(UUID().uuidString)", isDirectory: true)
        let output = directory.appendingPathComponent("ingest.jsonl")
        let sink = OTelGenAIIngestionSink(configuration: OTelGenAICollectorConfiguration(outputFile: output))
        let body = """
        {"attributes":{"gen_ai.system":"openai","gen_ai.request.model":"gpt-5","gen_ai.usage.input_tokens":1}}
        """
        let request = """
        POST /v1/traces HTTP/1.1\r
        Host: 127.0.0.1\r
        Content-Type: application/json\r
        Content-Length: \(Data(body.utf8).count)\r
        \r
        \(body)
        """

        let response = await OTelGenAIHTTPIngestHandler.handle(Data(request.utf8), sink: sink)
        let text = String(data: response, encoding: .utf8) ?? ""

        #expect(text.contains("200 OK"))
        #expect(text.contains(#""accepted":1"#))
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    @Test
    func `http ingest publishes one multiplexed local event`() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-http-events-\(UUID().uuidString)", isDirectory: true)
        let output = directory.appendingPathComponent("ingest.jsonl")
        let sink = OTelGenAIIngestionSink(configuration: OTelGenAICollectorConfiguration(outputFile: output))
        let hub = RunicLocalEventHub()
        let stream = await hub.stream(replayLatest: false)
        var iterator = stream.makeAsyncIterator()
        let body = """
        {"attributes":{"gen_ai.system":"openai","gen_ai.request.model":"gpt-5","gen_ai.usage.input_tokens":1}}
        """
        let request = """
        POST /v1/traces HTTP/1.1\r
        Host: 127.0.0.1\r
        Content-Type: application/json\r
        Content-Length: \(Data(body.utf8).count)\r
        \r
        \(body)
        """

        _ = await OTelGenAIHTTPIngestHandler.handle(Data(request.utf8), sink: sink, eventHub: hub)
        let event = await iterator.next()

        #expect(event?.type == "otel.ingest")
        #expect(event?.payload["accepted_entries"] == "1")
        #expect(event?.payload["output_file"] == output.path)
    }

    @Test
    func `local event hub fans out one publish to multiple subscribers`() async {
        let hub = RunicLocalEventHub()
        let firstStream = await hub.stream(replayLatest: false)
        let secondStream = await hub.stream(replayLatest: false)
        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()
        let event = RunicLocalEvent(id: "event-1", type: "test.event", payload: ["ok": "true"])

        await hub.publish(event)

        #expect(await firstIterator.next() == event)
        #expect(await secondIterator.next() == event)
    }

    @Test
    func `local event hub does not replay latest event by default`() async throws {
        let hub = RunicLocalEventHub()
        let staleEvent = RunicLocalEvent(id: "stale", type: "test.event", payload: ["stale": "true"])
        let freshEvent = RunicLocalEvent(id: "fresh", type: "test.event", payload: ["fresh": "true"])

        await hub.publish(staleEvent)
        let stream = await hub.stream()
        let read = Task {
            var iterator = stream.makeAsyncIterator()
            return await iterator.next()
        }
        try await Task.sleep(for: .milliseconds(20))
        await hub.publish(freshEvent)

        #expect(await read.value == freshEvent)
    }

    @Test
    func `local event hub uses bounded newest buffering`() async {
        let hub = RunicLocalEventHub()
        let stream = await hub.stream(replayLatest: false, bufferingNewest: 1)
        var iterator = stream.makeAsyncIterator()
        let first = RunicLocalEvent(id: "first", type: "test.event", payload: ["index": "1"])
        let second = RunicLocalEvent(id: "second", type: "test.event", payload: ["index": "2"])

        await hub.publish(first)
        await hub.publish(second)

        #expect(await iterator.next() == second)
    }

    @Test
    func `local event hub removes cancelled subscribers`() async throws {
        let hub = RunicLocalEventHub()
        let stream = await hub.stream(replayLatest: false)
        let read = Task {
            var iterator = stream.makeAsyncIterator()
            return await iterator.next()
        }

        try await Task.sleep(for: .milliseconds(20))
        #expect(await hub.subscriberCount == 1)
        read.cancel()
        try await Task.sleep(for: .milliseconds(20))

        #expect(await hub.subscriberCount == 0)
    }

    #if canImport(Network)
    @Test
    func `stream frames support sse and ndjson transports`() throws {
        let event = RunicLocalEvent(id: "event-1", type: "otel.ingest", payload: ["accepted_entries": "2"])
        let sse = try OTelGenAIHTTPCollector.frame(for: event, format: .sse)
        let ndjson = try OTelGenAIHTTPCollector.frame(for: event, format: .ndjson)
        let sseText = String(data: sse, encoding: .utf8) ?? ""
        let ndjsonText = String(data: ndjson, encoding: .utf8) ?? ""

        #expect(sseText.contains("id: event-1"))
        #expect(sseText.contains("event: otel.ingest"))
        #expect(sseText.contains(#""accepted_entries":"2""#))
        #expect(ndjsonText.hasSuffix("\n"))
        #expect(ndjsonText.contains(#""type":"otel.ingest""#))
    }
    #endif
}
