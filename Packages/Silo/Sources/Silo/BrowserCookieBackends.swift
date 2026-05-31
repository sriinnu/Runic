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
