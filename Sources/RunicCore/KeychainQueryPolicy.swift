import Foundation
#if canImport(Security)
import Security
#endif
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

enum RunicCoreKeychainQueryPolicy {
    #if canImport(Security)
    // CFString payloads behind the deprecated kSecUseAuthenticationUI* symbols.
    private static let authenticationUIAllow = "u_AuthUIA"
    private static let authenticationUIFail = "u_AuthUIF"

    static func disallowAuthenticationUI(in query: inout [String: Any]) {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        #endif
        query[kSecUseAuthenticationUI as String] = Self.authenticationUIFail as CFString
    }

    static func setAuthenticationUI(_ allowUserInteraction: Bool, in query: inout [String: Any]) {
        query[kSecUseAuthenticationUI as String] = allowUserInteraction
            ? (self.authenticationUIAllow as CFString)
            : (self.authenticationUIFail as CFString)
        #if canImport(LocalAuthentication)
        let context = LAContext()
        context.interactionNotAllowed = !allowUserInteraction
        query[kSecUseAuthenticationContext as String] = context
        #endif
    }
    #endif
}
