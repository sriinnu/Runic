import Foundation

struct SQLiteSnapshot {
    let readURL: URL
    let cleanup: () -> Void

    static func prepare(from databaseURL: URL) -> SQLiteSnapshot {
        let fm = FileManager.default
        let tempURL = fm.temporaryDirectory
            .appendingPathComponent("silo", isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
        let tempParent = tempURL.deletingLastPathComponent()
        try? fm.createDirectory(at: tempParent, withIntermediateDirectories: true)

        var usedTemp = false
        do {
            try fm.copyItem(at: databaseURL, to: tempURL)
            usedTemp = true
        } catch {
            usedTemp = false
        }

        if usedTemp {
            let walURL = URL(fileURLWithPath: databaseURL.path + "-wal")
            let shmURL = URL(fileURLWithPath: databaseURL.path + "-shm")
            if fm.fileExists(atPath: walURL.path) {
                try? fm.copyItem(at: walURL, to: URL(fileURLWithPath: tempURL.path + "-wal"))
            }
            if fm.fileExists(atPath: shmURL.path) {
                try? fm.copyItem(at: shmURL, to: URL(fileURLWithPath: tempURL.path + "-shm"))
            }
            return SQLiteSnapshot(readURL: tempURL) {
                try? fm.removeItem(at: URL(fileURLWithPath: tempURL.path + "-wal"))
                try? fm.removeItem(at: URL(fileURLWithPath: tempURL.path + "-shm"))
                try? fm.removeItem(at: tempURL)
            }
        }

        return SQLiteSnapshot(readURL: databaseURL, cleanup: {})
    }
}
