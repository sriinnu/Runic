import Foundation
import RunicCore
import Testing

struct ProviderCredentialDiscoveryTests {
    @Test
    func `an exported API key alone resolves a credential for every key-based provider`() {
        let cases: [(UsageProvider, String)] = [
            (.kimi, "KIMI_API_KEY"),
            (.kimiCN, "KIMI_CN_API_KEY"),
            (.qwen, "DASHSCOPE_API_KEY"),
            (.qwenCN, "DASHSCOPE_CN_API_KEY"),
            (.deepseek, "DEEPSEEK_API_KEY"),
            (.stepfun, "STEPFUN_API_KEY"),
            (.zaiCN, "BIGMODEL_API_KEY"),
            (.minimaxCN, "MINIMAXI_API_KEY"),
        ]
        for (provider, variable) in cases {
            let resolution = ProviderTokenResolver.credentialResolution(
                for: provider, environment: [variable: "test-key"], allowKeychain: false)
            #expect(resolution != nil, "\(provider) should resolve from \(variable)")
        }
    }

    @Test
    func `providers without an API-key resolver never claim a credential`() {
        for provider in [UsageProvider.codex, .claude, .gemini, .cursor, .opencode, .localLLM] {
            #expect(ProviderTokenResolver.credentialResolution(
                for: provider, environment: [:], allowKeychain: false) == nil)
        }
    }
}
