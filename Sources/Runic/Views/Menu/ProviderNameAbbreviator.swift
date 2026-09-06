import Foundation
import RunicCore

/// Shared provider-name abbreviation for the compact provider tab bars.
/// Single source of truth so the NSMenu switcher and the SwiftUI popover
/// truncate names identically: known long names map to curated short forms,
/// unknown long names are prefix-truncated WITH an ellipsis marker so the
/// truncation is visible.
enum ProviderNameAbbreviator {
    static func abbreviate(_ name: String) -> String {
        // "Kimi (China)" → "Kimi CN" so a China account keeps its brand name in
        // the chip instead of truncating to "Kimi (…".
        let name = UsageProvider.compactDisplayName(name)
        if name.count <= 8 { return name }
        let abbreviations: [String: String] = [
            "Antigravity": "AntiG",
            "OpenRouter": "ORouter",
            "Perplexity": "Perplx",
            "SambaNova": "SambaN",
            "Azure OpenAI": "Azure",
            "MiniMax CN": "MiniMax CN",
            "StepFun CN": "StepFun CN",
        ]
        return abbreviations[name] ?? "\(name.prefix(6))\u{2026}"
    }
}
