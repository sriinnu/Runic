import Foundation

extension GenericProviderFetcher {
    /// Build URL with variable substitution and query parameters
    func buildURL(from template: String, with params: [String: String]?) throws -> URL {
        var urlString = template

        urlString = try self.substituteDateVariables(in: urlString)

        guard var components = URLComponents(string: urlString) else {
            throw FetchError.invalidURL(urlString)
        }

        if let params, !params.isEmpty {
            var queryItems = components.queryItems ?? []
            queryItems.append(contentsOf: params.map { URLQueryItem(name: $0.key, value: $0.value) })
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw FetchError.invalidURL(urlString)
        }

        guard url.scheme?.lowercased() == "https" else {
            throw FetchError.insecureURL(urlString)
        }

        return url
    }

    /// Replace date variables in URL template
    private func substituteDateVariables(in template: String) throws -> String {
        var result = template
        let now = Date()

        let iso8601Formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        if result.contains("{{date}}") {
            result = result.replacingOccurrences(of: "{{date}}", with: iso8601Formatter.string(from: now))
        }

        if let customMatch = result.range(of: #"\{\{date:([^}]+)\}\}"#, options: .regularExpression) {
            let pattern = String(result[customMatch])
            if let formatRange = pattern.range(of: "(?<=:)[^}]+", options: .regularExpression) {
                let format = String(pattern[formatRange])
                dateFormatter.dateFormat = format
                result = result.replacingOccurrences(of: pattern, with: dateFormatter.string(from: now))
            }
        }

        if result.contains("{{start}}") || result.contains("{{end}}") {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: now)
            guard let startOfMonth = calendar.date(from: components) else {
                throw FetchError.invalidDateRange
            }
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now

            result = result.replacingOccurrences(of: "{{start}}", with: dateFormatter.string(from: startOfMonth))
            result = result.replacingOccurrences(of: "{{end}}", with: dateFormatter.string(from: endOfMonth))
        }

        if result.contains("{{timestamp}}") {
            result = result.replacingOccurrences(of: "{{timestamp}}", with: "\(Int(now.timeIntervalSince1970))")
        }

        return result
    }
}
