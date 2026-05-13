import Foundation

enum RunicResourceLocator {
    static func url(forResource name: String, withExtension fileExtension: String) -> URL? {
        for root in self.resourceRoots() {
            let url = root
                .appendingPathComponent(name, isDirectory: false)
                .appendingPathExtension(fileExtension)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    static func directories(named name: String) -> [URL] {
        var seen: Set<String> = []
        return self.resourceRoots().compactMap { root in
            let url = root.appendingPathComponent(name, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { return nil }

            let key = url.standardizedFileURL.path
            guard seen.insert(key).inserted else { return nil }
            return url
        }
    }

    private static func resourceRoots() -> [URL] {
        let sourceResourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
        let workingDirectoryResourcesURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/Runic/Resources", isDirectory: true)

        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.resourceURL?.appendingPathComponent("Resources", isDirectory: true),
            Bundle.main.resourceURL?.appendingPathComponent("Runic_Runic.bundle/Resources", isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent("Runic_Runic.bundle/Resources", isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Runic_Runic.bundle/Resources", isDirectory: true),
            sourceResourcesURL,
            workingDirectoryResourcesURL,
        ]

        var seen: Set<String> = []
        return candidates.compactMap { url in
            guard let url else { return nil }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { return nil }

            let key = url.standardizedFileURL.path
            guard seen.insert(key).inserted else { return nil }
            return url
        }
    }
}
