import RunicCore
import Testing

struct CLIProviderSelectionTests {
    @Test
    func `provider registry includes core providers`() {
        let providers = Set(ProviderDescriptorRegistry.all.map(\.id))

        #expect(providers.contains(.codex))
        #expect(providers.contains(.claude))
        #expect(providers.contains(.gemini))
        #expect(providers.contains(.cursor))
        #expect(providers.contains(.factory))
        #expect(providers.contains(.localLLM))
    }

    @Test
    func `provider enum resolves insights supported values`() {
        #expect(UsageProvider(rawValue: "codex") == .codex)
        #expect(UsageProvider(rawValue: "claude") == .claude)
        #expect(UsageProvider(rawValue: "local-llm") == .localLLM)
    }
}
