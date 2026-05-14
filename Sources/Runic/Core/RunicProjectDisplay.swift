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

    static func isUnattributed(_ displayName: String) -> Bool {
        displayName == self.ledgerUnknownName || displayName == self.unattributedName
    }
}
