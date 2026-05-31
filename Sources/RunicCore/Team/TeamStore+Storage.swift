import Foundation

extension TeamStore {
    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let runicDir = appSupport.appendingPathComponent("Runic", isDirectory: true)
        try? FileManager.default.createDirectory(at: runicDir, withIntermediateDirectories: true)
        return runicDir.appendingPathComponent("teams.json")
    }

    public static func load() -> TeamsData {
        guard FileManager.default.fileExists(atPath: self.storageURL.path) else {
            return TeamsData()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TeamsData.self, from: data)
        } catch {
            print("[TeamStore] Failed to load teams: \(error)")
            return TeamsData()
        }
    }

    public static func save(_ teamsData: TeamsData) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(teamsData)
        try data.write(to: self.storageURL, options: .atomic)
    }

    public static func setCurrentUser(userID: String) throws {
        var data = self.load()
        data.currentUserID = userID
        try self.save(data)
    }

    public static func getCurrentUser() -> String? {
        self.load().currentUserID
    }
}
