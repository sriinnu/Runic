import AppKit
import Foundation
import RunicCore

// MARK: - Errors

enum RunicConfigStoreError: LocalizedError {
    case fileSystemError(String)

    var errorDescription: String? {
        switch self {
        case let .fileSystemError(message):
            "File system error: \(message)"
        }
    }
}

// MARK: - Store

/// File-backed store for the hot-reload `config.json`, mirroring `CustomProviderStore`'s
/// Application Support location and atomic I/O style.
enum RunicConfigStore {
    private static let log = RunicLog.logger("config-store")

    // MARK: - Storage Location

    static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let runicDir = appSupport.appendingPathComponent("Runic", isDirectory: true)
        try? FileManager.default.createDirectory(at: runicDir, withIntermediateDirectories: true)
        return runicDir.appendingPathComponent("config.json")
    }

    // MARK: - Load/Save

    /// Load the hot-reload config from disk.
    ///
    /// Returns `.empty` when the file is missing or can't be decoded — decode errors are
    /// logged, never thrown. Keeping the last-good config around is the caller's job.
    static func load() -> RunicConfig {
        guard FileManager.default.fileExists(atPath: self.storageURL.path) else {
            self.log.info("No config file found, using empty config.")
            return .empty
        }

        do {
            let data = try Data(contentsOf: self.storageURL)
            let config = try JSONDecoder().decode(RunicConfig.self, from: data)
            Self.log.info("Loaded config (\(config.activeOverrideCount) override(s)).")
            return config
        } catch {
            self.log.error("Failed to decode config file, ignoring it: \(error)")
            return .empty
        }
    }

    /// Save the config to disk atomically with pretty-printed, sorted JSON.
    static func save(_ config: RunicConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(config)
            try data.write(to: self.storageURL, options: .atomic)
            Self.log.info("Saved config (\(config.activeOverrideCount) override(s)).")
        } catch {
            Self.log.error("Failed to save config: \(error)")
            throw RunicConfigStoreError.fileSystemError(error.localizedDescription)
        }
    }

    // MARK: - Seeding & Discovery

    /// Write the self-documenting default config if the file doesn't exist yet.
    static func ensureSeeded() {
        guard !FileManager.default.fileExists(atPath: self.storageURL.path) else { return }

        do {
            let data = Data(Self.seededDefaultJSON.utf8)
            try data.write(to: self.storageURL, options: .atomic)
            Self.log.info("Seeded default config file.")
        } catch {
            self.log.error("Failed to seed config file: \(error)")
        }
    }

    /// Open the config file in the user's default editor, seeding it first if needed.
    static func openInEditor() {
        self.ensureSeeded()
        NSWorkspace.shared.open(self.storageURL)
    }

    /// Reveal the config file in Finder, seeding it first if needed.
    static func revealInFinder() {
        self.ensureSeeded()
        NSWorkspace.shared.activateFileViewerSelecting([self.storageURL])
    }

    // MARK: - Seed Template

    /// JSON has no comments, so guidance lives in the `"$comment"` value, which the
    /// decoder ignores as an unknown key. Mirrors `RunicConfig.seededDefault`.
    private static let seededDefaultJSON = """
    {
      "$comment" : "Runic hot-reload config; save to apply, no restart. Empty endpoint = default. \
    providers.<id>.quota.windows = rolling budget gauge (minutes + requests or tokens), \
    e.g. DashScope Token Plan: 300=5h 10080=7d 43200=30d. Edit limits to your tier; gauge hot-reloads.",
      "logPaths" : [],
      "providers" : {
        "qwen" : {
          "endpoint" : ""
        },
        "qwenCN" : {
          "endpoint" : ""
        }
      }
    }
    """
}
