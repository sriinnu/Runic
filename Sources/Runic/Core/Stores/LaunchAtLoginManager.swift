import ServiceManagement

enum LaunchAtLoginManager {
    @MainActor
    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13, *) else { return }
        let service = SMAppService.mainApp
        if enabled {
            // SMAppService keys login items by *file path*, not bundle id, so
            // calling register() from a different copy of Runic.app silently
            // adds a second login item alongside the first. Skip if we're
            // already enabled — the existing registration is fine, even if it
            // points to a different bundle path (the user can fix that from
            // System Settings > Login Items).
            if service.status == .enabled { return }
            try? service.register()
        } else {
            if service.status != .enabled { return }
            try? service.unregister()
        }
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
