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

    /// One site to sign in to. `accept` is asked whenever the cookies change,
    /// and says whether they're a working login.
    struct Step {
        let site: String
        let url: URL
        let accept: @Sendable ([HTTPCookie]) async -> Bool
    }

    /// Only one at a time. Holds the window alive while it's open.
    private static var current: WebSignInWindow?

    /// Opens one window and walks the steps in it, sharing its cookies, so a
    /// site that shares a login with the one before needs no second sign-in.
    /// Throws only if the window closes before the first step is done; closing
    /// later keeps what was already signed in.
    static func run(steps: [Step]) async throws {
        guard let first = steps.first else { return }
        self.current?.finish(.failure(Failure.closed(site: first.site)))
        let signIn = WebSignInWindow(steps: steps)
        self.current = signIn
        try await withCheckedThrowingContinuation { continuation in
            signIn.continuation = continuation
            signIn.show()
        }
    }

    private let steps: [Step]
    private var stepIndex = 0
    private var step: Step {
        self.steps[self.stepIndex]
    }

    private let webView: WKWebView
    private var window: NSWindow?
    private var continuation: CheckedContinuation<Void, Error>?
    private var polling: Task<Void, Never>?
    private var lastTried: String?

    private init(steps: [Step]) {
        self.steps = steps
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

    private func show() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "Sign in to \(self.step.site)"
        window.isReleasedWhenClosed = false
        window.contentView = self.webView
        window.delegate = self
        window.center()
        self.window = window
        self.webView.load(URLRequest(url: self.step.url))
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
        guard await self.step.accept(cookies), self.continuation != nil else { return }
        guard self.stepIndex + 1 < self.steps.count else {
            self.finish(.success(()))
            return
        }
        self.stepIndex += 1
        self.lastTried = nil
        self.window?.title = "Sign in to \(self.step.site)"
        self.webView.load(URLRequest(url: self.step.url))
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
        if self.stepIndex == 0 {
            self.finish(.failure(Failure.closed(site: self.step.site)))
        } else {
            self.finish(.success(()))
        }
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
