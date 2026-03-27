import Foundation
import Testing
@testable import RunicCore

struct CopilotTokenResolverTests {
    @Test
    func `copilot token prefers copilot api environment variable`() {
        let env = [
            "COPILOT_API_TOKEN": "copilot-env-token",
            "GITHUB_TOKEN": "github-token",
            "GH_TOKEN": "gh-fallback-token",
        ]
        let resolution = ProviderTokenResolver.copilotResolution(environment: env)
        #expect(resolution?.token == "copilot-env-token")
        #expect(resolution?.source == .environment)
        #expect(resolution?.sourceKey == "COPILOT_API_TOKEN")
    }

    @Test
    func `copilot token falls back to github token`() {
        let env = [
            "GITHUB_TOKEN": "github-token",
            "GH_TOKEN": "gh-fallback-token",
        ]
        let resolution = ProviderTokenResolver.copilotResolution(environment: env)
        #expect(resolution?.token == "github-token")
        #expect(resolution?.sourceKey == "GITHUB_TOKEN")
    }

    @Test
    func `copilot token falls back to gh token`() {
        let env = [
            "GH_TOKEN": "gh-fallback-token",
            "GITHUB_TOKEN": "",
        ]
        let resolution = ProviderTokenResolver.copilotResolution(environment: env)
        #expect(resolution?.token == "gh-fallback-token")
        #expect(resolution?.sourceKey == "GH_TOKEN")
    }

    @Test
    func `copilot token falls back to github CLI token`() throws {
        let token = "gho_abcdefghijklmnopqrstuvwxyz1234"
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-copilot-gh-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let hostsFile = tempDir.appendingPathComponent("hosts.yml")
        let hostsContent = """
        github.com:
          oauth_token: \(token)
        """
        try hostsContent.write(to: hostsFile, atomically: true, encoding: .utf8)

        let env = [
            "GH_CONFIG_DIR": tempDir.path,
            "GH_TOKEN": "",
        ]
        let resolution = ProviderTokenResolver.copilotResolution(environment: env)
        #expect(resolution?.token == token)
        #expect(resolution?.source == .environment)
        #expect(resolution?.sourceKey == "gh-cli")
    }

    @Test
    func `copilot token strips quoted values`() {
        let env = [
            "COPILOT_API_TOKEN": "\"quoted-token\"",
        ]
        let token = ProviderTokenResolver.copilotToken(environment: env)
        #expect(token == "quoted-token")
    }
}
