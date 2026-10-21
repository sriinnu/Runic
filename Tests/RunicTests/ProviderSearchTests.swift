import RunicCore
import Testing

struct ProviderSearchTests {
    @Test
    func `empty query matches every provider`() {
        #expect(UsageProvider.allCases.allSatisfy { $0.matchesSearch("  ") })
    }

    @Test
    func `matches display name ignoring case and punctuation`() {
        #expect(UsageProvider.zai.matchesSearch("ZAI"))
        #expect(UsageProvider.openrouter.matchesSearch("open router"))
        #expect(!UsageProvider.claude.matchesSearch("groq"))
    }

    @Test
    func `matches cli names and aliases`() {
        #expect(UsageProvider.ollamacloud.matchesSearch("ollama-cloud"))
        #expect(UsageProvider.siliconflow.matchesSearch("sf"))
    }

    @Test
    func `china words find brands with a china slot only`() {
        #expect(UsageProvider.kimi.matchesSearch("kimi cn"))
        #expect(UsageProvider.siliconflow.matchesSearch("china"))
        #expect(!UsageProvider.claude.matchesSearch("china"))
    }

    @Test
    func `every word must match`() {
        #expect(!UsageProvider.kimi.matchesSearch("kimi groq"))
    }
}
