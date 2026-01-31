import Foundation
#if canImport(Security)
import Security
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
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
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
