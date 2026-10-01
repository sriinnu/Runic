import ServiceManagement

enum LaunchAtLoginManager {
    @MainActor
    static func isEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    @MainActor
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13, *) else { return false }
        let service = SMAppService.mainApp
        do {
            if enabled, service.status != .enabled {
                try service.register()
            } else if !enabled, service.status == .enabled {
                try service.unregister()
            }
        } catch {
            return false
        }
        return (service.status == .enabled) == enabled
    }

    /// Reset the login-item registration to point at the *current* bundle.
    /// Useful when promoting a dev build to be the canonical install.
    @MainActor
    static func reregister() {
        guard #available(macOS 13, *) else { return }
        let service = SMAppService.mainApp
        try? service.unregister()
        try? service.register()
    }
}
