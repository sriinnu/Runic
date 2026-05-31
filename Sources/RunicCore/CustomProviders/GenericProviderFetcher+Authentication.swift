import Foundation
#if canImport(Security)
import Security
#endif

extension GenericProviderFetcher {
    /// Add authentication headers to the request
    func addAuthHeaders(to request: inout URLRequest) async throws {
        let token = try await self.loadToken()

        switch self.config.auth.type {
        case .apiKey:
            let value = (self.config.auth.headerPrefix ?? "") + token
            request.setValue(value, forHTTPHeaderField: self.config.auth.headerName)

        case .bearer:
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        case .basic:
            let encoded = Data("\(token):".utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")

        case .oauth:
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        case .custom:
            let value = (self.config.auth.headerPrefix ?? "") + token
            request.setValue(value, forHTTPHeaderField: self.config.auth.headerName)
        }

        self.config.auth.additionalHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    /// Load token from keychain or environment
    private func loadToken() async throws -> String {
        if let token = self.keychainToken(account: self.config.auth.tokenKeychain) {
            return token
        }

        let envKey = self.config.auth.tokenKeychain.uppercased().replacingOccurrences(of: "-", with: "_")
        if let token = ProcessInfo.processInfo.environment[envKey] {
            return token.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw FetchError.missingToken(self.config.auth.tokenKeychain)
    }

    /// Read token from keychain
    private func keychainToken(account: String) -> String? {
        #if canImport(Security)
        if self.keychainService == RunicKeychainService.providerCredentials,
           let token = ProviderCredentialKeychainMigration.token(account: account)
        {
            return token
        }

        var result: CFTypeRef?
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        if status == errSecInteractionNotAllowed {
            return nil
        }
        guard status == errSecSuccess else {
            self.log.error("Keychain read failed for \(account): \(status)")
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
        _ = account
        return nil
        #endif
    }

    #if DEBUG
    public func _loadTokenForTesting() async throws -> String {
        try await self.loadToken()
    }
    #endif
}
