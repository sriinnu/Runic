import SwiftUI

/// Semantic color tokens for consistent theming across the Runic UI.
enum RunicColors {
    // MARK: - Status Colors

    static let success = Color(nsColor: .systemGreen)
    static let warning = Color(nsColor: .systemOrange)
    static let error = Color(nsColor: .systemRed)
    static let info = Color(nsColor: .systemBlue)

    // MARK: - Chart Palette (6 accessible colors)

    /// Ordered palette for chart series. Colors chosen for distinguishability in
    /// both light and dark mode and for common color-vision deficiencies.
    static let chartPalette: [Color] = [
        Color(red: 0.26, green: 0.55, blue: 0.96), // blue
        Color(red: 0.94, green: 0.53, blue: 0.18), // orange
        Color(red: 0.46, green: 0.75, blue: 0.36), // green
        Color(red: 0.80, green: 0.45, blue: 0.92), // purple
        Color(red: 0.26, green: 0.78, blue: 0.86), // teal
        Color(red: 0.94, green: 0.74, blue: 0.26), // yellow
    ]

    /// Returns a chart color for the given index, wrapping around if needed.
    static func chartColor(at index: Int) -> Color {
        self.chartPalette[index % self.chartPalette.count]
    }

    // MARK: - Model Family Colors

    /// Color for Claude/Anthropic model family.
    static let modelFamilyClaude = Color(red: 0.80, green: 0.45, blue: 0.30)
    /// Color for GPT/OpenAI model family.
    static let modelFamilyGPT = Color(red: 0.30, green: 0.70, blue: 0.40)
    /// Color for Gemini/Google model family.
    static let modelFamilyGemini = Color(red: 0.26, green: 0.55, blue: 0.96)
    /// Default color for unknown model families.
    static let modelFamilyDefault = Color(red: 0.55, green: 0.55, blue: 0.60)

    /// Returns a color appropriate for the given model name based on its family.
    static func colorForModel(_ model: String) -> Color {
        let lower = model.lowercased()
        if lower.contains("claude") || lower.contains("sonnet") || lower.contains("opus") || lower.contains("haiku") {
            return self.modelFamilyClaude
        }
        if lower.contains("gpt") || lower.contains("o1") || lower.contains("o3") || lower.contains("o4") {
            return self.modelFamilyGPT
        }
        if lower.contains("gemini") {
            return self.modelFamilyGemini
        }
        return self.modelFamilyDefault
    }

    // MARK: - Named Chart Colors

    /// Credits history chart bar color
    static let creditsChartBar = Color(red: 73 / 255, green: 163 / 255, blue: 176 / 255)

    // MARK: - Opacity Tokens

    enum Opacity {
        static let nano: Double = 0.045
        static let subtle: Double = 0.08
        static let light: Double = 0.12
        static let medium: Double = 0.22
        static let strong: Double = 0.35
        static let emphasis: Double = 0.55
        static let prominent: Double = 0.70
        static let vivid: Double = 0.90
    }
}
