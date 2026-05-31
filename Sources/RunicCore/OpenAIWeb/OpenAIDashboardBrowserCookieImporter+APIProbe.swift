#if os(macOS)
import Foundation

extension OpenAIDashboardBrowserCookieImporter {
    func fetchSignedInEmailFromAPI(
        cookies: [HTTPCookie],
        logger: (String) -> Void) async -> String?
    {
        let chatgptCookies = cookies.filter { $0.domain.lowercased().contains("chatgpt.com") }
        guard !chatgptCookies.isEmpty else { return nil }

        let cookieHeader = chatgptCookies
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")

        let endpoints = [
            "https://chatgpt.com/backend-api/me",
            "https://chatgpt.com/api/auth/session",
        ]

        for urlString in endpoints {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 10
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                logger("API \(url.host ?? "chatgpt.com") \(url.path) status=\(status)")
                guard status >= 200, status < 300 else { continue }
                if let email = Self.findFirstEmail(inJSONData: data) {
                    return email.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                logger("API request failed: \(error.localizedDescription)")
            }
        }

        return nil
    }

    static func findFirstEmail(inJSONData data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
        var queue: [Any] = [json]
        var seen = 0
        while !queue.isEmpty, seen < 2000 {
            let cur = queue.removeFirst()
            seen += 1
            if let str = cur as? String, str.contains("@") {
                return str
            }
            if let dict = cur as? [String: Any] {
                for (k, v) in dict {
                    if k.lowercased() == "email", let s = v as? String, s.contains("@") { return s }
                    queue.append(v)
                }
            } else if let arr = cur as? [Any] {
                queue.append(contentsOf: arr)
            }
        }
        return nil
    }
}
#endif
