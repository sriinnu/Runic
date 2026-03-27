import Testing
@testable import RunicCLI
@testable import RunicCore

struct CLIWebFallbackTests {
    private func makeContext(sourceMode: ProviderSourceMode = .auto) -> ProviderFetchContext {
        ProviderFetchContext(
            runtime: .cli,
            sourceMode: sourceMode,
            includeCredits: true,
            webTimeout: 60,
            webDebugDumpHTML: false,
            verbose: false,
            env: [:],
            settings: nil,
            fetcher: UsageFetcher(),
            claudeFetcher: ClaudeUsageFetcher())
    }

    @Test
    func `codex falls back when cookies missing`() {
        let context = self.makeContext()
        let strategy = CodexWebDashboardStrategy()
        #expect(strategy.shouldFallback(
            on: OpenAIDashboardBrowserCookieImporter.ImportError.noCookiesFound,
            context: context))
        #expect(strategy.shouldFallback(
            on: OpenAIDashboardBrowserCookieImporter.ImportError.noMatchingAccount(found: []),
            context: context))
        #expect(strategy.shouldFallback(
            on: OpenAIDashboardBrowserCookieImporter.ImportError.browserAccessDenied(details: "no access"),
            context: context))
        #expect(strategy.shouldFallback(
            on: OpenAIDashboardBrowserCookieImporter.ImportError.dashboardStillRequiresLogin,
            context: context))
        #expect(strategy.shouldFallback(
            on: OpenAIDashboardFetcher.FetchError.loginRequired,
            context: context))
    }

    @Test
    func `codex does not fallback for dashboard data errors`() {
        let context = self.makeContext()
        let strategy = CodexWebDashboardStrategy()
        #expect(!strategy.shouldFallback(
            on: OpenAIDashboardFetcher.FetchError.noDashboardData(body: "missing"),
            context: context))
    }

    @Test
    func `claude falls back when no session key`() {
        let context = self.makeContext()
        let strategy = ClaudeWebFetchStrategy()
        #expect(strategy.shouldFallback(on: ClaudeWebAPIFetcher.FetchError.noSessionKeyFound, context: context))
        #expect(!strategy.shouldFallback(on: ClaudeWebAPIFetcher.FetchError.unauthorized, context: context))
    }
}
