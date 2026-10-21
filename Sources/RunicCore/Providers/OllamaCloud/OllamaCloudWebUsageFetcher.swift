import Foundation
import Silo

/// Ollama Pro/Max accounts sign in with the website, not an API key, and the
/// usage numbers only exist on the settings page (`/settings`). The page is
/// server-rendered HTML, so we read the "Session usage" / "Weekly usage"
/// blocks out of it with the signed-in browser cookies.
enum OllamaCloudWebParser {
    private static let sessionLabels = ["Session usage", "Hourly usage"]
    private static let weeklyLabels = ["Weekly usage"]
    /// How far past a label to look for its percentage and reset time.
    private static let blockLength = 700

    /// Nil when the page is not a signed-in settings page.
    static func parse(html: String) -> OllamaCloudUsage? {
        let session = self.block(labels: self.sessionLabels, in: html)
        let weekly = self.block(labels: self.weeklyLabels, in: html)
        if session == nil, weekly == nil, !self.looksSignedIn(html) { return nil }
        return OllamaCloudUsage(
            monthlyUsage: nil,
            sessionUsage: session?.percent.map { $0 / 100 },
            weeklyUsage: weekly?.percent.map { $0 / 100 },
            models: [],
            cost: nil,
            sessionResetsAt: session?.resetsAt,
            weeklyResetsAt: weekly?.resetsAt)
    }

    private struct Block {
        let percent: Double?
        let resetsAt: Date?
    }

    private static func looksSignedIn(_ html: String) -> Bool {
        let lower = html.lowercased()
        let signedOut = lower.contains("href=\"/signin") || lower.contains("href=\"/login")
            || lower.contains("sign in to ollama")
        return !signedOut && (lower.contains("sign out") || lower.contains("/signout"))
    }

    private static func block(labels: [String], in html: String) -> Block? {
        guard let start = labels.compactMap({ html.range(of: $0, options: .caseInsensitive) }).min(by: {
            $0.lowerBound < $1.lowerBound
        }) else { return nil }
        let tail = html[start.upperBound...]
        var chunk = String(tail.prefix(self.blockLength))
        // Stop at the next usage label so one block never reads the other's numbers.
        for other in self.sessionLabels + self.weeklyLabels {
            if let r = chunk.range(of: other, options: .caseInsensitive) {
                chunk = String(chunk[..<r.lowerBound])
            }
        }
        return Block(percent: self.percent(in: chunk), resetsAt: self.resetDate(in: chunk))
    }

    private static func percent(in chunk: String) -> Double? {
        for pattern in [#"(\d+(?:\.\d+)?)\s*%\s*used"#, #"(\d+(?:\.\d+)?)\s*%"#, #"width:\s*(\d+(?:\.\d+)?)%"#] {
            if let value = self.firstCapture(pattern, in: chunk).flatMap(Double.init) { return value }
        }
        return nil
    }

    private static func resetDate(in chunk: String) -> Date? {
        guard let raw = self.firstCapture(#"data-time="([^"]+)""#, in: chunk) else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ISO8601DateFormatter().date(from: raw) ?? withFraction.date(from: raw)
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}

#if os(macOS)
struct OllamaCloudCookieSession {
    let cookieHeader: String
    let sourceLabel: String
}

enum OllamaCloudCookieImporter {
    private static let cookieClient = BrowserCookieClient()
    private static let cookieDomains = ["ollama.com"]

    /// One session per browser profile that holds any ollama.com cookies; the
    /// caller tries them in order until one is actually signed in.
    static func importSessions(logger: ((String) -> Void)? = nil) -> [OllamaCloudCookieSession] {
        let log: (String) -> Void = { msg in logger?("[ollama-cookie] \(msg)") }
        let order = ProviderDefaults.metadata[.ollamacloud]?.browserCookieOrder ?? Browser.defaultImportOrder
        var sessions: [OllamaCloudCookieSession] = []
        for browserSource in order {
            do {
                let query = BrowserCookieQuery(domains: self.cookieDomains)
                let sources = try Self.cookieClient.records(matching: query, in: browserSource)
                for source in sources where !source.records.isEmpty {
                    let cookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
                    guard !cookies.isEmpty else { continue }
                    log("Found \(cookies.count) cookies in \(source.label)")
                    sessions.append(OllamaCloudCookieSession(
                        cookieHeader: cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "),
                        sourceLabel: source.label))
                }
            } catch {
                log("\(browserSource.displayName) cookie import failed: \(error.localizedDescription)")
            }
        }
        return sessions
    }
}

enum OllamaCloudWebUsageFetcher {
    static let settingsURL = URL(string: "https://ollama.com/settings")!

    static func fetchUsage(logger: ((String) -> Void)? = nil) async throws -> OllamaCloudUsage {
        let sessions = OllamaCloudCookieImporter.importSessions(logger: logger)
        for session in sessions {
            if let usage = try await self.fetch(cookieHeader: session.cookieHeader) { return usage }
            logger?("[ollama-cookie] \(session.sourceLabel) is not signed in")
        }
        throw OllamaCloudAPIError.notSignedIn
    }

    /// Nil when this cookie jar is signed out (redirect to sign-in or 401/403).
    private static func fetch(cookieHeader: String) async throws -> OllamaCloudUsage? {
        var request = URLRequest(url: settingsURL)
        request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.addValue("text/html", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaCloudAPIError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { return nil }
        if let error = OllamaCloudAPIError.from(statusCode: http.statusCode) { throw error }
        let path = http.url?.path ?? ""
        if path.hasPrefix("/signin") || path.hasPrefix("/login") { return nil }
        guard let html = String(data: data, encoding: .utf8) else { throw OllamaCloudAPIError.decodingError }
        return OllamaCloudWebParser.parse(html: html)
    }
}
#endif
