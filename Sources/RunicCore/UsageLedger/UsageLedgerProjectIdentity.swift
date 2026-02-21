import Foundation

public enum UsageLedgerProjectNameConfidence: String, Sendable, Codable {
    case none
    case low
    case medium
    case high

    var rank: Int {
        switch self {
        case .none: 0
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }
}

public enum UsageLedgerProjectNameSource: String, Sendable, Codable {
    case unknown
    case projectName
    case projectID
    case inferredFromPath
    case inferredFromName
    case budgetOverride
}

public struct UsageLedgerProjectIdentity: Sendable, Codable, Hashable {
    public let key: String?
    public let projectID: String?
    public let displayName: String?
    public let confidence: UsageLedgerProjectNameConfidence
    public let source: UsageLedgerProjectNameSource
    public let workspaceHash: String?
    public let provenance: String?

    public init(
        key: String?,
        projectID: String?,
        displayName: String?,
        confidence: UsageLedgerProjectNameConfidence,
        source: UsageLedgerProjectNameSource,
        workspaceHash: String?,
        provenance: String?)
    {
        self.key = key
        self.projectID = projectID
        self.displayName = displayName
        self.confidence = confidence
        self.source = source
        self.workspaceHash = workspaceHash
        self.provenance = provenance
    }
}

public enum UsageLedgerProjectIdentityResolver {
    public static func resolve(
        provider _: UsageProvider,
        projectID: String?,
        projectName: String?,
        budgetNameOverride: String? = nil) -> UsageLedgerProjectIdentity
    {
        let normalizedProjectID = normalizedIdentifier(projectID)
        let normalizedProjectName = normalizedDisplay(projectName)
        let budgetName = normalizedDisplay(budgetNameOverride)
        let workspaceCandidate = firstPathLikeValue(candidates: [projectID, projectName])
        let workspaceHash = workspaceCandidate.map(stablePathHash)
        let workspaceSuffix = workspaceHash.map { "#w:\($0.prefix(8))" } ?? ""

        var displayName: String?
        var confidence: UsageLedgerProjectNameConfidence = .none
        var source: UsageLedgerProjectNameSource = .unknown
        var provenance: String?

        if let budgetName {
            displayName = budgetName
            confidence = .high
            source = .budgetOverride
            provenance = "budget_override"
        } else if let normalizedProjectName {
            displayName = normalizedProjectName
            confidence = .high
            source = .projectName
            provenance = "entry.projectName"
        } else if let pathTail = inferredPathTail(from: projectID) {
            displayName = pathTail
            confidence = .medium
            source = .inferredFromPath
            provenance = "path_tail(projectID)"
        } else if let readableID = readableIdentifier(normalizedProjectID) {
            displayName = readableID
            confidence = .low
            source = .projectID
            provenance = "entry.projectID"
        } else if let inferredFromName = inferredNameToken(from: projectName) {
            displayName = inferredFromName
            confidence = .low
            source = .inferredFromName
            provenance = "inferred(projectName)"
        }

        let key: String?
        if let normalizedProjectID {
            key = "id:\(normalizedProjectID.lowercased())\(workspaceSuffix)"
        } else if let seed = displayName {
            let slug = slugify(seed)
            key = slug.isEmpty ? nil : "name:\(slug)\(workspaceSuffix)"
        } else {
            key = nil
        }

        return UsageLedgerProjectIdentity(
            key: key,
            projectID: normalizedProjectID,
            displayName: displayName,
            confidence: confidence,
            source: source,
            workspaceHash: workspaceHash,
            provenance: provenance)
    }

    private static func normalizedIdentifier(_ value: String?) -> String? {
        let cleaned = normalizedDisplay(value)
        guard let cleaned, !cleaned.isEmpty else { return nil }
        return cleaned
    }

    private static func normalizedDisplay(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let pieces = trimmed.split(whereSeparator: { $0.isWhitespace })
        guard !pieces.isEmpty else { return nil }
        return pieces.joined(separator: " ")
    }

    private static func inferredPathTail(from value: String?) -> String? {
        guard let value else { return nil }
        let separators = CharacterSet(charactersIn: "/\\")
        guard value.rangeOfCharacter(from: separators) != nil else { return nil }

        let parts = value.split { ch in
            ch == "/" || ch == "\\"
        }
        guard let last = parts.last else { return nil }
        let tail = normalizedDisplay(String(last))
        guard let tail else { return nil }
        guard !looksOpaqueIdentifier(tail) else { return nil }
        return tail
    }

    private static func readableIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        guard !value.isEmpty else { return nil }
        guard !looksOpaqueIdentifier(value) else { return nil }
        return value
    }

    private static func inferredNameToken(from value: String?) -> String? {
        let normalized = normalizedDisplay(value)
        guard let normalized, !normalized.isEmpty else { return nil }
        let slug = slugify(normalized)
        guard !slug.isEmpty else { return nil }
        let titleCased = slug.split(separator: "-")
            .map { token -> String in
                guard let first = token.first else { return "" }
                return "\(String(first).uppercased())\(token.dropFirst())"
            }
            .joined(separator: " ")
        return titleCased.isEmpty ? nil : titleCased
    }

    private static func looksOpaqueIdentifier(_ value: String) -> Bool {
        if value.count >= 24 {
            let opaqueCharset = CharacterSet(charactersIn: "0123456789abcdefABCDEF-")
            if value.unicodeScalars.allSatisfy({ opaqueCharset.contains($0) }) {
                return true
            }
        }
        if value.count > 64 {
            return true
        }
        return false
    }

    private static func slugify(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .init(identifier: "en_US_POSIX"))
        var scalarBuffer: [UnicodeScalar] = []
        scalarBuffer.reserveCapacity(folded.unicodeScalars.count)

        let allowed = CharacterSet.alphanumerics
        var previousWasDash = false
        for scalar in folded.unicodeScalars {
            if allowed.contains(scalar) {
                scalarBuffer.append(UnicodeScalar(String(scalar).lowercased()) ?? scalar)
                previousWasDash = false
            } else if !previousWasDash {
                scalarBuffer.append("-")
                previousWasDash = true
            }
        }

        var slug = String(String.UnicodeScalarView(scalarBuffer))
        while slug.hasPrefix("-") {
            slug.removeFirst()
        }
        while slug.hasSuffix("-") {
            slug.removeLast()
        }
        return slug
    }

    private static func firstPathLikeValue(candidates: [String?]) -> String? {
        for candidate in candidates {
            guard let candidate else { continue }
            if candidate.contains("/") || candidate.contains("\\") {
                return candidate
            }
        }
        return nil
    }

    private static func stablePathHash(_ value: String) -> String {
        let normalized = value.lowercased()
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in normalized.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}
