import Foundation

public enum RunicKeychainService {
    public static let legacyProviderCredentials = "com.sriinnu.athena.Runic"
    /// Provider credentials live away from legacy ACL-bound items that can prompt after app rebuilds.
    public static let providerCredentials = "com.sriinnu.athena.Runic.provider-credentials.v2"
}
