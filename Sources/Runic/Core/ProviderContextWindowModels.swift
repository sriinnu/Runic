import Foundation

struct ProviderContextSnapshot: Sendable {
    let discoveredAt: Date?
    let providersByID: [String: ContextProvider]
    let modelsByProviderID: [String: [ContextModel]]
}

struct ContextProvider: Sendable {
    let providerID: String
    let canonicalProviderID: String?
    let aliases: Set<String>
    let lastRefreshed: Date?

    var lookupIDs: Set<String> {
        var ids = self.aliases
        ids.insert(self.providerID)
        if let canonicalProviderID {
            ids.insert(canonicalProviderID)
        }
        return ids
    }
}

struct ContextModel: Sendable {
    let key: String
    let modelID: String
    let name: String?
    let aliases: [String]
    let providerID: String
    let canonicalProviderID: String?
    let mode: String?
    let contextWindow: Int
    let discoveredAt: Date?

    var lookupProviderIDs: Set<String> {
        var ids: Set<String> = [self.providerID]
        if let canonicalProviderID {
            ids.insert(canonicalProviderID)
        }
        return ids
    }

    var lookupModelIDs: [String] {
        ([self.key, self.modelID] + [self.name].compactMap { $0 } + self.aliases)
            .filter { !$0.isEmpty }
    }
}

struct KoshaSnapshotRaw: Decodable {
    let schemaVersion: Int
    let discoveredAt: Int?
    let providers: [KoshaProviderRaw]
    let models: [KoshaModelRaw]
}

struct KoshaProviderRaw: Decodable {
    let providerId: String?
    let canonicalProviderId: String?
    let aliases: [String]?
    let lastRefreshed: Int?
}

struct KoshaModelRaw: Decodable {
    let key: String?
    let modelId: String?
    let name: String?
    let providerId: String?
    let canonicalProviderId: String?
    let mode: String?
    let aliases: [String]?
    let contextWindow: Int?
    let discoveredAt: Int?
}
