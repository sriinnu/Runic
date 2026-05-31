import Foundation

#if os(Linux)
struct LinuxChromiumCookieBackend: BrowserCookieBackend {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore] {
        guard let configNames = Self.configDirectoryNames(for: browser) else { return [] }
        var stores: [BrowserCookieStore] = []
        for home in configuration.homeDirectories {
            let configBase = home.appendingPathComponent(".config")
            for name in configNames {
                let baseURL = Self.appending(path: name, to: configBase)
                stores.append(contentsOf: Self.profileStores(baseURL: baseURL, browser: browser))
            }
        }
        return stores
    }

    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        configuration: BrowserCookieClient.Configuration) throws -> [BrowserCookieRecord]
    {
        let reader = LinuxChromiumCookieReader()
        return try reader.readCookies(
            store: store,
            decryptionFailurePolicy: configuration.decryptionFailurePolicy)
    }

    private static func configDirectoryNames(for browser: Browser) -> [String]? {
        switch browser {
        case .chrome: return ["google-chrome"]
        case .chromeBeta: return ["google-chrome-beta"]
        case .chromeCanary: return ["google-chrome-unstable"]
        case .chromium: return ["chromium"]
        case .brave: return ["BraveSoftware/Brave-Browser"]
        case .braveBeta: return ["BraveSoftware/Brave-Browser-Beta"]
        case .braveNightly: return ["BraveSoftware/Brave-Browser-Nightly"]
        case .edge: return ["microsoft-edge"]
        case .edgeBeta: return ["microsoft-edge-beta"]
        case .edgeCanary: return ["microsoft-edge-canary", "microsoft-edge-dev"]
        case .vivaldi: return ["vivaldi"]
        case .helium: return ["Helium"]
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

struct LinuxFirefoxCookieBackend: BrowserCookieBackend {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore] {
        var stores: [BrowserCookieStore] = []
        for home in configuration.homeDirectories {
            let baseURL = home
                .appendingPathComponent(".mozilla")
                .appendingPathComponent("firefox")
            stores.append(contentsOf: Self.profileStores(baseURL: baseURL, browser: browser))
        }
        return stores
    }

    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        configuration: BrowserCookieClient.Configuration) throws -> [BrowserCookieRecord]
    {
        let reader = FirefoxCookieReader()
        return try reader.readCookies(store: store)
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
