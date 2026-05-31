import AppKit
import RunicCore
import WebKit

@MainActor
final class OpenAICreditsPurchaseWindowController: NSWindowController, WKNavigationDelegate, WKScriptMessageHandler {
    private static let defaultSize = NSSize(width: 980, height: 760)
    private static let logHandlerName = "runicLog"
    private static let debugLogURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("runic-buy-credits.log")
    private let logger = RunicLog.logger("creditsPurchase")
    private var webView: WKWebView?
    private var accountEmail: String?
    private var pendingAutoStart = false
    private let logHandler = WeakScriptMessageHandler()

    init() {
        super.init(window: nil)
        self.logHandler.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(purchaseURL: URL, accountEmail: String?, autoStartPurchase: Bool) {
        let normalizedEmail = Self.normalizeEmail(accountEmail)
        if self.window == nil || normalizedEmail != self.accountEmail {
            self.accountEmail = normalizedEmail
            self.buildWindow()
        }
        Self.resetDebugLog()
        let accountValue = normalizedEmail ?? "nil"
        Self.appendDebugLog(
            "show autoStart=\(autoStartPurchase) url=\(purchaseURL.absoluteString) account=\(accountValue)")
        self.logger.debug("Show buy credits window")
        self.logger.debug("Auto-start purchase", metadata: ["enabled": autoStartPurchase ? "1" : "0"])
        self.logger.debug("Purchase URL", metadata: ["url": purchaseURL.absoluteString])
        self.logger.debug("Account email", metadata: ["email": accountValue])
        self.pendingAutoStart = autoStartPurchase
        self.load(url: purchaseURL)
        self.window?.center()
        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self.logHandler, name: Self.logHandlerName)
        config.websiteDataStore = OpenAIDashboardWebsiteDataStore.store(forAccountEmail: self.accountEmail)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: .zero)
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let window = NSWindow(
            contentRect: Self.defaultFrame(),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Buy Credits"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.contentView = container
        window.center()

        self.window = window
        self.webView = webView
    }

    private func load(url: URL) {
        guard let webView else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard self.pendingAutoStart else { return }
        self.pendingAutoStart = false
        let currentURL = webView.url?.absoluteString ?? "unknown"
        Self.appendDebugLog("didFinish url=\(currentURL)")
        self.logger.debug("Buy credits navigation finished", metadata: ["url": currentURL])
        webView.evaluateJavaScript(OpenAICreditsPurchaseAutoStartScript.source) { [logger] result, error in
            if let error {
                Self.appendDebugLog("autoStart error=\(error.localizedDescription)")
                logger.error("Auto-start purchase failed", metadata: ["error": error.localizedDescription])
                return
            }
            if let result {
                Self.appendDebugLog("autoStart result=\(String(describing: result))")
                logger.debug("Auto-start purchase result", metadata: ["result": String(describing: result)])
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.logHandlerName else { return }
        let payload = String(describing: message.body)
        Self.appendDebugLog("js \(payload)")
        self.logger.debug("Auto-buy log", metadata: ["payload": payload])
    }

    private static func normalizeEmail(_ email: String?) -> String? {
        guard let raw = email?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return raw.lowercased()
    }

    private static func defaultFrame() -> NSRect {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 900)
        let width = min(Self.defaultSize.width, visible.width * 0.92)
        let height = min(Self.defaultSize.height, visible.height * 0.88)
        let origin = NSPoint(x: visible.midX - width / 2, y: visible.midY - height / 2)
        return NSRect(origin: origin, size: NSSize(width: width, height: height))
    }

    private static func appendDebugLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: Self.debugLogURL.path) {
            if let handle = try? FileHandle(forWritingTo: Self.debugLogURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: Self.debugLogURL, options: .atomic)
        }
    }

    private static func resetDebugLog() {
        try? FileManager.default.removeItem(at: self.debugLogURL)
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.delegate?.userContentController(userContentController, didReceive: message)
    }
}
