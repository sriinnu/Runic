#if os(macOS)
import Silo

public typealias BrowserCookieImportOrder = [Browser]

extension Collection<Browser> {
    /// Returns a user-friendly hint about which browsers to log in to.
    public var loginHint: String {
        if self.isEmpty {
            return "your browser"
        } else if self.count == 1, let first = self.first {
            return first.displayName
        } else {
            let names = self.map(\.displayName)
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
