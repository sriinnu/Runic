import AppKit
import RunicCore
import SwiftUI

@MainActor
enum RunicScreenshotRenderer {
    private static let menuSize = CGSize(width: 392, height: 680)
    private static let preferencesSize = CGSize(width: PreferencesTab.windowWidth, height: PreferencesTab.windowHeight)
    private static var keepAliveWindow: NSWindow?

    static var isRequested: Bool {
        Self.request != nil
    }

    static func startIfRequested(
        store: UsageStore,
        settings: SettingsStore,
        account: AccountInfo,
        updater: UpdaterProviding,
        selection: PreferencesSelection) -> Bool
    {
        guard let request = Self.request else { return false }
        self.installKeepAliveWindow()
        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 600_000_000)
                try self.render(request, store: store, settings: settings, account: account, updater: updater, selection: selection)
                self.keepAliveWindow = nil
                NSApp.terminate(nil)
            } catch {
                fputs("Runic screenshot render failed: \(error.localizedDescription)\n", stderr)
                self.keepAliveWindow = nil
                NSApp.terminate(nil)
            }
        }
        return true
    }

    private static func installKeepAliveWindow() {
        let window = NSWindow(
            contentRect: CGRect(x: -10_000, y: -10_000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        window.orderOut(nil)
        self.keepAliveWindow = window
    }

    private static var request: RenderRequest? {
        guard let raw = ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_RENDER"],
              let separator = raw.firstIndex(of: ":")
        else { return nil }

        let kind = String(raw[..<separator])
        let output = String(raw[raw.index(after: separator)...])
        guard !kind.isEmpty, !output.isEmpty else { return nil }
        return RenderRequest(kind: kind, outputURL: URL(fileURLWithPath: output))
    }

    private static func render(
        _ request: RenderRequest,
        store: UsageStore,
        settings: SettingsStore,
        account: AccountInfo,
        updater: UpdaterProviding,
        selection: PreferencesSelection) throws
    {
        let previousTheme = settings.theme
        if let theme = Self.themeOverride {
            settings.theme = theme
        }
        defer {
            if settings.theme != previousTheme {
                settings.theme = previousTheme
            }
        }

        switch request.kind {
        case "menubar":
            try Self.writePNG(
                MenuPopoverView(
                    store: store,
                    settings: settings,
                    account: account,
                    updateReady: false,
                    initialProvider: store.enabledProviders().first,
                    width: Self.menuSize.width,
                    actions: Self.noopActions,
                    onSelectProvider: { _ in })
                    .environment(\.runicFonts, RunicFontStore.shared),
                size: Self.menuSize,
                to: request.outputURL)
        case "prefs-general":
            selection.tab = .general
            try Self.writePreferences(store: store, settings: settings, updater: updater, selection: selection, to: request.outputURL)
        case "prefs-providers":
            selection.tab = .providers
            try Self.writePreferences(store: store, settings: settings, updater: updater, selection: selection, to: request.outputURL)
        default:
            throw RendererError.unsupportedKind(request.kind)
        }
    }

    private static var themeOverride: Theme? {
        guard let raw = ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_THEME"] else { return nil }
        return Theme(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func writePreferences(
        store: UsageStore,
        settings: SettingsStore,
        updater: UpdaterProviding,
        selection: PreferencesSelection,
        to url: URL) throws
    {
        try Self.writePNG(
            PreferencesView(settings: settings, store: store, updater: updater, selection: selection)
                .environment(\.runicFonts, RunicFontStore.shared),
            size: Self.preferencesSize,
            to: url)
    }

    private static func writePNG<Content: View>(_ view: Content, size: CGSize, to url: URL) throws {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -10_000, y: -10_000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.contentView = hostingView
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        window.orderFrontRegardless()
        window.layoutIfNeeded()
        window.displayIfNeeded()
        hostingView.needsLayout = true
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        window.displayIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw RendererError.bitmapUnavailable
        }
        rep.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw RendererError.pngUnavailable
        }
        try data.write(to: url, options: .atomic)
    }

    private static let noopActions = MenuPopoverActions(
        installUpdate: {},
        refresh: {},
        openDashboard: {},
        openStatusPage: {},
        switchAccount: { _ in },
        exportCSV: { _ in },
        exportJSON: { _ in },
        openSettings: {},
        openAbout: {},
        quit: {},
        copyError: { _ in })
}

private struct RenderRequest {
    let kind: String
    let outputURL: URL
}

private enum RendererError: LocalizedError {
    case bitmapUnavailable
    case pngUnavailable
    case unsupportedKind(String)

    var errorDescription: String? {
        switch self {
        case .bitmapUnavailable:
            "Could not create a bitmap for the rendered view."
        case .pngUnavailable:
            "Could not encode the rendered view as PNG."
        case let .unsupportedKind(kind):
            "Unsupported screenshot render kind: \(kind)."
        }
    }
}
