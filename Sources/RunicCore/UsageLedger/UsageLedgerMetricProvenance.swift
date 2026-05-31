import Foundation

public enum MetricConfidence: String, Sendable, Codable, Hashable, CaseIterable {
    case exact
    case providerReported = "provider-reported"
    case estimated
    case inferred
    case unknown

    public var displayName: String {
        switch self {
        case .exact: "Exact"
        case .providerReported: "Provider-reported"
        case .estimated: "Estimated"
        case .inferred: "Inferred"
        case .unknown: "Unknown"
        }
    }

    fileprivate var rank: Int {
        switch self {
        case .exact: 5
        case .providerReported: 4
        case .estimated: 3
        case .inferred: 2
        case .unknown: 1
        }
    }
}

public enum MetricSourceKind: String, Sendable, Codable, Hashable, CaseIterable {
    case providerAPI = "provider-api"
    case providerDashboard = "provider-dashboard"
    case browserSession = "browser-session"
    case localLog = "local-log"
    case localProbe = "local-probe"
    case openTelemetry = "open-telemetry"
    case pricingTable = "pricing-table"
    case koshaRegistry = "kosha-registry"
    case staticFallback = "static-fallback"
    case heuristic
    case mixed
    case unknown

    public var displayName: String {
        switch self {
        case .providerAPI: "Provider API"
        case .providerDashboard: "Provider dashboard"
        case .browserSession: "Browser session"
        case .localLog: "Local log"
        case .localProbe: "Local probe"
        case .openTelemetry: "OpenTelemetry"
        case .pricingTable: "Pricing table"
        case .koshaRegistry: "Kosha"
        case .staticFallback: "Static fallback"
        case .heuristic: "Heuristic"
        case .mixed: "Mixed sources"
        case .unknown: "Unknown source"
        }
    }
}

public struct MetricProvenance: Sendable, Codable, Hashable {
    public let confidence: MetricConfidence
    public let source: MetricSourceKind
    public let detail: String?

    public init(confidence: MetricConfidence, source: MetricSourceKind, detail: String? = nil) {
        self.confidence = confidence
        self.source = source
        self.detail = detail
    }

    public var displayText: String {
        let base = "\(self.confidence.displayName) from \(self.source.displayName)"
        guard let detail = self.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty else {
            return base
        }
        return "\(base): \(detail)"
    }

    public static func combined(_ values: [MetricProvenance?]) -> MetricProvenance? {
        let provenances = values.compactMap(\.self)
        guard !provenances.isEmpty else { return nil }
        let first = provenances[0]
        if provenances.allSatisfy({ $0 == first }) {
            return first
        }
        let lowestConfidence = provenances.min { lhs, rhs in
            lhs.confidence.rank < rhs.confidence.rank
        }?.confidence ?? .unknown
        let sourceNames = Set(provenances.map(\.source.displayName)).sorted()
        let detail = sourceNames.isEmpty ? nil : sourceNames.joined(separator: ", ")
        return MetricProvenance(confidence: lowestConfidence, source: .mixed, detail: detail)
    }
}
