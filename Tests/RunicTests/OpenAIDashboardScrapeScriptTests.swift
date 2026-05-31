import Testing
@testable import RunicCore

struct OpenAIDashboardScrapeScriptTests {
    @Test
    func `dashboard scrape script loads decoded javascript resource`() {
        #expect(openAIDashboardScrapeScript.contains("window.__runicUsageBreakdownJSON"))
        #expect(openAIDashboardScrapeScript.contains(#"^\d{4}-\d{2}-\d{2}$"#))
        #expect(openAIDashboardScrapeScript.contains(#"div[style*="background-color"]"#))
    }
}
