import AppKit
import RunicCore
import SwiftUI

@MainActor
enum RunicScreenshotRenderer {
    private static let menuSize = CGSize(width: 392, height: Self.heightOverride ?? 680)
    private static let preferencesSize = CGSize(
        width: PreferencesTab.windowWidth,
        height: Self.heightOverride ?? PreferencesTab.windowHeight)

    /// `RUNIC_SCREENSHOT_HEIGHT` renders a taller canvas so scrolling panes (the
    /// Providers list) can be captured in full for review.
    private static var heightOverride: CGFloat? {
        guard let raw = ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_HEIGHT"],
              let value = Double(raw), value > 0 else { return nil }
        return CGFloat(value)
    }

    /// `RUNIC_SCREENSHOT_PROVIDERS_LAYOUT=sidebar|list` picks the Providers pane
    /// layout for the render without persisting a change to the user's setting.
    private static var providersLayoutOverride: Bool? {
        switch ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_PROVIDERS_LAYOUT"]?.lowercased() {
        case "sidebar": true
        case "list": false
        default: nil
        }
    }

    private static var keepAliveWindow: NSWindow?

    private struct RenderContext {
        let store: UsageStore
        let settings: SettingsStore
        let account: AccountInfo
        let updater: UpdaterProviding
        let selection: PreferencesSelection
    }

    static var isRequested: Bool {
        request != nil
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
        // The stored theme is the user's; every exit path below puts the raw
        // value back and flushes, so a render can never leave it flipped.
        let storedTheme = UserDefaults.standard.string(forKey: "theme")
        defer {
            if let storedTheme {
                UserDefaults.standard.set(storedTheme, forKey: "theme")
            } else {
                UserDefaults.standard.removeObject(forKey: "theme")
            }
            UserDefaults.standard.synchronize()
        }
        Task { @MainActor in
            defer {
                if let storedTheme {
                    UserDefaults.standard.set(storedTheme, forKey: "theme")
                } else {
                    UserDefaults.standard.removeObject(forKey: "theme")
                }
                UserDefaults.standard.synchronize()
            }
            do {
                try await Task.sleep(nanoseconds: 600_000_000)
                let context = RenderContext(
                    store: store,
                    settings: settings,
                    account: account,
                    updater: updater,
                    selection: selection)
                try self.render(request, context: context)
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
            contentRect: CGRect(x: -10000, y: -10000, width: 1, height: 1),
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
        context: RenderContext) throws
    {
        let store = context.store
        let settings = context.settings
        let account = context.account
        let updater = context.updater
        let selection = context.selection
        // In-memory only: the stored preference is never touched, so a batch
        // of renders can't race each other's restore.
        if let theme = Self.themeOverride {
            settings.previewTheme(theme)
        }
        if Self.wantsDemoData {
            Self.seedDemoSnapshots(into: store)
        }
        let previousSidebar = settings.providersPaneSidebar
        if let sidebar = Self.providersLayoutOverride {
            settings.providersPaneSidebar = sidebar
        }
        defer {
            if settings.providersPaneSidebar != previousSidebar {
                settings.providersPaneSidebar = previousSidebar
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
                    initialProvider: Self.menuProviderOverride ?? store.enabledProviders().first,
                    initialPanel: ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_PANEL"]
                        .flatMap(PopoverInsightPanel.init(rawValue:)),
                    width: Self.menuSize.width,
                    height: Self.menuSize.height,
                    actions: Self.noopActions,
                    onSelectProvider: { _ in })
                    .environment(\.runicFonts, RunicFontStore.shared),
                size: Self.menuSize,
                to: request.outputURL)
        case "prefs-general":
            selection.tab = .general
            try Self.writePreferences(
                store: store,
                settings: settings,
                updater: updater,
                selection: selection,
                to: request.outputURL)
        case "prefs-providers":
            selection.tab = .providers
            // RUNIC_SCREENSHOT_SIDEBAR_PROVIDER=<rawValue> focuses that brand in
            // sidebar layout (a China slot also flips the region switch).
            selection.provider = ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_SIDEBAR_PROVIDER"]
                .flatMap(UsageProvider.init(rawValue:))
            try Self.writePreferences(
                store: store,
                settings: settings,
                updater: updater,
                selection: selection,
                to: request.outputURL)
        default:
            throw RendererError.unsupportedKind(request.kind)
        }
    }

    /// `RUNIC_SCREENSHOT_MENU_PROVIDER=<rawValue>|overview` picks the menu card
    /// to render; default is the first enabled provider.
    private static var menuProviderOverride: UsageProvider?? {
        guard let raw = ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_MENU_PROVIDER"] else { return nil }
        if raw.lowercased() == "overview" { return .some(nil) }
        return UsageProvider(rawValue: raw).map { .some($0) }
    }

    /// `RUNIC_SCREENSHOT_DEMO=1` seeds representative quota windows for the
    /// enabled providers so review renders show gauges, reset countdowns and
    /// the Resets panel. The screenshot process never fetches, so without
    /// this every card renders empty. Nothing is persisted — the seeded
    /// snapshots live only in this throwaway process.
    private static var wantsDemoData: Bool {
        ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_DEMO"] == "1"
    }

    private static func seedDemoSnapshots(into store: UsageStore) {
        let now = Date()
        let providers = store.enabledProviders()
        // Never let a render write quota history into the real support dir.
        QuotaSampleStore.shared.memoryOnly = true
        // A spread of shapes: healthy session + weekly, an exhausted session
        // about to flip, a model-labelled window from a phrase, a plain
        // balance (no reset — must stay out of the Resets panel).
        struct DemoShape {
            let used: Double
            let resetsIn: TimeInterval
            let windowMinutes: Int?
            let weeklyUsed: Double?
            let weeklyResetsIn: TimeInterval?
        }
        let shapes: [DemoShape] = [
            DemoShape(
                used: 62,
                resetsIn: 2 * 3600 + 14 * 60,
                windowMinutes: 300,
                weeklyUsed: 20,
                weeklyResetsIn: 3 * 86400 + 5 * 3600),
            DemoShape(used: 100, resetsIn: 18 * 60, windowMinutes: 300, weeklyUsed: 48, weeklyResetsIn: 5 * 86400),
            DemoShape(used: 35, resetsIn: 5 * 3600, windowMinutes: 300, weeklyUsed: nil, weeklyResetsIn: nil),
            DemoShape(used: 12, resetsIn: 26 * 3600, windowMinutes: 1440, weeklyUsed: 71, weeklyResetsIn: 12 * 86400),
        ]
        for (index, provider) in providers.enumerated() {
            let shape = shapes[index % shapes.count]
            let primary = RateWindow(
                usedPercent: shape.used,
                windowMinutes: shape.windowMinutes,
                resetsAt: now.addingTimeInterval(shape.resetsIn),
                resetDescription: nil)
            let secondary: RateWindow? = shape.weeklyUsed.map { used in
                RateWindow(
                    usedPercent: used,
                    windowMinutes: 10080,
                    resetsAt: now.addingTimeInterval(shape.weeklyResetsIn ?? 7 * 86400),
                    resetDescription: nil)
            }
            let banked: UsageResetCredits? = index % shapes.count == 1
                ? UsageResetCredits(
                    availableCount: 2,
                    credits: [
                        UsageResetCredit(
                            id: "demo-1",
                            title: "Full reset",
                            status: "available",
                            grantedAt: now.addingTimeInterval(-5 * 86400),
                            expiresAt: now.addingTimeInterval(25 * 86400)),
                        UsageResetCredit(
                            id: "demo-2",
                            title: "Full reset",
                            status: "available",
                            grantedAt: now.addingTimeInterval(-4 * 86400),
                            expiresAt: now.addingTimeInterval(26 * 86400)),
                    ])
                : nil
            let snapshot = UsageSnapshot(
                primary: primary,
                secondary: secondary,
                tertiary: nil,
                resetCredits: banked,
                updatedAt: now.addingTimeInterval(-240),
                identity: nil)
            store.snapshots[provider] = snapshot
            Self.seedDemoBurnHistory(provider: provider, snapshot: snapshot, now: now)
        }
    }

    /// A believable cycle for the Burn panel: quiet, a burst, quiet again,
    /// ending exactly at the live reading so the curve meets the dot.
    private static func seedDemoBurnHistory(provider: UsageProvider, snapshot: UsageSnapshot, now: Date) {
        let store = QuotaSampleStore.shared
        store.clear(provider: provider)
        for slot in QuotaWindowSlot.allCases {
            guard let window = slot.window(in: snapshot), let resetsAt = window.resetsAt,
                  let minutes = window.windowMinutes else { continue }
            let duration = TimeInterval(minutes) * 60
            let start = resetsAt.addingTimeInterval(-duration)
            let elapsed = now.timeIntervalSince(start)
            guard elapsed > 0 else { continue }
            let steps = 40
            for step in 0...steps {
                let fraction = Double(step) / Double(steps)
                let at = start.addingTimeInterval(elapsed * fraction)
                // Ease: slow start, burst around 55–70% of elapsed time, plateau.
                let shape: Double = fraction < 0.55
                    ? fraction * 0.45
                    : (fraction < 0.72 ? 0.25 + (fraction - 0.55) * 3.5 : 0.85 + (fraction - 0.72) * 0.5)
                let used = min(window.usedPercent, window.usedPercent * shape)
                store.record(
                    provider: provider,
                    slot: slot,
                    sample: QuotaSample(at: at, usedPercent: used, resetsAt: resetsAt, windowMinutes: minutes))
            }
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
        try self.writePNG(
            PreferencesView(settings: settings, store: store, updater: updater, selection: selection)
                .environment(\.runicFonts, RunicFontStore.shared),
            size: self.preferencesSize,
            to: url)
    }

    private static func writePNG(_ view: some View, size: CGSize, to url: URL) throws {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -10000, y: -10000), size: size),
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
        // The rep's logical size must match the bounds that were laid out,
        // not the requested canvas: a taller `RUNIC_SCREENSHOT_HEIGHT` than
        // the content once produced a non-uniformly scaled PNG whose text
        // looked letter-spaced — and cost a long chase for a font bug that
        // did not exist.
        rep.size = hostingView.bounds.size
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
        openProviderSettings: { _ in },
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
