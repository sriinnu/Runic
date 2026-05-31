import Foundation

#if os(iOS)
struct IOSCookieBackend: BrowserCookieBackend {
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
