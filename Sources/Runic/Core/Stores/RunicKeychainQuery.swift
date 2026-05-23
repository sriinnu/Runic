import Foundation
import LocalAuthentication
import Security

enum RunicKeychainQuery {
    // CFString payload behind kSecUseAuthenticationUISkip, without referencing the deprecated symbol.
    private static let authenticationUISkip = "u_AuthUIS"

    static func disallowAuthenticationUI(in query: inout [String: Any]) {
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        query[kSecUseAuthenticationUI as String] = Self.authenticationUISkip as CFString
    }
}
