import Foundation
import LocalAuthentication
import Security

enum RunicKeychainQuery {
    /// CFString payload behind kSecUseAuthenticationUIFail, without referencing the deprecated symbol.
    private static let authenticationUIFail = "u_AuthUIF"

    static func disallowAuthenticationUI(in query: inout [String: Any]) {
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        query[kSecUseAuthenticationUI as String] = Self.authenticationUIFail as CFString
    }
}
