import AppKit
import SwiftUI

// MARK: - Deferred (lazy) hosted submenu content

//
// Chart submenus used to build their full SwiftUI hierarchies EAGERLY for all
// ~15-20 submenus on every `populateMenu` — the dominant cost of opening the
// menu. Each submenu now carries a placeholder item with a build closure and
// materializes its hosted view only when the submenu is about to open
// (`menuWillOpen`), following the NSMenuDelegate pattern the controller
// already uses for height refreshes.

extension StatusItemController {
    @MainActor
    final class DeferredHostedSubmenuContent {
        let id: String
        let build: @MainActor () -> NSView

        init(id: String, build: @escaping @MainActor () -> NSView) {
            self.id = id
            self.build = build
        }
    }

    /// Builds a hosting view and sizes it to its fitting height at a fixed
    /// width using the SAME view instance (no throwaway measuring controller).
    func makeSizedHostedView(_ rootView: some View, width: CGFloat) -> NSView {
        let hosting = MenuHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: 1))
        hosting.layoutSubtreeIfNeeded()
        let height = hosting.fittingSize.height
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
        return hosting
    }

    /// A submenu whose single hosted item is built lazily on first open.
    /// `id` becomes the item's `representedObject` after materialization, so
    /// existing id-based plumbing (`isHostedSubviewMenu`,
    /// `refreshHostedSubviewHeights`) keeps working unchanged.
    func makeDeferredHostedSubmenu(id: String, build: @escaping @MainActor () -> NSView) -> NSMenu {
        let submenu = NSMenu()
        submenu.delegate = self
        let item = NSMenuItem()
        item.isEnabled = false
        item.representedObject = DeferredHostedSubmenuContent(id: id, build: build)
        submenu.addItem(item)
        return submenu
    }

    /// Adds a titled menu item whose submenu hosts a lazily built chart view.
    func addDeferredChartSubmenu(
        title: String,
        id: String,
        to menu: NSMenu,
        width: CGFloat,
        view: @escaping @MainActor () -> some View)
    {
        let submenu = self.makeDeferredHostedSubmenu(id: id) { [weak self] in
            guard let self else { return NSView() }
            return self.makeSizedHostedView(self.themedHostedMenuRoot(view()), width: width)
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
    }

    /// Replace any deferred placeholders with their real hosted views. Called
    /// from `menuWillOpen` before AppKit measures the menu.
    func materializeDeferredSubmenuContent(in menu: NSMenu) {
        for item in menu.items {
            guard let deferred = item.representedObject as? DeferredHostedSubmenuContent else { continue }
            item.view = deferred.build()
            item.representedObject = deferred.id
        }
    }
}
