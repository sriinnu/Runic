import Foundation
import RunicCore

extension UsageStore {
    /// `~/Library/Application Support/Runic/diagnostics/accounts.json`: one row
    /// per account the last refresh visited, written after every refresh
    /// cycle. Until the menu shows accounts, this is where a second login is
    /// seen to land (or fail). No tokens; display names may contain email
    /// addresses. Also includes percentages, resets, source labels, and errors.
    func persistAccountDiagnostics() {
        var rows: [[String: Any]] = []
        let formatter = ISO8601DateFormatter()
        for kind in UsageProvider.allCases where self.isEnabled(kind) {
            for account in self.accounts(for: kind) {
                let id = account.id
                var row: [String: Any] = [
                    "account": id.rawValue,
                    "kind": kind.rawValue,
                    "displayName": account.displayName,
                    "isDefault": id.isDefault,
                    "credential": Self.describe(account.credential),
                ]
                if let snapshot = self.snapshots[id] {
                    row["updatedAt"] = formatter.string(from: snapshot.updatedAt)
                    row["primaryUsedPercent"] = snapshot.primary.usedPercent
                    row["primaryWindowMinutes"] = snapshot.primary.windowMinutes ?? NSNull()
                    row["primaryResetsAt"] = snapshot.primary.resetsAt.map(formatter.string(from:)) ?? NSNull()
                    row["secondaryUsedPercent"] = snapshot.secondary?.usedPercent ?? NSNull()
                }
                row["sourceLabel"] = self.lastSourceLabels[id] ?? NSNull()
                row["error"] = self.errors[id] ?? NSNull()
                rows.append(row)
            }
        }
        let payload: [String: Any] = [
            "generatedAt": formatter.string(from: Date()),
            "addedAccountsOnDisk": self.addedAccounts.count,
            "accounts": rows,
        ]
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Runic/diagnostics", isDirectory: true),
            let json = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        else { return }
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let file = directory.appendingPathComponent("accounts.json")
            try json.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        } catch {}
    }

    private static func describe(_ credential: CredentialRef?) -> String {
        switch credential {
        case nil: "default"
        case let .oauthDir(path): "oauthDir:\(path)"
        case let .keychainItem(name): "keychainItem:\(name)"
        case let .env(name): "env:\(name)"
        case let .cookies(key): "cookies:\(key)"
        }
    }
}
