import Foundation

/// USD per million tokens, as models.dev publishes it.
public struct ModelPrice: Codable, Sendable, Equatable {
    public let input: Double
    public let output: Double
    public let cacheRead: Double?
    public let cacheWrite: Double?

    enum CodingKeys: String, CodingKey {
        case input
        case output
        case cacheRead = "cache_read"
        case cacheWrite = "cache_write"
    }

    public init(input: Double, output: Double, cacheRead: Double? = nil, cacheWrite: Double? = nil) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
    }

    /// Cost in USD. A cache rate the catalog doesn't list is billed as input,
    /// which is what providers without a cache discount charge.
    public func cost(input: Int, output: Int, cacheWrite: Int, cacheRead: Int) -> Double {
        let total = Double(input) * self.input
            + Double(output) * self.output
            + Double(cacheWrite) * (self.cacheWrite ?? self.input)
            + Double(cacheRead) * (self.cacheRead ?? self.input)
        return total / 1_000_000
    }
}

/// Per-model prices for providers that only report a balance, so tokens in the
/// local logs can be turned into an estimated spend without waiting for the
/// balance to move. Scoped by provider: a model is only priced from its own
/// vendor's list, never a reseller's or a near-namesake's.
public struct ModelPriceCatalog: Sendable, Equatable {
    /// models.dev provider id → model id → price.
    public let prices: [String: [String: ModelPrice]]
    /// When the prices were taken ("2026-09-23"), for display.
    public let snapshot: String?

    public init(prices: [String: [String: ModelPrice]], snapshot: String?) {
        self.prices = prices
        self.snapshot = snapshot
    }

    /// Which models.dev lists price each Runic provider, preferred first.
    /// Usage from logs has no region, so Kimi and StepFun check both lists.
    static let providerIDs: [UsageProvider: [String]] = [
        .deepseek: ["deepseek"],
        .kimi: ["moonshotai", "moonshotai-cn"],
        .kimiCN: ["moonshotai-cn", "moonshotai"],
        .stepfun: ["stepfun-ai", "stepfun"],
        .stepfunCN: ["stepfun", "stepfun-ai"],
    ]

    public static var pricedProviders: Set<UsageProvider> {
        Set(self.providerIDs.keys)
    }

    static var catalogIDs: Set<String> {
        Set(self.providerIDs.values.flatMap(\.self))
    }

    public func price(for provider: UsageProvider, model: String) -> ModelPrice? {
        guard let ids = Self.providerIDs[provider] else { return nil }
        for candidate in Self.candidates(for: model) {
            for id in ids {
                if let price = self.prices[id]?[candidate] { return price }
            }
        }
        return nil
    }

    /// "deepseek/DeepSeek-V4-Pro-20260812" → ["deepseek-v4-pro-20260812", "deepseek-v4-pro"].
    static func candidates(for model: String) -> [String] {
        var id = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let slash = id.lastIndex(of: "/") { id = String(id[id.index(after: slash)...]) }
        guard !id.isEmpty else { return [] }
        var result = [id]
        let undated = id.replacingOccurrences(
            of: #"-(\d{8}|\d{4}-\d{2}-\d{2}|\d{4})$"#,
            with: "",
            options: .regularExpression)
        if undated != id, !undated.isEmpty { result.append(undated) }
        return result
    }

    /// Later catalogs win model by model (live over bundled, user over live).
    public func overlaid(by other: ModelPriceCatalog) -> ModelPriceCatalog {
        var merged = self.prices
        for (provider, models) in other.prices {
            merged[provider, default: [:]].merge(models) { _, new in new }
        }
        return ModelPriceCatalog(prices: merged, snapshot: other.snapshot ?? self.snapshot)
    }

    // MARK: - Encoding

    private struct Snapshot: Codable {
        let source: String?
        let snapshot: String?
        let prices: [String: [String: ModelPrice]]
    }

    /// Runic's compact format (bundled file, cache, user overrides).
    public static func decodeSnapshot(_ data: Data) throws -> ModelPriceCatalog {
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
        return ModelPriceCatalog(prices: decoded.prices, snapshot: decoded.snapshot)
    }

    public func encodedSnapshot() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Snapshot(source: "models.dev", snapshot: self.snapshot, prices: self.prices))
    }

    /// The full `https://models.dev/api.json`, trimmed to the lists Runic uses.
    public static func fromModelsDev(_ data: Data, snapshot: String?) throws -> ModelPriceCatalog {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        var prices: [String: [String: ModelPrice]] = [:]
        for id in self.catalogIDs {
            guard let provider = root[id] as? [String: Any],
                  let models = provider["models"] as? [String: Any] else { continue }
            for (modelID, value) in models {
                guard let model = value as? [String: Any],
                      let cost = model["cost"] as? [String: Any],
                      let input = (cost["input"] as? NSNumber)?.doubleValue,
                      let output = (cost["output"] as? NSNumber)?.doubleValue
                else { continue }
                prices[id, default: [:]][modelID.lowercased()] = ModelPrice(
                    input: input,
                    output: output,
                    cacheRead: (cost["cache_read"] as? NSNumber)?.doubleValue,
                    cacheWrite: (cost["cache_write"] as? NSNumber)?.doubleValue)
            }
        }
        guard !prices.isEmpty else { throw CocoaError(.coderValueNotFound) }
        return ModelPriceCatalog(prices: prices, snapshot: snapshot)
    }

    /// The copy shipped with the app, used until a live fetch succeeds.
    public static let bundled: ModelPriceCatalog = {
        guard let url = Bundle.module.url(forResource: "model-prices", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? decodeSnapshot(data)
        else { return ModelPriceCatalog(prices: [:], snapshot: nil) }
        return catalog
    }()
}
