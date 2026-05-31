import Foundation

#if os(macOS)
extension ClaudeWebAPIFetcher {
    /// Probes a list of endpoints using the current claude.ai session cookies.
    /// - Parameters:
    ///   - endpoints: Absolute URLs or "/api/..." paths. Supports "{orgId}" placeholder.
    ///   - includePreview: When true, includes a truncated response preview in results.
    public static func probeEndpoints(
        _ endpoints: [String],
        includePreview: Bool = false,
        logger: ((String) -> Void)? = nil) async throws -> [ProbeResult]
    {
        let log: (String) -> Void = { msg in logger?("[claude-probe] \(msg)") }
        let sessionInfo = try extractSessionKeyInfo(logger: log)
        let sessionKey = sessionInfo.key
        let organization = try? await fetchOrganizationInfo(sessionKey: sessionKey, logger: log)
        let expanded = endpoints.map { endpoint -> String in
            var url = endpoint
            if let orgId = organization?.id {
                url = url.replacingOccurrences(of: "{orgId}", with: orgId)
            }
            if url.hasPrefix("/") {
                url = "https://claude.ai\(url)"
            }
            return url
        }

        var results: [ProbeResult] = []
        results.reserveCapacity(expanded.count)

        for endpoint in expanded {
            guard let url = URL(string: endpoint) else { continue }
            var request = URLRequest(url: url)
            request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
            request.setValue("application/json, text/html;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
            request.httpMethod = "GET"
            request.timeoutInterval = 20

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let http = response as? HTTPURLResponse
                let contentType = http?.value(forHTTPHeaderField: "Content-Type")
                let truncated = data.prefix(Self.maxProbeBytes)
                let body = String(data: truncated, encoding: .utf8) ?? ""

                let parsed = Self.parseProbeBody(data: data, fallbackText: body, contentType: contentType)
                let preview = includePreview ? parsed.preview : nil

                results.append(ProbeResult(
                    url: endpoint,
                    statusCode: http?.statusCode,
                    contentType: contentType,
                    topLevelKeys: parsed.keys,
                    emails: parsed.emails,
                    planHints: parsed.planHints,
                    notableFields: parsed.notableFields,
                    bodyPreview: preview))
            } catch {
                results.append(ProbeResult(
                    url: endpoint,
                    statusCode: nil,
                    contentType: nil,
                    topLevelKeys: [],
                    emails: [],
                    planHints: [],
                    notableFields: [],
                    bodyPreview: "Error: \(error.localizedDescription)"))
            }
        }

        return results
    }
}
#endif
