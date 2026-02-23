import Testing
@testable import RunicCore

@Suite
struct CopilotTokenResolverTests {
    @Test
    func copilotTokenPrefersCopilotApiEnvironmentVariable() {
        let env = [
            "COPILOT_API_TOKEN": "copilot-env-token",
            "GITHUB_TOKEN": "github-token",
            "GH_TOKEN": "gh-fallback-token",
        ]
        let resolution = ProviderTokenResolver.copilotResolution(environment: env)
        #expect(resolution?.token == "copilot-env-token")
        #expect(resolution?.source == .environment)
    }

    @Test
    func copilotTokenFallsBackToGithubToken() {
        let env = [
            "GITHUB_TOKEN": "github-token",
            "GH_TOKEN": "gh-fallback-token",
        ]
        let resolution = ProviderTokenResolver.copilotResolution(environment: env)
        #expect(resolution?.token == "github-token")
    }

    @Test
    func copilotTokenFallsBackToGhToken() {
        let env = [
            "GH_TOKEN": "gh-fallback-token",
            "GITHUB_TOKEN": "",
        ]
        let resolution = ProviderTokenResolver.copilotResolution(environment: env)
        #expect(resolution?.token == "gh-fallback-token")
    }

    @Test
    func copilotTokenStripsQuotedValues() {
        let env = [
            "COPILOT_API_TOKEN": "\"quoted-token\"",
        ]
        let token = ProviderTokenResolver.copilotToken(environment: env)
        #expect(token == "quoted-token")
    }
}

