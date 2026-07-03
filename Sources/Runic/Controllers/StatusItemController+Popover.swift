import AppKit
import RunicCore
import SwiftUI

// MARK: - SwiftUI popover menu

extension StatusItemController {
    private static let swiftUIPopoverDefaultsKey = "swiftUIPopoverMenuEnabled"
    private static let swiftUIPopoverWidth: CGFloat = 392
    private static let swiftUIPopoverHeight: CGFloat = 680

    var usesSwiftUIPopoverMenu: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["RUNIC_SWIFTUI_POPOVER"] == "1" { return true }
        if env["RUNIC_SWIFTUI_POPOVER"] == "0" { return false }
        guard let stored = UserDefaults.standard.object(forKey: Self.swiftUIPopoverDefaultsKey) as? Bool else {
            return false
        }
        return stored
    }

    func attachPopover(to item: NSStatusItem) {
        item.menu = nil
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(self.handleStatusItemPopoverClick(_:))
        button.sendAction(on: [.leftMouseUp])
    }

    func detachPopover(from item: NSStatusItem) {
        guard let button = item.button else { return }
        if button.target === self, button.action == #selector(self.handleStatusItemPopoverClick(_:)) {
            button.target = nil
            button.action = nil
        }
    }

    @objc func handleStatusItemPopoverClick(_ sender: Any?) {
        guard let button = sender as? NSStatusBarButton else { return }
        let provider = self.providerForPopoverButton(button)
        self.showPopover(relativeTo: button, provider: provider)
    }

    func showPopover(relativeTo button: NSStatusBarButton, provider requestedProvider: UsageProvider?) {
        if self.popover?.isShown == true {
            self.dismissPopover()
            return
        }

        let enabledProviders = self.store.enabledProviders()
        let initialProvider: UsageProvider? = {
            if let requestedProvider, enabledProviders.contains(requestedProvider) {
                return requestedProvider
            }
            if self.shouldMergeIcons {
                return self.selectedMenuProvider.flatMap { enabledProviders.contains($0) ? $0 : nil }
            }
            return nil
        }()

        if let initialProvider {
            self.selectedMenuProvider = initialProvider
            self.lastMenuProvider = initialProvider
        } else if enabledProviders.count == 1 {
            self.lastMenuProvider = enabledProviders.first
        }

        let actions = MenuPopoverActions(
            installUpdate: { [weak self] in
                self?.dismissPopover()
                self?.installUpdate()
            },
            refresh: { [weak self] in
                self?.refreshNow()
            },
            openDashboard: { [weak self] in
                self?.dismissPopover()
                self?.openDashboard()
            },
            openStatusPage: { [weak self] in
                self?.dismissPopover()
                self?.openStatusPage()
            },
            switchAccount: { [weak self] provider in
                self?.dismissPopover()
                self?.runSwitchAccount(provider: provider)
            },
            exportCSV: { [weak self] scope in
                self?.dismissPopover()
                self?.exportUsage(format: .csv, scope: scope)
            },
            exportJSON: { [weak self] scope in
                self?.dismissPopover()
                self?.exportUsage(format: .json, scope: scope)
            },
            openSettings: { [weak self] in
                self?.dismissPopover()
                self?.showSettingsGeneral()
            },
            openAbout: { [weak self] in
                self?.dismissPopover()
                self?.showSettingsAbout()
            },
            quit: { [weak self] in
                self?.quit()
            },
            copyError: { [weak self] message in
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(message, forType: .string)
                self?.dismissPopover()
            })

        let rootView = MenuPopoverView(
            store: self.store,
            settings: self.settings,
            account: self.account,
            updateReady: self.updater.updateStatus.isUpdateReady,
            initialProvider: initialProvider,
            width: Self.swiftUIPopoverWidth,
            actions: actions,
            onSelectProvider: { [weak self] provider in
                guard let self else { return }
                self.selectedMenuProvider = provider
                self.lastMenuProvider = provider ?? self.store.enabledProviders().first
                self.applyIcon(phase: nil)
            })
            .environment(\.runicFonts, RunicFontStore.shared)

        let controller = NSHostingController(rootView: rootView)
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.appearance = self.settings.theme.palette.nsAppearance
        popover.contentSize = NSSize(width: Self.swiftUIPopoverWidth, height: Self.swiftUIPopoverHeight)
        popover.contentViewController = controller
        self.popover = popover

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.installPopoverDismissMonitors(anchor: button)
        self.schedulePopoverPing(provider: initialProvider)
    }

    func dismissPopover() {
        self.removePopoverDismissMonitors()
        self.popover?.close()
        self.popoverPingTask?.cancel()
        self.popoverPingTask = nil
    }

    private func installPopoverDismissMonitors(anchor button: NSStatusBarButton) {
        self.removePopoverDismissMonitors()
        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        self.popoverLocalEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: eventMask)
        { [weak self, weak button] event in
            guard let self else { return event }
            guard self.popover?.isShown == true else { return event }
            guard !self.eventIsInsidePopoverOrAnchor(event, anchor: button) else { return event }
            self.dismissPopover()
            return event
        }

        self.popoverGlobalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.popover?.isShown == true else { return }
                self.dismissPopover()
            }
        }
    }

    private func removePopoverDismissMonitors() {
        if let monitor = self.popoverLocalEventMonitor {
            NSEvent.removeMonitor(monitor)
            self.popoverLocalEventMonitor = nil
        }
        if let monitor = self.popoverGlobalEventMonitor {
            NSEvent.removeMonitor(monitor)
            self.popoverGlobalEventMonitor = nil
        }
    }

    private func eventIsInsidePopoverOrAnchor(_ event: NSEvent, anchor button: NSStatusBarButton?) -> Bool {
        if let popoverWindow = self.popover?.contentViewController?.view.window,
           event.window === popoverWindow
        {
            return true
        }

        guard let button,
              let buttonWindow = button.window,
              event.window === buttonWindow
        else {
            return false
        }

        let location = button.convert(event.locationInWindow, from: nil)
        return button.bounds.contains(location)
    }

    private func providerForPopoverButton(_ button: NSStatusBarButton) -> UsageProvider? {
        if self.statusItem.button === button {
            return self.shouldMergeIcons ? self.selectedMenuProvider : nil
        }
        for (provider, item) in self.statusItems where item.button === button {
            return self.isEnabled(provider) ? provider : nil
        }
        return nil
    }

    private func schedulePopoverPing(provider: UsageProvider?) {
        self.popoverPingTask?.cancel()
        guard self.settings.refreshFrequency != .manual else { return }

        self.popoverPingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: PerformanceConstants.menuOpenPingDelay)
            guard !Task.isCancelled else { return }
            guard self.popover?.isShown == true else { return }
            guard !self.store.isRefreshing else { return }
            let target = provider ?? self.selectedMenuProvider ?? self.store.enabledProviders().first
            let shouldPing = target.map { self.store.shouldPingOnMenuOpen(provider: $0) }
                ?? self.store.isStale
            guard shouldPing else { return }
            await self.store.refresh(trigger: .menuOpen)
        }
    }
}

extension StatusItemController: NSPopoverDelegate {
    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.popoverPingTask?.cancel()
            self.popoverPingTask = nil
            self.removePopoverDismissMonitors()
        }
    }
}
