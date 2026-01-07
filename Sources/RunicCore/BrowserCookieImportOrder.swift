#if os(macOS)
import Silo

public typealias BrowserCookieImportOrder = [Browser]

public extension Collection where Element == Browser {
    /// Returns a user-friendly hint about which browsers to log in to.
    var loginHint: String {
        if self.isEmpty {
            return "your browser"
        } else if self.count == 1, let first = self.first {
            return first.displayName
        } else {
            let names = self.map { $0.displayName }
            return names.dropLast().joined(separator: ", ") + " or " + (names.last ?? "")
        }
    }
}
#else
public struct Browser: Sendable, Hashable {
    public init() {}
}

public typealias BrowserCookieImportOrder = [Browser]
#endif
