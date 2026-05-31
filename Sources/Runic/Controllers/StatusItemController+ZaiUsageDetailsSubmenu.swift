import AppKit
import RunicCore

extension StatusItemController {
    func makeZaiUsageDetailsSubmenu(snapshot: UsageSnapshot?) -> NSMenu? {
        guard let zai = snapshot?.zaiUsage else { return nil }
        let hasMCPDetails = zai.timeLimit.map { !$0.usageDetails.isEmpty } ?? false
        let hasModelUsage = zai.modelUsage.map { !$0.entries.isEmpty } ?? false
        let hasToolUsage = zai.toolUsage.map { !$0.entries.isEmpty } ?? false
        guard hasMCPDetails || hasModelUsage || hasToolUsage else { return nil }

        let submenu = NSMenu()
        submenu.delegate = self

        if let modelUsage = zai.modelUsage, !modelUsage.entries.isEmpty {
            let headerFont = RunicFont.nsFont(size: NSFont.systemFontSize, weight: .semibold)
            let header = NSMenuItem(title: "Models (24h)", action: nil, keyEquivalent: "")
            header.attributedTitle = NSAttributedString(string: "Models (24h)", attributes: [.font: headerFont])
            header.isEnabled = false
            submenu.addItem(header)

            let totalTokensStr = UsageFormatter.tokenCountString(modelUsage.totalTokens)
            let totalPromptsStr = "\(modelUsage.totalPrompts) prompts"
            let totalCostStr = modelUsage.totalEstimatedCostUSD > 0
                ? String(format: " · ~$%.2f", modelUsage.totalEstimatedCostUSD) : ""
            let summaryItem = NSMenuItem(
                title: "\(totalTokensStr) tokens · \(totalPromptsStr)\(totalCostStr)",
                action: nil,
                keyEquivalent: "")
            summaryItem.isEnabled = false
            let summaryFont = RunicFont.nsFont(size: NSFont.smallSystemFontSize)
            summaryItem.attributedTitle = NSAttributedString(
                string: summaryItem.title,
                attributes: [.font: summaryFont, .foregroundColor: self.settings.theme.palette.nsSecondaryTextColor])
            submenu.addItem(summaryItem)
            submenu.addItem(.separator())

            for entry in modelUsage.entries {
                let tokens = UsageFormatter.tokenCountString(entry.tokens)
                var title = "\(entry.modelCode): \(tokens)"
                if entry.prompts > 0 {
                    title += " · \(entry.prompts)p"
                }
                if let cost = entry.estimatedCostUSD, cost > 0.001 {
                    title += String(format: " · ~$%.3f", cost)
                }
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                submenu.addItem(item)
            }

            if hasToolUsage || hasMCPDetails {
                submenu.addItem(.separator())
            }
        }

        if let toolUsage = zai.toolUsage, !toolUsage.entries.isEmpty {
            let headerFont = RunicFont.nsFont(size: NSFont.systemFontSize, weight: .semibold)
            let header = NSMenuItem(title: "MCP Tools (24h)", action: nil, keyEquivalent: "")
            header.attributedTitle = NSAttributedString(string: "MCP Tools (24h)", attributes: [.font: headerFont])
            header.isEnabled = false
            submenu.addItem(header)

            let totalItem = NSMenuItem(
                title: "\(toolUsage.totalCalls) total calls",
                action: nil,
                keyEquivalent: "")
            totalItem.isEnabled = false
            let totalFont = RunicFont.nsFont(size: NSFont.smallSystemFontSize)
            totalItem.attributedTitle = NSAttributedString(
                string: totalItem.title,
                attributes: [.font: totalFont, .foregroundColor: self.settings.theme.palette.nsSecondaryTextColor])
            submenu.addItem(totalItem)
            submenu.addItem(.separator())

            for entry in toolUsage.entries {
                let displayName = self.displayToolName(entry.toolName)
                let item = NSMenuItem(
                    title: "\(displayName): \(entry.count) calls",
                    action: nil,
                    keyEquivalent: "")
                submenu.addItem(item)
            }

            if hasMCPDetails {
                submenu.addItem(.separator())
            }
        }

        if let timeLimit = zai.timeLimit, !timeLimit.usageDetails.isEmpty {
            let headerFont = RunicFont.nsFont(size: NSFont.systemFontSize, weight: .semibold)
            let header = NSMenuItem(title: "Quota Window", action: nil, keyEquivalent: "")
            header.attributedTitle = NSAttributedString(string: "Quota Window", attributes: [.font: headerFont])
            header.isEnabled = false
            submenu.addItem(header)

            if let window = timeLimit.windowLabel {
                let item = NSMenuItem(title: window, action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
            if let resetTime = timeLimit.nextResetTime {
                let reset = UsageFormatter.resetDescription(from: resetTime)
                let item = NSMenuItem(title: "Resets: \(reset)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
            submenu.addItem(.separator())

            let sortedDetails = timeLimit.usageDetails.sorted {
                $0.modelCode.localizedCaseInsensitiveCompare($1.modelCode) == .orderedAscending
            }
            for detail in sortedDetails {
                let usage = UsageFormatter.tokenCountString(detail.usage)
                let item = NSMenuItem(title: "\(detail.modelCode): \(usage)", action: nil, keyEquivalent: "")
                submenu.addItem(item)
            }
        }

        return submenu
    }

    private func displayToolName(_ raw: String) -> String {
        let mapping: [String: String] = [
            "web_search": "Web Search",
            "web_reader": "Web Reader",
            "zread": "ZRead",
            "web-search": "Web Search",
            "web-reader": "Web Reader",
        ]
        return mapping[raw.lowercased()] ?? raw
    }
}
