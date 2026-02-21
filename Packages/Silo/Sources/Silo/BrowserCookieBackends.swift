import Foundation

protocol BrowserCookieBackend: Sendable {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore]
    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        configuration: BrowserCookieClient.Configuration) throws -> [BrowserCookieRecord]
}

enum BrowserCookieBackendRegistry {
    static func backend(for browser: Browser) -> BrowserCookieBackend {
        #if os(macOS)
        switch browser.engine {
        case .chromium:
            return MacOSChromiumCookieBackend()
        case .firefox:
            return MacOSFirefoxCookieBackend()
        case .webkit:
            return MacOSSafariCookieBackend()
        }
        #elseif os(iOS)
        return IOSCookieBackend()
        #elseif os(Linux)
        switch browser.engine {
        case .chromium:
            return LinuxChromiumCookieBackend()
        case .firefox:
            return LinuxFirefoxCookieBackend()
        case .webkit:
            return NullBrowserCookieBackend()
        }
        #elseif os(Windows)
        switch browser.engine {
        case .chromium:
            return WindowsChromiumCookieBackend()
        case .firefox:
            return WindowsFirefoxCookieBackend()
        case .webkit:
            return NullBrowserCookieBackend()
        }
        #else
        return NullBrowserCookieBackend()
        #endif
    }
}

struct NullBrowserCookieBackend: BrowserCookieBackend {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore] {
        []
    }

    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        configuration: BrowserCookieClient.Configuration) throws -> [BrowserCookieRecord]
    {
        throw BrowserCookieError.loadFailed(
            browser: store.browser,
            details: "Cookie reader not implemented for this platform.")
    }
}

#if os(macOS)
private struct MacOSChromiumCookieBackend: BrowserCookieBackend {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore] {
        guard let appSupportName = Self.appSupportDirectoryName(for: browser) else { return [] }
        var stores: [BrowserCookieStore] = []
        for home in configuration.homeDirectories {
            let baseURL = home
                .appendingPathComponent("Library")
                .appendingPathComponent("Application Support")
                .appendingPathComponent(appSupportName)
            stores.append(contentsOf: Self.profileStores(baseURL: baseURL, browser: browser))
        }
        return stores
    }

    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        configuration: BrowserCookieClient.Configuration) throws -> [BrowserCookieRecord]
    {
        let reader = MacOSChromiumCookieReader()
        return try reader.readCookies(
            store: store,
            decryptionFailurePolicy: configuration.decryptionFailurePolicy)
    }

    private static func appSupportDirectoryName(for browser: Browser) -> String? {
        switch browser {
        case .chrome: return "Google/Chrome"
        case .chromeBeta: return "Google/Chrome Beta"
        case .chromeCanary: return "Google/Chrome Canary"
        case .chromium: return "Chromium"
        case .brave: return "Brave Browser"
        case .braveBeta: return "Brave Browser Beta"
        case .braveNightly: return "Brave Browser Nightly"
        case .edge: return "Microsoft Edge"
        case .edgeBeta: return "Microsoft Edge Beta"
        case .edgeCanary: return "Microsoft Edge Canary"
        case .arc: return "Arc"
        case .arcBeta: return "Arc Beta"
        case .arcCanary: return "Arc Canary"
        case .vivaldi: return "Vivaldi"
        case .helium: return "Helium"
        case .chatgptAtlas: return "ChatGPT Atlas"
        case .safari, .firefox:
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
}

private struct MacOSFirefoxCookieBackend: BrowserCookieBackend {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore] {
        var stores: [BrowserCookieStore] = []
        for home in configuration.homeDirectories {
            let baseURL = home
                .appendingPathComponent("Library")
                .appendingPathComponent("Application Support")
                .appendingPathComponent("Firefox")
                .appendingPathComponent("Profiles")
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

private struct MacOSSafariCookieBackend: BrowserCookieBackend {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore] {
        var stores: [BrowserCookieStore] = []
        for home in configuration.homeDirectories {
            let legacyURL = home
                .appendingPathComponent("Library")
                .appendingPathComponent("Cookies")
                .appendingPathComponent("Cookies.binarycookies")
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                stores.append(Self.store(for: browser, url: legacyURL, label: "Safari"))
            }

            let containerURL = home
                .appendingPathComponent("Library")
                .appendingPathComponent("Containers")
                .appendingPathComponent("com.apple.Safari")
                .appendingPathComponent("Data")
                .appendingPathComponent("Library")
                .appendingPathComponent("Cookies")
                .appendingPathComponent("Cookies.binarycookies")
            if FileManager.default.fileExists(atPath: containerURL.path) {
                stores.append(Self.store(for: browser, url: containerURL, label: "Safari (Container)"))
            }
        }
        return stores
    }

    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        configuration: BrowserCookieClient.Configuration) throws -> [BrowserCookieRecord]
    {
        guard let url = store.databaseURL else {
            throw BrowserCookieError.notFound(
                browser: store.browser,
                details: "Missing Safari cookies file URL.")
        }
        return try BinaryCookiesReader().readCookies(from: url)
    }

    private static func store(for browser: Browser, url: URL, label: String) -> BrowserCookieStore {
        BrowserCookieStore(
            browser: browser,
            profile: BrowserProfile(id: "default", name: "Default"),
            kind: .safari,
            label: label,
            databaseURL: url)
    }
}
#endif

#if os(iOS)
private struct IOSCookieBackend: BrowserCookieBackend {
    func stores(for browser: Browser, configuration: BrowserCookieClient.Configuration) -> [BrowserCookieStore] {
        guard browser.engine == .webkit else { return [] }
        var stores: [BrowserCookieStore] = []
        for home in configuration.homeDirectories {
            let candidatePaths = [
                home
                    .appendingPathComponent("Library")
                    .appendingPathComponent("Cookies")
                    .appendingPathComponent("Cookies.binarycookies"),
                home
                    .appendingPathComponent("Library")
                    .appendingPathComponent("WebKit")
                    .appendingPathComponent("WebsiteData")
                    .appendingPathComponent("Default")
                    .appendingPathComponent("Cookies.binarycookies"),
            ]
            for url in candidatePaths where FileManager.default.fileExists(atPath: url.path) {
                stores.append(BrowserCookieStore(
                    browser: browser,
                    profile: BrowserProfile(id: "default", name: "Default"),
                    kind: .primary,
                    label: "Default",
                    databaseURL: url))
            }
        }
        return stores
    }

    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        configuration: BrowserCookieClient.Configuration) throws -> [BrowserCookieRecord]
    {
        guard let url = store.databaseURL else {
            throw BrowserCookieError.notFound(
                browser: store.browser,
                details: "Missing cookies file URL.")
        }
        return try BinaryCookiesReader().readCookies(from: url)
    }
}
#endif

#if os(Linux)
private struct LinuxChromiumCookieBackend: BrowserCookieBackend {
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

private struct LinuxFirefoxCookieBackend: BrowserCookieBackend {
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

#if os(Windows)
private struct WindowsChromiumCookieBackend: BrowserCookieBackend {
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

private struct WindowsFirefoxCookieBackend: BrowserCookieBackend {
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
