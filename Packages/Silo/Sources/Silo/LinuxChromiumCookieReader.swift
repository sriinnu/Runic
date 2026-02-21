#if os(Linux)
import Foundation
import SQLite3
#if canImport(CryptoSwift)
import CryptoSwift
#endif

struct LinuxChromiumCookieReader {
    func readCookies(
        store: BrowserCookieStore,
        decryptionFailurePolicy: BrowserCookieDecryptionFailurePolicy = .bestEffort) throws -> [BrowserCookieRecord]
    {
        let reader = ChromiumCookieReader()
        let decryptor = LinuxChromiumDecryptor(browser: store.browser, databaseURL: store.databaseURL)
        return try reader.readCookies(
            store: store,
            browser: store.browser,
            decryptor: decryptor,
            decryptionFailurePolicy: decryptionFailurePolicy,
            requireKeyForEncrypted: false)
    }
}

private struct LinuxChromiumDecryptor: ChromiumCookieDecrypting {
    private static let salt = "saltysalt".data(using: .utf8) ?? Data()
    private static let iterations: Int = 1
    private static let keyLength: Int = 16

    let legacyKey: Data?
    let gcmKey: Data?

    var hasKey: Bool { legacyKey != nil || gcmKey != nil }

    init(browser: Browser, databaseURL: URL?) {
        let password = Self.safeStoragePassword(for: browser)
        self.legacyKey = password.flatMap { Self.deriveKey(from: $0) }
        if let databaseURL {
            self.gcmKey = Self.readLocalStateKey(databaseURL: databaseURL, legacyKey: self.legacyKey)
        } else {
            self.gcmKey = nil
        }
    }

    func decrypt(data: Data) -> String? {
        guard data.count > 3 else { return nil }
        let prefix = data.prefix(3)
        guard let prefixString = String(data: prefix, encoding: .utf8),
              prefixString == "v10" || prefixString == "v11" else {
            return nil
        }

        let payload = Data(data.dropFirst(3))
        if let gcmKey, let plaintext = Self.decryptGCM(payload: payload, key: gcmKey) {
            return plaintext
        }
        if let legacyKey, let plaintext = Self.decryptCBC(payload: payload, key: legacyKey) {
            return plaintext
        }
        return nil
    }

    private static func decryptCBC(payload: Data, key: Data) -> String? {
        let iv = Data(repeating: 0x20, count: 16)
        guard let data = CryptoSupport.decryptAESCBC(payload: payload, key: key, iv: iv) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decryptGCM(payload: Data, key: Data) -> String? {
        guard let data = CryptoSupport.decryptAESGCM(payload: payload, key: key) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func safeStoragePassword(for browser: Browser) -> String? {
        if let env = ProcessInfo.processInfo.environment["SILO_CHROME_SAFE_STORAGE"], !env.isEmpty {
            return env
        }
        let candidates = secretServiceNames(for: browser)
        if let value = LinuxSecretService.lookupPassword(applications: candidates) {
            return value
        }
        if allowInsecureFallback() {
            return "peanuts"
        }
        return nil
    }

    private static func secretServiceNames(for browser: Browser) -> [String] {
        switch browser {
        case .chrome, .chromeBeta, .chromeCanary:
            return ["chrome", "google-chrome", "Chrome"]
        case .chromium:
            return ["chromium", "Chromium"]
        case .brave, .braveBeta, .braveNightly:
            return ["brave", "Brave"]
        case .edge, .edgeBeta, .edgeCanary:
            return ["edge", "microsoft-edge", "Edge"]
        case .vivaldi:
            return ["vivaldi", "Vivaldi"]
        case .helium:
            return ["Helium"]
        case .arc, .arcBeta, .arcCanary, .chatgptAtlas, .safari, .firefox:
            return ["chromium"]
        }
    }

    private static func allowInsecureFallback() -> Bool {
        let value = ProcessInfo.processInfo.environment["SILO_ALLOW_INSECURE_CHROMIUM_FALLBACK"] ?? ""
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["1", "true", "yes"].contains(normalized)
    }

    private static func deriveKey(from password: String) -> Data? {
        #if canImport(CryptoSwift)
        do {
            let key = try PKCS5.PBKDF2(
                password: Array(password.utf8),
                salt: Array(salt),
                iterations: iterations,
                keyLength: keyLength,
                variant: .sha1).calculate()
            return Data(key)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    private static func readLocalStateKey(databaseURL: URL, legacyKey: Data?) -> Data? {
        guard let localStateURL = localStateURL(for: databaseURL),
              let data = try? Data(contentsOf: localStateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let osCrypt = json["os_crypt"] as? [String: Any],
              let encryptedKeyBase64 = osCrypt["encrypted_key"] as? String,
              let encryptedKeyData = Data(base64Encoded: encryptedKeyBase64) else {
            return nil
        }

        var keyData = encryptedKeyData
        let dpapiPrefix = "DPAPI".data(using: .utf8) ?? Data()
        if keyData.starts(with: dpapiPrefix) {
            keyData = Data(keyData.dropFirst(dpapiPrefix.count))
        }

        if keyData.count == 32 {
            return keyData
        }

        if keyData.count >= 3,
           let prefix = String(data: keyData.prefix(3), encoding: .utf8),
           (prefix == "v10" || prefix == "v11"),
           let legacyKey,
           let decrypted = CryptoSupport.decryptAESCBC(
                payload: Data(keyData.dropFirst(3)),
                key: legacyKey,
                iv: Data(repeating: 0x20, count: 16)) {
            return decrypted.count == 32 ? decrypted : nil
        }

        return nil
    }

    private static func localStateURL(for databaseURL: URL) -> URL? {
        let parent = databaseURL.deletingLastPathComponent()
        let profileURL = parent.lastPathComponent == "Network" ? parent.deletingLastPathComponent() : parent
        let rootURL = profileURL.deletingLastPathComponent()
        let localStateURL = rootURL.appendingPathComponent("Local State")
        return FileManager.default.fileExists(atPath: localStateURL.path) ? localStateURL : nil
    }
}
#endif
