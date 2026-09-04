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

    /// When false, every resolver behaves as if the Keychain were empty and only
    /// environment variables are consulted. Startup discovery runs this way: it
    /// probes ~25 accounts in a row, and an unattended Keychain read can block on
    /// an ACL prompt (seen from the test bundle, which isn't signed as the app).
    @TaskLocal static var keychainReadsAllowed = true

    static func keychainToken(service: String, account: String) -> String? {
        guard self.keychainReadsAllowed, RunicKeychainAccessPolicy.processMayUseKeychain else { return nil }
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
