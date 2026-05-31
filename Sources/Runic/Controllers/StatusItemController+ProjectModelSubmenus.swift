import AppKit
import RunicCore
import SwiftUI

extension StatusItemController {
    func addProjectBreakdownSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let breakdown = self.store.ledgerProjectBreakdown(for: provider)
        guard !breakdown.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        let submenu = NSMenu()
        submenu.delegate = self
        let chartView = self.themedHostedMenuRoot(ProjectBreakdownMenuView(breakdown: breakdown, width: width))
        let hosting = MenuHostingView(rootView: chartView)
        let controller = NSHostingController(rootView: chartView)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

        let chartItem = NSMenuItem()
        chartItem.view = hosting
        chartItem.isEnabled = false
        chartItem.representedObject = "projectBreakdownChart"
        submenu.addItem(chartItem)

        let item = NSMenuItem(title: "Projects", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    func addModelBreakdownSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let breakdown = self.store.ledgerModelBreakdown(for: provider)
        let submenu = NSMenu()
        submenu.delegate = self

        if !breakdown.isEmpty {
            let width = Self.menuCardBaseWidth
            let chartView = self.themedHostedMenuRoot(ModelBreakdownMenuView(breakdown: breakdown, width: width))
            let hosting = MenuHostingView(rootView: chartView)
            let controller = NSHostingController(rootView: chartView)
            let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: size.height))

            let chartItem = NSMenuItem()
            chartItem.view = hosting
            chartItem.isEnabled = false
            chartItem.representedObject = "modelBreakdownChart"
            submenu.addItem(chartItem)
        } else {
            let quotaWindows = self.modelQuotaWindows(for: provider)
            guard !quotaWindows.isEmpty else { return false }

            let titleItem = NSMenuItem(title: "Quota windows", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            submenu.addItem(titleItem)

            for window in quotaWindows {
                let rawLabel = window.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Model"
                let label = UsageFormatter.modelDisplayName(rawLabel)
                let used = Int(window.usedPercent.rounded())
                let remaining = Int(window.remainingPercent.rounded())
                var line = "\(label): \(used)% used · \(remaining)% left"
                if let resetsAt = window.resetsAt {
                    line += " · reset \(UsageFormatter.resetCountdownDescription(from: resetsAt))"
                } else if let resetDescription = window.resetDescription?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !resetDescription.isEmpty
                {
                    line += " · \(resetDescription)"
                }
                let detailItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
                detailItem.isEnabled = false
                submenu.addItem(detailItem)
            }
        }

        let item = NSMenuItem(title: "Models", action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.submenu = submenu
        menu.addItem(item)
        return true
    }

    private func modelQuotaWindows(for provider: UsageProvider) -> [RateWindow] {
        guard let snapshot = self.store.snapshot(for: provider) else { return [] }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self)
        var seen: Set<String> = []
        var result: [RateWindow] = []

        for window in windows {
            guard let label = window.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty
            else {
                continue
            }
            let normalized = label.lowercased()
            guard seen.insert(normalized).inserted else { continue }
            result.append(window)
        }
        return result
    }
}
