import AppKit
import RunicCore

extension StatusItemController {
    // MARK: - Actions reachable from menus

    @objc func refreshNow() {
        let provider = self.selectedMenuProvider
        if let provider {
            Task {
                await self.store.refreshSingleProvider(provider)
            }
        } else {
            Task { await self.store.refresh(trigger: .manual, forceTokenUsage: true) }
        }
    }

    @objc func installUpdate() {
        self.updater.checkForUpdates(nil)
    }

    @objc func openDashboard() {
        let preferred = self.lastMenuProvider
            ?? (self.store.isEnabled(.codex) ? .codex : self.store.enabledProviders().first)

        let provider = preferred ?? .codex
        let meta = self.store.metadata(for: provider)
        let urlString: String? = if provider == .claude, self.store.isClaudeSubscription() {
            meta.subscriptionDashboardURL ?? meta.dashboardURL
        } else {
            meta.dashboardURL
        }

        guard let urlString, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openCreditsPurchase() {
        let preferred = self.lastMenuProvider
            ?? (self.store.isEnabled(.codex) ? .codex : self.store.enabledProviders().first)
        let provider = preferred ?? .codex
        guard provider == .codex else { return }

        let dashboardURL = self.store.metadata(for: .codex).dashboardURL
        let purchaseURL = Self.sanitizedCreditsPurchaseURL(self.store.openAIDashboard?.creditsPurchaseURL)
        let urlString = purchaseURL ?? dashboardURL
        guard let urlString,
              let url = URL(string: urlString) else { return }

        let accountEmail = self.store.codexAccountEmailForOpenAIDashboard()
        let controller = self.creditsPurchaseWindow ?? OpenAICreditsPurchaseWindowController()
        controller.show(purchaseURL: url, accountEmail: accountEmail, autoStartPurchase: true)
        self.creditsPurchaseWindow = controller
    }

    static func sanitizedCreditsPurchaseURL(_ raw: String?) -> String? {
        guard let raw, let url = URL(string: raw) else { return nil }
        guard let host = url.host?.lowercased(), host.contains("chatgpt.com") else { return nil }
        let path = url.path.lowercased()
        let allowed = ["settings", "usage", "billing", "credits"]
        guard allowed.contains(where: { path.contains($0) }) else { return nil }
        return url.absoluteString
    }

    @objc func openStatusPage() {
        let preferred = self.lastMenuProvider
            ?? (self.store.isEnabled(.codex) ? .codex : self.store.enabledProviders().first)

        let provider = preferred ?? .codex
        let meta = self.store.metadata(for: provider)
        let urlString = meta.statusPageURL ?? meta.statusLinkURL
        guard let urlString, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func showSettingsGeneral() {
        self.openSettings(tab: .general)
    }

    @objc func showSettingsAbout() {
        self.openSettings(tab: .about)
    }

    func openMenuFromShortcut() {
        if self.usesSwiftUIPopoverMenu {
            if self.shouldMergeIcons, let button = self.statusItem.button {
                self.showPopover(relativeTo: button, provider: self.selectedMenuProvider)
                return
            }

            let provider = self.resolvedShortcutProvider()
            let item = self.statusItems[provider] ?? self.statusItem
            if let button = item.button {
                self.showPopover(relativeTo: button, provider: provider)
            }
            return
        }

        if self.shouldMergeIcons {
            self.statusItem.button?.performClick(nil)
            return
        }

        let provider = self.resolvedShortcutProvider()
        let item = self.statusItems[provider] ?? self.statusItem
        item.button?.performClick(nil)
    }

    func openSettings(tab: PreferencesTab) {
        DispatchQueue.main.async {
            SettingsWindowBridge.open(tab: tab, selection: self.preferencesSelection)
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    @objc func copyError(_ sender: NSMenuItem) {
        if let err = sender.representedObject as? String {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(err, forType: .string)
        }
    }

    func resolvedShortcutProvider() -> UsageProvider {
        if let last = self.lastMenuProvider, self.isEnabled(last) {
            return last
        }
        if let first = self.store.enabledProviders().first {
            return first
        }
        return .codex
    }
}
