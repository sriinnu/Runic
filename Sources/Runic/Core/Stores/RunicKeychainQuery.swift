import Foundation
import LocalAuthentication
import Security

enum RunicKeychainQuery {
    static func disallowAuthenticationUI(in query: inout [String: Any]) {
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
    }
}
