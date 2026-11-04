import AppKit
import CryptoKit
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

    /// One site to sign in to. `validate` is asked as the cookies change, and
    /// returns what to do to keep a working login, or nil while there is none.
    /// Throwing ends the sign-in: this login can't work however long it waits.
    /// Keeping is separate so a window closed mid-check saves nothing.
    struct Step {
        let site: String
        let url: URL
        let validate: @Sendable ([HTTPCookie]) async throws -> (@Sendable () -> Void)?
        /// For a site whose login isn't in its cookies: picks up the headers its
        /// own page sends, for `validate` to read.
        var headerCapture: HeaderCapture?
    }

    /// Holds the auth headers a site's own page sends to one API prefix. Only
    /// ever filled from that site's main frame, and held in memory until `validate`
    /// decides to keep them.
    final class HeaderCapture: @unchecked Sendable {
        struct Headers {
            let authorization: String
            let organization: String?
        }

        let siteHost: String
        let apiPrefix: String
        private let lock = NSLock()
        private var captured: Headers?

        init(siteHost: String, apiPrefix: String) {
            self.siteHost = siteHost
            self.apiPrefix = apiPrefix
        }

        var headers: Headers? {
            self.lock.withLock { self.captured }
        }

        func store(_ headers: Headers) {
            self.lock.withLock { self.captured = headers }
        }

        /// JSON-escapes the prefix: a script is the only place it goes.
        var script: String {
            let encoded = (try? JSONSerialization.data(withJSONObject: [self.apiPrefix]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            return """
            (() => {
              const prefix = \(encoded)[0];
              const original = window.fetch;
              window.fetch = function (input, init) {
                try {
                  const url = typeof input === "string" ? input : (input && input.url) || String(input);
                  if (url.startsWith(prefix)) {
                    const headers = new Headers((init && init.headers) || (input && input.headers) || {});
                    const authorization = headers.get("authorization");
                    if (authorization) {
                      window.webkit.messageHandlers.\(WebSignInWindow.captureHandlerName).postMessage({
                        authorization,
                        organization: headers.get("openai-organization"),
                      });
                    }
                  }
                } catch {}
                return original.apply(this, arguments);
              };
            })();
            """
        }
    }

    fileprivate nonisolated static let captureHandlerName = "runicHeaderCapture"

    /// `WKUserContentController` keeps its handler alive, which would keep a
    /// closed window alive with it.
    private final class WeakCaptureHandler: NSObject, WKScriptMessageHandler {
        weak var owner: WebSignInWindow?

        init(owner: WebSignInWindow) {
            self.owner = owner
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            self.owner?.receiveCapture(message)
        }
    }

    /// Only one at a time. Holds the window alive while it's open.
    private static var current: WebSignInWindow?

    /// A login check can fail on a passing network problem with the same
    /// cookies, so they get asked again after this long.
    private static let retryInterval: TimeInterval = 10

    /// Opens one window and walks the steps in it, sharing its cookies, so a
    /// site that shares a login with the one before needs no second sign-in.
    /// Throws only if the first step never completes; closing later keeps what
    /// was already signed in. A second caller joins the window already open.
    static func run(steps: [Step]) async throws {
        guard !steps.isEmpty else { return }
        try await withCheckedThrowingContinuation { continuation in
            if let current = self.current {
                current.continuations.append(continuation)
                current.bringToFront()
                return
            }
            let signIn = WebSignInWindow(steps: steps)
            self.current = signIn
            signIn.continuations.append(continuation)
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
    private var continuations: [CheckedContinuation<Void, Error>] = []
    private var isFinished = false
    private var isChecking = false
    private var polling: Task<Void, Never>?
    private var lastTried: SHA256Digest?
    private var lastTriedAt = Date.distantPast

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
        for capture in steps.compactMap(\.headerCapture) {
            let controller = configuration.userContentController
            controller.add(WeakCaptureHandler(owner: self), name: Self.captureHandlerName)
            controller.addUserScript(WKUserScript(
                source: capture.script,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true))
        }
    }

    /// Takes headers only from the step's own site, over https, in the main frame.
    private func receiveCapture(_ message: WKScriptMessage) {
        guard let capture = self.step.headerCapture,
              message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "https",
              message.frameInfo.securityOrigin.host == capture.siteHost,
              let body = message.body as? [String: Any],
              let authorization = body["authorization"] as? String
        else { return }
        capture.store(WebSignInWindow.HeaderCapture.Headers(
            authorization: authorization,
            organization: body["organization"] as? String))
        // Cookies may not have changed, so don't let the fingerprint skip this.
        self.lastTried = nil
        Task { await self.checkCookies() }
    }

    private func show() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = self.webView
        window.delegate = self
        window.center()
        self.window = window
        self.updateTitle()
        self.webView.load(URLRequest(url: self.step.url))
        self.bringToFront()
        self.polling = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkCookies()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        self.window?.makeKeyAndOrderFront(nil)
    }

    /// There's no address bar, so the title says where this page really is:
    /// a password should only go in when that host looks right.
    private func updateTitle() {
        let host = self.webView.url?.host ?? self.step.url.host ?? self.step.site
        self.window?.title = "Sign in to \(self.step.site) — on \(host)"
    }

    private func checkCookies() async {
        // One check at a time, so a result always belongs to the current step.
        guard !self.isFinished, !self.isChecking else { return }
        self.isChecking = true
        defer { self.isChecking = false }

        let cookies = await self.webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        guard !self.isFinished, !cookies.isEmpty else { return }
        let fingerprint = SHA256.hash(data: Data(
            cookies.map { "\($0.domain)|\($0.name)|\($0.value)" }.sorted().joined(separator: "\n").utf8))
        let now = Date()
        guard fingerprint != self.lastTried || now.timeIntervalSince(self.lastTriedAt) >= Self.retryInterval
        else { return }
        self.lastTried = fingerprint
        self.lastTriedAt = now

        do {
            guard let keep = try await self.step.validate(cookies), !self.isFinished else { return }
            keep()
            self.advance()
        } catch {
            guard !self.isFinished else { return }
            // A later site failing doesn't undo the login already kept.
            self.finish(self.stepIndex == 0 ? .failure(error) : .success(()))
        }
    }

    private func advance() {
        guard self.stepIndex + 1 < self.steps.count else {
            self.finish(.success(()))
            return
        }
        self.stepIndex += 1
        self.lastTried = nil
        self.lastTriedAt = .distantPast
        self.updateTitle()
        self.webView.load(URLRequest(url: self.step.url))
    }

    private func finish(_ result: Result<Void, Error>) {
        guard !self.isFinished else { return }
        self.isFinished = true
        self.polling?.cancel()
        self.webView.configuration.userContentController.removeAllScriptMessageHandlers()
        self.webView.configuration.userContentController.removeAllUserScripts()
        self.window?.delegate = nil
        self.window?.close()
        if Self.current === self { Self.current = nil }
        let waiting = self.continuations
        self.continuations = []
        for continuation in waiting {
            continuation.resume(with: result)
        }
    }

    func windowWillClose(_: Notification) {
        if self.stepIndex == 0 {
            self.finish(.failure(Failure.closed(site: self.step.site)))
        } else {
            self.finish(.success(()))
        }
    }

    /// Logins and their identity providers are https; nothing else loads here.
    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void)
    {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        decisionHandler(!isMainFrame || scheme == "https" ? .allow : .cancel)
    }

    func webView(_: WKWebView, didCommit _: WKNavigation!) {
        self.updateTitle()
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        self.updateTitle()
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
