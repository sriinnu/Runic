import Foundation

extension ProviderTokenResolver {
    static let keychainService = RunicKeychainService.providerCredentials

    static func cleaned(_ raw: String?) -> String? {
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

    static func keychainToken(service: String, account: String) -> String? {
        #if canImport(Security)
        if service == RunicKeychainService.providerCredentials {
            return ProviderCredentialKeychainMigration.token(account: account)
        }
        // Token stores write to the standard keychain, so try it first.
        // Fall back to the Data Protection keychain for pre-migration items.
        if let token = self.keychainRead(service: service, account: account, dataProtection: false) {
            return token
        }
        return self.keychainRead(service: service, account: account, dataProtection: true)
        #else
        _ = service
        _ = account
        return nil
        #endif
    }
}
