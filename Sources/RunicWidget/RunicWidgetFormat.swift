import Foundation
import RunicCore
import SwiftUI

enum WidgetColors {
    private static let providerColors: [UsageProvider: Color] = [
        .codex: Self.rgb(73, 163, 176),
        .claude: Self.rgb(204, 124, 94),
        .gemini: Self.rgb(171, 135, 234),
        .antigravity: Self.rgb(96, 186, 126),
        .cursor: Self.rgb(0, 191, 165),
        .zai: Self.rgb(232, 90, 106),
        .factory: Self.rgb(255, 107, 53),
        .copilot: Self.rgb(168, 85, 247),
        .minimax: Self.rgb(99, 102, 241),
        .openrouter: Self.rgb(255, 90, 0),
        .vercelai: Self.rgb(0, 0, 0),
        .groq: Self.rgb(0, 200, 150),
        .deepseek: Self.rgb(76, 110, 245),
        .fireworks: Self.rgb(255, 115, 0),
        .mistral: Self.rgb(255, 90, 52),
        .perplexity: Self.rgb(35, 180, 146),
        .kimi: Self.rgb(0, 129, 255),
        .auggie: Self.rgb(255, 180, 0),
        .together: Self.rgb(98, 76, 245),
        .cohere: Self.rgb(58, 95, 255),
        .xai: Self.rgb(20, 20, 20),
        .cerebras: Self.rgb(14, 122, 161),
        .sambanova: Self.rgb(236, 84, 74),
        .azure: Self.rgb(0, 120, 212),
        .bedrock: Self.rgb(255, 153, 0),
        .vertexai: Self.rgb(66, 133, 244),
        .qwen: Self.rgb(98, 52, 227),
        .localLLM: Self.rgb(46, 204, 113),
    ]

    static func color(for provider: UsageProvider) -> Color {
        self.providerColors[provider] ?? self.rgb(73, 163, 176)
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }
}

enum WidgetFormat {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value)
    }

    static func credits(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func costAndTokens(cost: Double?, tokens: Int?) -> String {
        let costText = cost.map(self.usd) ?? "—"
        if let tokens {
            return "\(costText) · \(self.tokenCount(tokens))"
        }
        return costText
    }

    static func usd(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    static func tokenCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let raw = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(raw) tokens"
    }

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
