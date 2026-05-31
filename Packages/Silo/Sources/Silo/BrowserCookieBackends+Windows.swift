import Foundation

#if os(Windows)
struct WindowsChromiumCookieBackend: BrowserCookieBackend {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore] {
        guard let localAppData = Self.localAppDataURL(),
              let directoryNames = Self.localDataDirectoryNames(for: browser) else {
            return []
        }
        var stores: [BrowserCookieStore] = []
        for name in directoryNames {
            let baseURL = Self.appending(path: name, to: localAppData)
            stores.append(contentsOf: Self.profileStores(baseURL: baseURL, browser: browser))
        }
        return stores
    }

    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        configuration: BrowserCookieClient.Configuration) throws -> [BrowserCookieRecord]
    {
        let reader = WindowsChromiumCookieReader()
        return try reader.readCookies(
            store: store,
            decryptionFailurePolicy: configuration.decryptionFailurePolicy)
    }

    private static func localAppDataURL() -> URL? {
        guard let value = ProcessInfo.processInfo.environment["LOCALAPPDATA"] else { return nil }
        return URL(fileURLWithPath: value)
    }

    private static func localDataDirectoryNames(for browser: Browser) -> [String]? {
        switch browser {
        case .chrome: return ["Google/Chrome/User Data"]
        case .chromeBeta: return ["Google/Chrome Beta/User Data"]
        case .chromeCanary: return ["Google/Chrome SxS/User Data"]
        case .chromium: return ["Chromium/User Data"]
        case .brave: return ["BraveSoftware/Brave-Browser/User Data"]
        case .braveBeta: return ["BraveSoftware/Brave-Browser-Beta/User Data"]
        case .braveNightly: return ["BraveSoftware/Brave-Browser-Nightly/User Data"]
        case .edge: return ["Microsoft/Edge/User Data"]
        case .edgeBeta: return ["Microsoft/Edge Beta/User Data"]
        case .edgeCanary: return ["Microsoft/Edge SxS/User Data"]
        case .vivaldi: return ["Vivaldi/User Data"]
        case .helium: return ["Helium/User Data"]
        case .arc, .arcBeta, .arcCanary, .chatgptAtlas, .safari, .firefox:
            return nil
        }
    }

    private static func profileStores(baseURL: URL, browser: Browser) -> [BrowserCookieStore] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: baseURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let profileNames = (try? fm.contentsOfDirectory(atPath: baseURL.path)) ?? []
        var stores: [BrowserCookieStore] = []
        for profileName in profileNames {
            let profileURL = baseURL.appendingPathComponent(profileName)
            var profileIsDir: ObjCBool = false
            guard fm.fileExists(atPath: profileURL.path, isDirectory: &profileIsDir),
                  profileIsDir.boolValue else { continue }

            let networkCookies = profileURL.appendingPathComponent("Network/Cookies")
            let legacyCookies = profileURL.appendingPathComponent("Cookies")
            let profile = BrowserProfile(id: profileName, name: profileName)

            if fm.fileExists(atPath: networkCookies.path) {
                stores.append(BrowserCookieStore(
                    browser: browser,
                    profile: profile,
                    kind: .network,
                    label: "\(profileName) (Network)",
                    databaseURL: networkCookies))
            }

            if fm.fileExists(atPath: legacyCookies.path) {
                stores.append(BrowserCookieStore(
                    browser: browser,
                    profile: profile,
                    kind: .primary,
                    label: profileName,
                    databaseURL: legacyCookies))
            }
        }
        return stores
    }

    private static func appending(path: String, to baseURL: URL) -> URL {
        path.split(separator: "/").reduce(baseURL) { url, component in
            url.appendingPathComponent(String(component))
        }
    }
}

struct WindowsFirefoxCookieBackend: BrowserCookieBackend {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore] {
        guard let appData = Self.appDataURL() else { return [] }
        let baseURL = appData
            .appendingPathComponent("Mozilla")
            .appendingPathComponent("Firefox")
            .appendingPathComponent("Profiles")
        return Self.profileStores(baseURL: baseURL, browser: browser)
    }

    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        configuration: BrowserCookieClient.Configuration) throws -> [BrowserCookieRecord]
    {
        let reader = FirefoxCookieReader()
        return try reader.readCookies(store: store)
    }

    private static func appDataURL() -> URL? {
        guard let value = ProcessInfo.processInfo.environment["APPDATA"] else { return nil }
        return URL(fileURLWithPath: value)
    }

    private static func profileStores(baseURL: URL, browser: Browser) -> [BrowserCookieStore] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: baseURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let profileNames = (try? fm.contentsOfDirectory(atPath: baseURL.path)) ?? []
        var stores: [BrowserCookieStore] = []
        for profileName in profileNames {
            let profileURL = baseURL.appendingPathComponent(profileName)
            var profileIsDir: ObjCBool = false
            guard fm.fileExists(atPath: profileURL.path, isDirectory: &profileIsDir),
                  profileIsDir.boolValue else { continue }

            let cookiesDB = profileURL.appendingPathComponent("cookies.sqlite")
            guard fm.fileExists(atPath: cookiesDB.path) else { continue }
            let profile = BrowserProfile(id: profileName, name: profileName)
            stores.append(BrowserCookieStore(
                browser: browser,
                profile: profile,
                kind: .primary,
                label: profileName,
                databaseURL: cookiesDB))
        }
        return stores
    }
}
#endif
