#if os(Windows)
import Foundation
import SQLite3
import WinSDK

struct WindowsChromiumCookieReader {
    func readCookies(
        store: BrowserCookieStore,
        decryptionFailurePolicy: BrowserCookieDecryptionFailurePolicy = .bestEffort) throws -> [BrowserCookieRecord]
    {
        let reader = ChromiumCookieReader()
        let decryptor = WindowsChromiumDecryptor(databaseURL: store.databaseURL)
        return try reader.readCookies(
            store: store,
            browser: store.browser,
            decryptor: decryptor,
            decryptionFailurePolicy: decryptionFailurePolicy,
            requireKeyForEncrypted: false)
    }
}

private struct WindowsChromiumDecryptor: ChromiumCookieDecrypting {
    let masterKey: Data?

    var hasKey: Bool { masterKey != nil }

    init(databaseURL: URL?) {
        if let databaseURL {
            self.masterKey = Self.readLocalStateKey(databaseURL: databaseURL)
        } else {
            self.masterKey = nil
        }
    }

    func decrypt(data: Data) -> String? {
        guard data.count > 3 else { return nil }
        let prefix = data.prefix(3)
        if let prefixString = String(data: prefix, encoding: .utf8),
           prefixString == "v10" || prefixString == "v11" {
            guard let masterKey else { return nil }
            let payload = Data(data.dropFirst(3))
            guard let plaintext = CryptoSupport.decryptAESGCM(payload: payload, key: masterKey) else { return nil }
            return String(decoding: plaintext, as: UTF8.self)
        }

        if let plaintext = Self.decryptDPAPI(data: data) {
            return String(decoding: plaintext, as: UTF8.self)
        }

        return nil
    }

    private static func readLocalStateKey(databaseURL: URL) -> Data? {
        guard let localStateURL = localStateURL(for: databaseURL),
              let data = try? Data(contentsOf: localStateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let osCrypt = json["os_crypt"] as? [String: Any],
              let encryptedKeyBase64 = osCrypt["encrypted_key"] as? String,
              let encryptedKeyData = Data(
                base64Encoded: encryptedKeyBase64,
                options: .ignoreUnknownCharacters) else {
            return nil
        }

        var keyData = encryptedKeyData
        let dpapiPrefix = "DPAPI".data(using: .utf8) ?? Data()
        if keyData.starts(with: dpapiPrefix) {
            keyData = Data(keyData.dropFirst(dpapiPrefix.count))
        }

        guard let decrypted = decryptDPAPI(data: keyData) else { return nil }
        return decrypted.count == 32 ? decrypted : nil
    }

    private static func localStateURL(for databaseURL: URL) -> URL? {
        let parent = databaseURL.deletingLastPathComponent()
        let profileURL = parent.lastPathComponent == "Network" ? parent.deletingLastPathComponent() : parent
        let rootURL = profileURL.deletingLastPathComponent()
        let localStateURL = rootURL.appendingPathComponent("Local State")
        return FileManager.default.fileExists(atPath: localStateURL.path) ? localStateURL : nil
    }

    private static func decryptDPAPI(data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        var input = DATA_BLOB()
        var output = DATA_BLOB()
        let copied = [UInt8](data)

        return copied.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return nil }
            input.pbData = UnsafeMutablePointer<UInt8>(mutating: baseAddress.assumingMemoryBound(to: UInt8.self))
            input.cbData = UInt32(buffer.count)
            let result = CryptUnprotectData(
                &input,
                nil,
                nil,
                nil,
                nil,
                CRYPTPROTECT_UI_FORBIDDEN,
                &output)
            guard result != 0, let outData = output.pbData else {
                return nil
            }
            let decrypted = Data(bytes: outData, count: Int(output.cbData))
            LocalFree(UnsafeMutableRawPointer(outData))
            return decrypted
        }
    }
}
#endif
