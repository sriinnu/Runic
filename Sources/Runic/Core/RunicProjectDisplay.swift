import Foundation
import RunicCore

enum RunicProjectDisplay {
    static let ledgerUnknownName = "Unknown project"
    static let unattributedName = "Unattributed usage"

    static func name(_ displayName: String) -> String {
        self.isUnattributed(displayName) ? self.unattributedName : displayName
    }

    static func name(for summary: UsageLedgerProjectSummary) -> String {
        self.name(summary.displayProjectName)
    }

    static func name(for summary: UsageLedgerModelSummary) -> String {
        self.name(summary.displayProjectName)
    }

    static func attributionText(for summary: UsageLedgerProjectSummary) -> String? {
        self.attributionText(
            displayName: summary.displayProjectName,
            confidence: summary.projectNameConfidence,
            source: summary.projectNameSource,
            provenance: summary.projectNameProvenance)
    }

    static func attributionText(for summary: UsageLedgerModelSummary) -> String? {
        self.attributionText(
            displayName: summary.displayProjectName,
            confidence: summary.projectNameConfidence,
            source: summary.projectNameSource,
            provenance: summary.projectNameProvenance)
    }

    static func isUnattributed(_ displayName: String) -> Bool {
        displayName == self.ledgerUnknownName || displayName == self.unattributedName
    }

    private static func attributionText(
        displayName: String,
        confidence: UsageLedgerProjectNameConfidence?,
        source: UsageLedgerProjectNameSource?,
        provenance: String?) -> String?
    {
        if self.isUnattributed(displayName) {
            return "Unattributed: provider log did not expose a readable project name or path."
        }

        let normalizedSource = source ?? .unknown
        let normalizedConfidence = confidence ?? .none
        guard normalizedSource != .projectName || normalizedConfidence != .high else { return nil }

        var parts: [String] = []
        parts.append("Attribution \(self.confidenceLabel(normalizedConfidence))")
        parts.append("source \(self.sourceLabel(normalizedSource))")
        if let provenance = provenance?.trimmingCharacters(in: .whitespacesAndNewlines), !provenance.isEmpty {
            parts.append(provenance)
        }
        return parts.joined(separator: " · ")
    }

    private static func confidenceLabel(_ confidence: UsageLedgerProjectNameConfidence) -> String {
        switch confidence {
        case .high: "high"
        case .medium: "medium"
        case .low: "low"
        case .none: "unknown"
        }
    }

    private static func sourceLabel(_ source: UsageLedgerProjectNameSource) -> String {
        switch source {
        case .projectName: "project name"
        case .projectID: "project id"
        case .inferredFromPath: "path"
        case .inferredFromName: "name token"
        case .budgetOverride: "budget override"
        case .unknown: "unknown"
        }
    }
}
