import RunicCore
import XCTest
@testable import Runic

final class ProviderContextWindowRegistryTests: XCTestCase {
    func test_koshaExactModelContextOverridesStaticProviderFallback() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let registry = try self.registry(
            manifest: self.manifest(
                timestamp: now,
                providers: [
                    self.providerJSON(id: "openai", timestamp: now),
                ],
                models: [
                    self.modelJSON(id: "gpt-5.5", provider: "openai", contextWindow: 1_000_000, timestamp: now),
                ]),
            fallback: #"{"codex":{"contextK":400}}"#,
            now: now)

        let exact = registry.contextLabel(for: .codex, model: "gpt-5.5")
        XCTAssertEqual(exact?.text, "ctx 1M")
        XCTAssertEqual(exact?.source, .kosha)
        XCTAssertEqual(exact?.isStale, false)

        let providerFallback = registry.contextLabel(for: .codex)
        XCTAssertEqual(providerFallback?.text, "ctx ~400K")
        XCTAssertEqual(providerFallback?.source, .staticFallback)
    }

    func test_koshaProviderContextUsesMaxContextAndMarksStale() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let stale = now.addingTimeInterval(-(25 * 60 * 60))
        let registry = try self.registry(
            manifest: self.manifest(
                timestamp: now,
                providers: [
                    self.providerJSON(id: "google", timestamp: now),
                    self.providerJSON(id: "anthropic", timestamp: stale),
                ],
                models: [
                    self.modelJSON(
                        id: "gemini-flash",
                        provider: "google",
                        contextWindow: 128_000,
                        timestamp: now),
                    self.modelJSON(
                        id: "gemini-pro",
                        provider: "google",
                        contextWindow: 1_000_000,
                        timestamp: now),
                    self.modelJSON(
                        id: "claude-opus-4-6",
                        provider: "anthropic",
                        contextWindow: 1_000_000,
                        timestamp: stale),
                ]),
            fallback: #"{"gemini":{"contextK":1000},"claude":{"contextK":1000}}"#,
            now: now)

        let gemini = registry.contextLabel(for: .gemini)
        XCTAssertEqual(gemini?.text, "ctx <=1M")
        XCTAssertEqual(gemini?.source, .kosha)
        XCTAssertEqual(gemini?.isStale, false)

        let claude = registry.contextLabel(for: .claude, model: "claude-opus-4-6")
        XCTAssertEqual(claude?.text, "ctx 1M (stale)")
        XCTAssertEqual(claude?.source, .kosha)
        XCTAssertEqual(claude?.isStale, true)
    }

    func test_schemaMismatchFallsBackToBundledContextJSON() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let registry = try self.registry(
            manifest: """
            {
              "schemaVersion": 2,
              "discoveredAt": \(self.ms(now)),
              "providers": [],
              "models": []
            }
            """,
            fallback: #"{"deepseek":{"contextK":64},"factory":{"label":"ctx varies"}}"#,
            now: now)

        let deepseek = registry.contextLabel(for: .deepseek)
        XCTAssertEqual(deepseek?.text, "ctx ~64K")
        XCTAssertEqual(deepseek?.source, .staticFallback)

        let factory = registry.contextLabel(for: .factory)
        XCTAssertEqual(factory?.text, "ctx varies")
        XCTAssertEqual(factory?.source, .staticFallback)
    }

    func test_azureUsesKoshaForExactModelButNotProviderWideContext() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let registry = try self.registry(
            manifest: self.manifest(
                timestamp: now,
                providers: [
                    self.providerJSON(id: "openai", timestamp: now),
                ],
                models: [
                    self.modelJSON(id: "gpt-4.1", provider: "openai", contextWindow: 1_000_000, timestamp: now),
                ]),
            fallback: #"{"azure":{"label":"ctx varies"}}"#,
            now: now)

        let exact = registry.contextLabel(for: .azure, model: "gpt-4.1")
        XCTAssertEqual(exact?.text, "ctx 1M")
        XCTAssertEqual(exact?.source, .kosha)

        let providerWide = registry.contextLabel(for: .azure)
        XCTAssertEqual(providerWide?.text, "ctx varies")
        XCTAssertEqual(providerWide?.source, .staticFallback)
    }

    private func registry(
        manifest: String?,
        fallback: String,
        now: Date) throws -> ProviderContextWindowRegistry
    {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-kosha-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let manifestURL = root.appendingPathComponent("registry.json")
        if let manifest {
            try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
        }

        let fallbackURL = root.appendingPathComponent("provider-context-windows.json")
        try fallback.write(to: fallbackURL, atomically: true, encoding: .utf8)

        return ProviderContextWindowRegistry(
            manifestURL: manifestURL,
            fallbackURL: fallbackURL,
            ttl: 24 * 60 * 60,
            reloadInterval: 0,
            nowProvider: { now })
    }

    private func manifest(timestamp: Date, providers: [String], models: [String]) -> String {
        """
        {
          "schemaVersion": 1,
          "discoveredAt": \(self.ms(timestamp)),
          "providers": [
            \(providers.joined(separator: ",\n    "))
          ],
          "models": [
            \(models.joined(separator: ",\n    "))
          ]
        }
        """
    }

    private func providerJSON(id: String, timestamp: Date) -> String {
        """
        {
          "providerId": "\(id)",
          "canonicalProviderId": "\(id)",
          "aliases": [],
          "lastRefreshed": \(self.ms(timestamp))
        }
        """
    }

    private func modelJSON(id: String, provider: String, contextWindow: Int, timestamp: Date) -> String {
        """
        {
          "key": "\(provider):\(id)",
          "modelId": "\(id)",
          "name": "\(id)",
          "providerId": "\(provider)",
          "canonicalProviderId": "\(provider)",
          "mode": "chat",
          "aliases": [],
          "contextWindow": \(contextWindow),
          "discoveredAt": \(self.ms(timestamp))
        }
        """
    }

    private func ms(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }
}
