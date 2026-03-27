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
}
