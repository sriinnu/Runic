import Foundation
#if canImport(Security)
import Security
#endif

/// The single choke point for every keychain call Runic makes. Each call checks
/// `RunicKeychainAccessPolicy` first, so a binary that isn't Runic-signed (an
/// ad-hoc `swift build` product, the test bundle) never reaches securityd and
/// never summons the per-item ACL password dialog. Denied calls report
/// `errSecInteractionNotAllowed`, which every caller already treats as
/// "nothing there".
public enum RunicKeychainGate {
    #if canImport(Security)
    public static func copyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard RunicKeychainAccessPolicy.processMayUseKeychain else { return errSecInteractionNotAllowed }
        return SecItemCopyMatching(query, result)
    }

    public static func add(_ attributes: CFDictionary) -> OSStatus {
        guard RunicKeychainAccessPolicy.processMayUseKeychain else { return errSecInteractionNotAllowed }
        return SecItemAdd(attributes, nil)
    }

    public static func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus {
        guard RunicKeychainAccessPolicy.processMayUseKeychain else { return errSecInteractionNotAllowed }
        return SecItemUpdate(query, attributes)
    }

    public static func delete(_ query: CFDictionary) -> OSStatus {
        guard RunicKeychainAccessPolicy.processMayUseKeychain else { return errSecInteractionNotAllowed }
        return SecItemDelete(query)
    }
    #endif
}
