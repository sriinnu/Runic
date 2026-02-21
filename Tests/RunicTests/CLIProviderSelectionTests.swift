import RunicCore
import Testing

@Suite
struct CLIProviderSelectionTests {
    @Test
    func providerRegistryIncludesCoreProviders() {
        let providers = Set(ProviderDescriptorRegistry.all.map(\.id))

        #expect(providers.contains(.codex))
        #expect(providers.contains(.claude))
        #expect(providers.contains(.gemini))
        #expect(providers.contains(.cursor))
        #expect(providers.contains(.factory))
    }

    @Test
    func providerEnumResolvesInsightsSupportedValues() {
        #expect(UsageProvider(rawValue: "codex") == .codex)
        #expect(UsageProvider(rawValue: "claude") == .claude)
    }
}
