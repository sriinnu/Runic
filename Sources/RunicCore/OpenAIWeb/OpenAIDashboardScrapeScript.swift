#if os(macOS)
import Foundation

enum OpenAIDashboardScrapeScriptError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        "OpenAI dashboard scrape script is missing from the app bundle."
    }
}

let openAIDashboardScrapeScript = OpenAIDashboardScrapeScriptResource.load()

private enum OpenAIDashboardScrapeScriptResource {
    static func load() -> String? {
        let resourceNames = [
            (subdirectory: String?.none, name: "OpenAIDashboardScrape"),
            (subdirectory: String?.some("OpenAIWeb/Resources"), name: "OpenAIDashboardScrape"),
            (subdirectory: String?.some("Resources"), name: "OpenAIDashboardScrape"),
        ]
        for candidate in resourceNames {
            if let url = Bundle.module.url(
                forResource: candidate.name,
                withExtension: "js",
                subdirectory: candidate.subdirectory),
                let script = try? String(contentsOf: url, encoding: .utf8)
            {
                return script
            }
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/OpenAIDashboardScrape.js")
        if let script = try? String(contentsOf: sourceURL, encoding: .utf8) {
            return script
        }

        return nil
    }
}
#endif
