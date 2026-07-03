import AppKit
import RunicCore
import SwiftUI

extension StatusItemController {
    func addProjectBreakdownSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let breakdown = self.store.ledgerProjectBreakdown(for: provider)
        guard !breakdown.isEmpty else { return false }

        let width = Self.menuCardBaseWidth
        self.addDeferredChartSubmenu(
            title: "Projects",
            id: "projectBreakdownChart",
            to: menu,
            width: width)
        {
            ProjectBreakdownMenuView(breakdown: breakdown, width: width)
        }
        return true
    }

    func addModelBreakdownSubmenu(to menu: NSMenu, provider: UsageProvider) -> Bool {
        let breakdown = self.store.ledgerModelBreakdown(for: provider)

        if !breakdown.isEmpty {
            let width = Self.menuCardBaseWidth
            self.addDeferredChartSubmenu(
                title: "Models",
                id: "modelBreakdownChart",
                to: menu,
                width: width)
            {
                ModelBreakdownMenuView(breakdown: breakdown, width: width)
            }
            return true
        }

        // Quota-window fallback: plain text rows, cheap enough to keep eager.
        let quotaWindows = self.modelQuotaWindows(for: provider)
        guard !quotaWindows.isEmpty else { return false }

        let submenu = NSMenu()
        submenu.delegate = self
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
