import Foundation
import Testing
@testable import RunicCore

struct ProviderFetchPipelineTests {
    private struct SlowStrategy: ProviderFetchStrategy {
        let id: String
        let kind: ProviderFetchKind = .api
        let shouldFallbackValue: Bool

        func isAvailable(_ context: ProviderFetchContext) async -> Bool {
            true
        }

        func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
            while true {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
            self.shouldFallbackValue
        }
    }

    private struct FailingStrategy: ProviderFetchStrategy {
        let id: String = "provider.fetchPipeline.fail"
        let kind: ProviderFetchKind = .api
        let error: Error
        let fallback: Bool

        func isAvailable(_ context: ProviderFetchContext) async -> Bool {
            true
        }

        func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
            throw self.error
        }

        func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
            self.fallback
        }
    }

    private struct FastSuccessStrategy: ProviderFetchStrategy {
        let id: String = "provider.fetchPipeline.success"
        let kind: ProviderFetchKind = .api
        let result: ProviderFetchResult

        func isAvailable(_ context: ProviderFetchContext) async -> Bool {
            true
        }

        func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
            self.result
        }

        func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
            false
        }
    }

    private final class DummyClaudeFetcher: ClaudeUsageFetching, @unchecked Sendable {
        func loadLatestUsage(model: String) async throws -> ClaudeUsageSnapshot {
            throw URLError(.unsupportedURL)
        }

        func debugRawProbe(model: String) async -> String {
            ""
        }

        func detectVersion() -> String? {
            nil
        }
    }

    private func makeContext() -> ProviderFetchContext {
        ProviderFetchContext(
            runtime: .app,
            sourceMode: .auto,
            includeCredits: false,
            webTimeout: 60,
            webDebugDumpHTML: false,
            verbose: false,
            env: [:],
            settings: nil,
            fetcher: UsageFetcher(environment: [:]),
            claudeFetcher: DummyClaudeFetcher())
    }

    @Test
    func `hangs are converted to strategy timeout`() async {
        let pipeline = ProviderFetchPipeline(
            resolveStrategies: { _ in [SlowStrategy(id: "provider.fetchPipeline.hang", shouldFallbackValue: false)] },
            strategyTimeout: 0.05)
        let outcome = await pipeline.fetch(context: self.makeContext(), provider: .kimi)

        #expect(!outcome.attempts.isEmpty)
        #expect(outcome.attempts.count == 1)
        #expect(outcome.attempts[0].strategyID == "provider.fetchPipeline.hang")
        #expect(outcome.attempts[0].wasAvailable == true)

        guard case let .failure(error) = outcome.result else {
            Issue.record("Expected fetch failure")
            return
        }
        guard case let .strategyTimeout(provider, strategyID, timeoutSeconds) = error as? ProviderFetchError else {
            Issue.record("Expected strategy timeout error")
            return
        }
        #expect(provider == .kimi)
        #expect(strategyID == "provider.fetchPipeline.hang")
        #expect(timeoutSeconds == 0.05)
    }

    @Test
    func `strategy fallback still honors order`() async {
        let expected = Self.makeStubResult()
        let pipeline = ProviderFetchPipeline(
            resolveStrategies: { _ in [
                FailingStrategy(error: URLError(.timedOut), fallback: true),
                FastSuccessStrategy(result: expected),
            ] },
            strategyTimeout: 1)

        let outcome = await pipeline.fetch(context: self.makeContext(), provider: .kimi)
        let result = try? outcome.result.get()

        #expect(result?.strategyID == expected.strategyID)
        #expect(result?.strategyKind == expected.strategyKind)
        #expect(result?.sourceLabel == expected.sourceLabel)
        #expect(result?.usage.primary.resetDescription == expected.usage.primary.resetDescription)
        #expect(outcome.attempts.count == 2)
        #expect(outcome.attempts[0].wasAvailable)
        #expect(outcome.attempts[0].errorDescription != nil)
        #expect(outcome.attempts[1].wasAvailable)
        #expect(outcome.attempts[1].errorDescription == nil)
    }

    private static func makeStubResult() -> ProviderFetchResult {
        let usage = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 1,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "test"),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
        return ProviderFetchResult(
            usage: usage,
            credits: nil,
            dashboard: nil,
            sourceLabel: "test",
            strategyID: "provider.fetchPipeline.success",
            strategyKind: .api)
    }
}
