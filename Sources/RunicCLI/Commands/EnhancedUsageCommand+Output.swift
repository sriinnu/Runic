import Foundation

extension EnhancedUsageCommand {
    static func outputJSON(_ data: EnhancedUsageData, config: Configuration) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if config.isPretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        guard let jsonData = try? encoder.encode(data),
              let text = String(data: jsonData, encoding: .utf8)
        else {
            print("{}")
            return
        }

        print(text)
    }

    static func outputText(_ data: EnhancedUsageData, config: Configuration) {
        switch config.mode {
        case .summary:
            self.outputSummaryMode(data, config: config)
        case .detailed:
            self.outputDetailedMode(data, config: config)
        case .breakdown:
            self.outputBreakdownMode(data, config: config)
        case .trending:
            self.outputTrendingMode(data, config: config)
        }
    }

    static func outputSummaryMode(_ data: EnhancedUsageData, config: Configuration) {
        self.printHeader("Usage Summary", useColor: config.useColor)
        print("")

        if let summary = data.summary {
            print("Providers: \(summary.totalProviders)")
            print("Total Tokens: \(self.formatNumber(summary.totalTokens))")
            print("Average Usage: \(String(format: "%.1f", summary.averageUsagePercent))%")
            print("Highest Usage: \(summary.highestUsageProvider)")
            print("")
        }

        for providerData in data.providers {
            print(providerData.providerName)
            for window in providerData.windows {
                let bar = self.progressBar(
                    used: window.usedPercent,
                    width: 20,
                    useColor: config.useColor)
                let percent = String(format: "%.1f", window.usedPercent)
                print("  \(window.name): \(bar) \(percent)%")
            }
            print("")
        }
    }

    static func outputDetailedMode(_ data: EnhancedUsageData, config: Configuration) {
        self.printHeader("Detailed Usage Information", useColor: config.useColor)
        print("")

        for (index, providerData) in data.providers.enumerated() {
            if index > 0 { print("") }

            if config.useColor {
                print(self.ansi("1;36", providerData.providerName))
            } else {
                print(providerData.providerName)
            }

            for window in providerData.windows {
                print("")
                print("  \(window.name):")
                if let used = window.used, let limit = window.limit {
                    print("    Used: \(self.formatNumber(used)) / \(self.formatNumber(limit))")
                }
                print("    Percent: \(String(format: "%.1f", window.usedPercent))%")
                if let reset = window.resetDescription {
                    print("    Reset: \(reset)")
                }
            }
        }
    }

    static func outputBreakdownMode(_ data: EnhancedUsageData, config: Configuration) {
        self.printHeader("Token Breakdown", useColor: config.useColor)
        print("")
        print("Note: Detailed token breakdown requires historical log data.")
        print("Use 'runic insights --view models' for model-level breakdown.")
    }

    static func outputTrendingMode(_ data: EnhancedUsageData, config: Configuration) {
        self.printHeader("Usage Trends", useColor: config.useColor)
        print("")

        for providerData in data.providers {
            print(providerData.providerName)

            if let trends = providerData.trending, !trends.isEmpty {
                for trend in trends.suffix(10) {
                    let tokens = self.formatNumber(trend.totalTokens)
                    let cost = trend.cost.map { String(format: "$%.4f", $0) } ?? "n/a"
                    print("  \(trend.date): \(tokens) tokens (\(cost))")
                }
            } else {
                print("  No trending data available")
            }
            print("")
        }
    }

    static func progressBar(used: Double, width: Int, useColor: Bool) -> String {
        let filled = Int((used / 100.0) * Double(width))
        let empty = width - filled
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)

        guard useColor else { return "[\(bar)]" }

        let color = switch used {
        case 90...: "31" // red
        case 75...: "33" // yellow
        default: "32" // green
        }

        return "[\(self.ansi(color, bar))]"
    }

    static func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
    }

    static func printHeader(_ text: String, useColor: Bool) {
        if useColor {
            print(self.ansi("1;36", text))
        } else {
            print(text)
        }
    }

    static func ansi(_ code: String, _ text: String) -> String {
        "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }
}
