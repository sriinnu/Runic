import Foundation

public struct OTelGenAIIngestionOptions: Sendable, Codable, Hashable {
    public var enabled: Bool
    public var allowExperimentalSemanticConventions: Bool
    public var defaultProvider: UsageProvider?
    public var source: UsageLedgerEntry.Source

    public init(
        enabled: Bool = false,
        allowExperimentalSemanticConventions: Bool = true,
        defaultProvider: UsageProvider? = nil,
        source: UsageLedgerEntry.Source = .openTelemetry)
    {
        self.enabled = enabled
        self.allowExperimentalSemanticConventions = allowExperimentalSemanticConventions
        self.defaultProvider = defaultProvider
        self.source = source
    }

    public static let disabled = OTelGenAIIngestionOptions(enabled: false)
}

public enum OTelGenAILedgerAdapterError: LocalizedError, Sendable, Equatable {
    case invalidUTF8
    case invalidJSON(String)
    case fileTooLarge(path: String, size: Int, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            "OTel payload is not valid UTF-8."
        case let .invalidJSON(message):
            "OTel JSON parse failed: \(message)"
        case let .fileTooLarge(path, size, limit):
            "OTel JSON file is too large for whole-file parsing: " +
                "\(path) (\(size) bytes, limit \(limit) bytes). Use JSONL or split the file."
        }
    }
}
