import Foundation
#if canImport(Security)
import Security
#endif
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

public enum ProviderTokenSource: String, Sendable {
    case keychain
    case environment
}

public struct ProviderTokenResolution: Sendable {
    public let token: String
    public let source: ProviderTokenSource

    public init(token: String, source: ProviderTokenSource) {
        self.token = token
        self.source = source
    }
}

public enum ProviderTokenResolver {
    private static let log = RunicLog.logger("provider-token")

    private static let keychainService = "com.sriinnu.athena.Runic"
    private static let zaiAccount = "zai-api-token"
    private static let copilotAccount = "copilot-api-token"
    private static let minimaxAccount = "minimax-api-token"
    private static let minimaxCookieAccount = "minimax-cookie-header"
    private static let minimaxGroupAccount = "minimax-group-id"
    private static let openRouterAccount = "openrouter-api-token"
    private static let groqAccount = "groq-api-token"
    private static let deepSeekAccount = "deepseek-api-token"
    private static let fireworksAccount = "fireworks-api-token"
    private static let mistralAccount = "mistral-api-token"
    private static let perplexityAccount = "perplexity-api-token"
    private static let kimiAccount = "kimi-api-token"
    private static let auggieAccount = "auggie-api-token"
    private static let togetherAccount = "together-api-token"
    private static let cohereAccount = "cohere-api-token"
    private static let xaiAccount = "xai-api-token"
    private static let cerebrasAccount = "cerebras-api-token"
    private static let sambanovaAccount = "sambanova-api-token"
    private static let azureOpenAIAccount = "azure-openai-api-token"

    public static func zaiToken(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.zaiResolution(environment: environment)?.token
    }

    public static func copilotToken(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.copilotResolution(environment: environment)?.token
    }

    public static func minimaxToken(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.minimaxResolution(environment: environment)?.token
    }

    public static func minimaxCookieHeader(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.minimaxCookieHeaderResolution(environment: environment)?.token
    }

    public static func minimaxGroupID(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.minimaxGroupResolution(environment: environment)?.token
    }

    public static func openRouterToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.openRouterResolution(environment: environment)?.token
    }

    public static func groqToken(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.groqResolution(environment: environment)?.token
    }

    public static func deepSeekToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.deepSeekResolution(environment: environment)?.token
    }

    public static func fireworksToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.fireworksResolution(environment: environment)?.token
    }

    public static func mistralToken(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.mistralResolution(environment: environment)?.token
    }

    public static func perplexityToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.perplexityResolution(environment: environment)?.token
    }

    public static func kimiToken(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.kimiResolution(environment: environment)?.token
    }

    public static func auggieToken(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.auggieResolution(environment: environment)?.token
    }

    public static func togetherToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.togetherResolution(environment: environment)?.token
    }

    public static func cohereToken(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.cohereResolution(environment: environment)?.token
    }

    public static func xaiToken(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.xaiResolution(environment: environment)?.token
    }

    public static func cerebrasToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.cerebrasResolution(environment: environment)?.token
    }

    public static func sambaNovaToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.sambaNovaResolution(environment: environment)?.token
    }

    public static func azureOpenAIToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.azureOpenAIResolution(environment: environment)?.token
    }

    public static func zaiResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.zaiAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = ZaiSettingsReader.apiToken(environment: environment) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func copilotResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.copilotAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["COPILOT_API_TOKEN"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func minimaxResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let api = self.minimaxApiKeyResolution(environment: environment) {
            return api
        }
        return self.minimaxCookieHeaderResolution(environment: environment)
    }

    public static func minimaxApiKeyResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.minimaxAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["MINIMAX_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func minimaxCookieHeaderResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.minimaxCookieAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = MiniMaxSettingsReader.cookieHeader(environment: environment) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func minimaxGroupResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.minimaxGroupAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = MiniMaxSettingsReader.groupID(environment: environment) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func openRouterResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.openRouterAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["OPENROUTER_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func groqResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.groqAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["GROQ_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func deepSeekResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.deepSeekAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["DEEPSEEK_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func fireworksResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.fireworksAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["FIREWORKS_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func mistralResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.mistralAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["MISTRAL_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func perplexityResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.perplexityAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["PPLX_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        if let token = self.cleaned(environment["PERPLEXITY_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func kimiResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.kimiAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["KIMI_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        if let token = self.cleaned(environment["MOONSHOT_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func auggieResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.auggieAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["AUGMENT_API_TOKEN"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        if let token = self.cleaned(environment["AUGGIE_API_TOKEN"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func togetherResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.togetherAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["TOGETHER_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func cohereResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.cohereAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["COHERE_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func xaiResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.xaiAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["XAI_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func cerebrasResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.cerebrasAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["CEREBRAS_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func sambaNovaResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.sambanovaAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["SAMBANOVA_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    public static func azureOpenAIResolution(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderTokenResolution?
    {
        if let token = self.keychainToken(service: self.keychainService, account: self.azureOpenAIAccount) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        if let token = self.cleaned(environment["AZURE_OPENAI_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        if let token = self.cleaned(environment["AZURE_AI_API_KEY"]) {
            return ProviderTokenResolution(token: token, source: .environment)
        }
        return nil
    }

    private static func cleaned(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'"))
        {
            value.removeFirst()
            value.removeLast()
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func keychainToken(service: String, account: String) -> String? {
        #if canImport(Security)
        var result: CFTypeRef?
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationUI as String: "kSecUseAuthenticationUIFail" as CFString,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
#if canImport(LocalAuthentication)
        let authContext = LAContext()
        authContext.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = authContext
#endif

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        if status == errSecInteractionNotAllowed {
            return nil
        }
        guard status == errSecSuccess else {
            self.log.error("Keychain read failed: \(status)")
            return nil
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty
        else {
            return nil
        }

        return token
        #else
        _ = service
        _ = account
        return nil
        #endif
    }
}
