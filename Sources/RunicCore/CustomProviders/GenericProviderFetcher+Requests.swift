import Foundation

extension GenericProviderFetcher {
    /// Fetch usage data from the custom provider
    public func fetchUsage() async throws -> UsageData {
        guard let endpoint = self.config.endpoints.usage else {
            throw FetchError.noUsageEndpoint
        }

        let url = try self.buildURL(from: endpoint.url, with: endpoint.queryParams)

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        try await self.addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FetchError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.invalidJSON
        }

        return try self.extractUsageData(from: json, mapping: endpoint.mapping)
    }

    /// Fetch balance data from the custom provider
    public func fetchBalance() async throws -> BalanceData {
        guard let endpoint = self.config.endpoints.balance else {
            throw FetchError.noBalanceEndpoint
        }

        let url = try self.buildURL(from: endpoint.url, with: nil)

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        try await self.addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FetchError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.invalidJSON
        }

        return try self.extractBalanceData(from: json, mapping: endpoint.mapping)
    }
}
