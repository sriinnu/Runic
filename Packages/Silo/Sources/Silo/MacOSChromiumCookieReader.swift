#if os(macOS)
import CommonCrypto
import Foundation
import Security
import SQLite3

struct MacOSChromiumCookieReader {
    func readCookies(
        store: BrowserCookieStore,
        decryptionFailurePolicy: BrowserCookieDecryptionFailurePolicy = .bestEffort) throws -> [BrowserCookieRecord]
    {
        let reader = ChromiumCookieReader()
        let decryptor = MacOSChromiumDecryptor(browser: store.browser, databaseURL: store.databaseURL)
        return try reader.readCookies(
            store: store,
            browser: store.browser,
            decryptor: decryptor,
            decryptionFailurePolicy: decryptionFailurePolicy,
            requireKeyForEncrypted: true)
    }
}

private struct MacOSChromiumDecryptor: ChromiumCookieDecrypting {
    private static let salt = "saltysalt".data(using: .utf8) ?? Data()
    private static let iterations: UInt32 = 1003
    private static let keyLength = kCCKeySizeAES128
    private static let chromiumEpoch: Date = {
        var components = DateComponents()
        components.year = 1601
        components.month = 1
        components.day = 1
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return components.date ?? Date(timeIntervalSince1970: 0)
    }()

    let legacyKey: Data?
    let gcmKey: Data?

    var hasKey: Bool { self.legacyKey != nil || self.gcmKey != nil }

    init(browser: Browser, databaseURL: URL?) {
        guard let databaseURL,
              let serviceName = Self.serviceName(for: browser) else {
            self.legacyKey = nil
            self.gcmKey = nil
            return
        }
        let password = Self.readKeychainPassword(service: serviceName)
        self.legacyKey = password.flatMap { Self.deriveKey(from: $0) }
        self.gcmKey = Self.readLocalStateKey(databaseURL: databaseURL, legacyKey: self.legacyKey)
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
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        guard let data = CryptoSupport.decryptAESCBC(payload: payload, key: key, iv: iv) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decryptGCM(payload: Data, key: Data) -> String? {
        guard let data = CryptoSupport.decryptAESGCM(payload: payload, key: key) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func deriveKey(from password: String) -> Data? {
        let passwordBytes = Array(password.utf8)
        var key = Data(count: keyLength)
        let status = key.withUnsafeMutableBytes { keyBytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes,
                passwordBytes.count,
                [UInt8](salt),
                salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                iterations,
                keyBytes.bindMemory(to: UInt8.self).baseAddress,
                keyLength)
        }
        return status == kCCSuccess ? key : nil
    }

    private static func readKeychainPassword(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
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

        if keyData.count >= 3,
           let prefix = String(data: keyData.prefix(3), encoding: .utf8),
           (prefix == "v10" || prefix == "v11"),
           let legacyKey,
           let decrypted = CryptoSupport.decryptAESCBC(
                payload: Data(keyData.dropFirst(3)),
                key: legacyKey,
                iv: Data(repeating: 0x20, count: kCCBlockSizeAES128)) {
            if decrypted.count == 32 {
                return decrypted
            }
        }

        if keyData.count == 32 {
            return keyData
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

    private static func serviceName(for browser: Browser) -> String? {
        switch browser {
        case .chrome: return "Chrome Safe Storage"
        case .chromeBeta: return "Chrome Beta Safe Storage"
        case .chromeCanary: return "Chrome Canary Safe Storage"
        case .chromium: return "Chromium Safe Storage"
        case .brave: return "Brave Safe Storage"
        case .braveBeta: return "Brave Browser Beta Safe Storage"
        case .braveNightly: return "Brave Browser Nightly Safe Storage"
        case .edge: return "Microsoft Edge Safe Storage"
        case .edgeBeta: return "Microsoft Edge Beta Safe Storage"
        case .edgeCanary: return "Microsoft Edge Canary Safe Storage"
        case .arc: return "Arc Safe Storage"
        case .arcBeta: return "Arc Beta Safe Storage"
        case .arcCanary: return "Arc Canary Safe Storage"
        case .vivaldi: return "Vivaldi Safe Storage"
        case .helium: return "Helium Safe Storage"
        case .chatgptAtlas: return "ChatGPT Atlas Safe Storage"
        case .safari, .firefox:
            return nil
        }
    }
}
#endif
