import Foundation

enum RunicScreenshotMode {
    static let placeholderEmail = "demo@runic.app"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_MODE"] == "1"
    }

    static func sanitize(email: String?) -> String? {
        guard self.isEnabled else { return email }
        guard let email, !email.isEmpty else { return email }
        return self.placeholderEmail
    }
}
