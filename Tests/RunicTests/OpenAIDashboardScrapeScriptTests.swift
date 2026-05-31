import Testing
@testable import RunicCore

struct OpenAIDashboardScrapeScriptTests {
    @Test
    func `dashboard scrape script loads decoded javascript resource`() throws {
        let script = try #require(openAIDashboardScrapeScript)

        #expect(script.contains("window.__runicUsageBreakdownJSON"))
        #expect(script.contains(#"^\d{4}-\d{2}-\d{2}$"#))
        #expect(script.contains(#"div[style*="background-color"]"#))
    }
}
