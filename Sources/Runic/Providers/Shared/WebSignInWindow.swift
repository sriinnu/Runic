import AppKit
import WebKit

/// Sign in to a website inside Runic, for numbers that only exist behind a web
/// login. macOS can refuse to let Runic read a browser's folder ("System Policy
/// deny file-read-data"), and no prompt appears when it does. This needs no
/// access to any browser: the login happens here, Runic keeps the resulting
/// cookies in its own Keychain item, and the page's own storage is thrown away.
@MainActor
final class WebSignInWindow: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    enum Failure: LocalizedError {
        case closed(site: String)

        var errorDescription: String? {
            switch self {
            case let .closed(site):
                "The \(site) sign-in window was closed before signing in. Turn this on again to retry."
            }
        }
    }

    /// Only one at a time. Holds the window alive while it's open.
    private static var current: WebSignInWindow?

    /// Opens the window and returns once `accept` takes the cookies, which it
    /// is asked again whenever they change. Throws if the user closes the window.
    static func run(
        site: String,
        url: URL,
        accept: @escaping @Sendable ([HTTPCookie]) async -> Bool) async throws
    {
        self.current?.finish(.failure(Failure.closed(site: site)))
        let signIn = WebSignInWindow(site: site, accept: accept)
        self.current = signIn
        try await withCheckedThrowingContinuation { continuation in
            signIn.continuation = continuation
            signIn.show(url: url)
        }
    }

    private let site: String
    private let accept: @Sendable ([HTTPCookie]) async -> Bool
    private let webView: WKWebView
    private var window: NSWindow?
    private var continuation: CheckedContinuation<Void, Error>?
    private var polling: Task<Void, Never>?
    private var lastTried: String?

    private init(site: String, accept: @escaping @Sendable ([HTTPCookie]) async -> Bool) {
        self.site = site
        self.accept = accept
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 720), configuration: configuration)
        // Sign-in providers turn away pages that don't look like a full browser.
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
            + "(KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        super.init()
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
    }

    private func show(url: URL) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "Sign in to \(self.site)"
        window.isReleasedWhenClosed = false
        window.contentView = self.webView
        window.delegate = self
        window.center()
        self.window = window
        self.webView.load(URLRequest(url: url))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        self.polling = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkCookies()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func checkCookies() async {
        guard self.continuation != nil else { return }
        let cookies = await self.webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        let fingerprint = cookies.map { "\($0.domain)|\($0.name)|\($0.value)" }.sorted().joined(separator: "\n")
        guard !cookies.isEmpty, fingerprint != self.lastTried else { return }
        self.lastTried = fingerprint
        if await self.accept(cookies) {
            self.finish(.success(()))
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        self.polling?.cancel()
        self.window?.delegate = nil
        self.window?.close()
        if Self.current === self { Self.current = nil }
        continuation.resume(with: result)
    }

    func windowWillClose(_: Notification) {
        self.finish(.failure(Failure.closed(site: self.site)))
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        Task { await self.checkCookies() }
    }

    /// "Continue with Google" opens a popup: keep it in this one window.
    func webView(
        _ webView: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures) -> WKWebView?
    {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}
