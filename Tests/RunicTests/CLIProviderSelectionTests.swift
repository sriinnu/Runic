import RunicCore
import Foundation
import Testing
@testable import RunicCLI

@Suite
struct CLIProviderSelectionTests {
    @Test
    func helpIncludesGeminiAndAll() {
        let usage = RunicCLI.usageHelp(version: "0.0.0")
        let root = RunicCLI.rootHelp(version: "0.0.0")
        let expectedProviders = [
            "--provider codex|",
            "|claude|",
            "|factory|",
            "|zai|",
            "|cursor|",
            "|gemini|",
            "|antigravity|",
            "|copilot|",
            "|both|",
            "|all]",
        ]
        for provider in expectedProviders {
            #expect(usage.contains(provider))
            #expect(root.contains(provider))
        }
        #expect(usage.contains("--json"))
        #expect(root.contains("--json"))
        #expect(usage.contains("--json-output"))
        #expect(root.contains("--json-output"))
        #expect(usage.contains("--log-level"))
        #expect(root.contains("--log-level"))
        #expect(usage.contains("--verbose"))
        #expect(root.contains("--verbose"))
        #expect(usage.contains("runic usage --provider gemini"))
        #expect(usage.contains("runic usage --format json --provider all --pretty"))
        #expect(root.contains("runic --provider gemini"))
    }

    @Test
    func helpMentionsSourceFlag() {
        let usage = RunicCLI.usageHelp(version: "0.0.0")
        let root = RunicCLI.rootHelp(version: "0.0.0")

        func tokens(_ text: String) -> [String] {
            let split = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "[]|,"))
            return text.components(separatedBy: split).filter { !$0.isEmpty }
        }

        #expect(usage.contains("--source"))
        #expect(root.contains("--source"))
        #expect(usage.contains("--web-timeout"))
        #expect(usage.contains("--web-debug-dump-html"))
        #expect(!tokens(usage).contains("--web"))
        #expect(!tokens(root).contains("--web"))
        #expect(!tokens(usage).contains("--claude-source"))
        #expect(!tokens(root).contains("--claude-source"))
    }

    @Test
    func providerSelectionRespectsOverride() {
        let selection = RunicCLI.providerSelection(rawOverride: "gemini", enabled: [.codex, .claude])
        #expect(selection.asList == [.gemini])
    }

    @Test
    func providerSelectionUsesAllWhenEnabled() {
        let selection = RunicCLI.providerSelection(
            rawOverride: nil,
            enabled: [.codex, .claude, .zai, .cursor, .gemini, .antigravity, .factory, .copilot])
        #expect(selection.asList == ProviderSelection.all.asList)
    }

    @Test
    func providerSelectionUsesBothForCodexAndClaude() {
        let selection = RunicCLI.providerSelection(rawOverride: nil, enabled: [.codex, .claude])
        #expect(selection.asList == [.codex, .claude])
    }

    @Test
    func providerSelectionUsesCustomForCodexAndGemini() {
        let enabled: [UsageProvider] = [.codex, .gemini]
        let selection = RunicCLI.providerSelection(rawOverride: nil, enabled: enabled)
        #expect(selection.asList == enabled)
    }

    @Test
    func providerSelectionDefaultsToCodexWhenEmpty() {
        let selection = RunicCLI.providerSelection(rawOverride: nil, enabled: [])
        #expect(selection.asList == [.codex])
    }
}
