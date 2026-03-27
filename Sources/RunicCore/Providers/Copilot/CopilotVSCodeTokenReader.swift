import Foundation

#if os(macOS)
import CommonCrypto
import LocalAuthentication
import Security
import SQLite3
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum CopilotVSCodeTokenReader {
    private struct VSCodeStoreCandidate {
        let databaseURL: URL
        let safeStorageService: String
    }

    private static let githubAuthSecretKey = "secret://{\"extensionId\":\"vscode.github-authentication\",\"key\":\"github.auth\"}"
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private static let pbkdf2Salt = Data("saltysalt".utf8)
    private static let pbkdf2Iterations: UInt32 = 1003
    private static let legacyKeyLength = kCCKeySizeAES128
    private static let log = RunicLog.logger("copilot-vscode-token")

    public static func token(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        allowUserInteraction: Bool = false) -> String?
    {
        for candidate in self.candidateStores(environment: environment) {
            guard let secretValue = self.readSecretValue(from: candidate.databaseURL) else {
                continue
            }
            guard let encryptedPayload = self.normalizeEncryptedPayload(secretValue) else {
                continue
            }
            guard let password = self.readSafeStoragePassword(
                service: candidate.safeStorageService,
                allowUserInteraction: allowUserInteraction),
                let legacyKey = self.deriveLegacyKey(from: password),
                let decryptedJSON = self.decryptSecretPayload(encryptedPayload, legacyKey: legacyKey),
                let token = self.extractToken(fromDecryptedJSON: decryptedJSON)
            else {
                continue
            }
            return token
        }
        return nil
    }

    private static func candidateStores(environment: [String: String]) -> [VSCodeStoreCandidate] {
        let appVariants: [(appName: String, service: String)] = [
            ("Code", "Code Safe Storage"),
            ("Code - Insiders", "Code - Insiders Safe Storage"),
            ("VSCodium", "VSCodium Safe Storage"),
            ("Code - OSS", "Code - OSS Safe Storage"),
        ]

        var stores: [VSCodeStoreCandidate] = []
        for home in self.candidateHomes(environment: environment) {
            let appSupport = home
                .appendingPathComponent("Library")
                .appendingPathComponent("Application Support")
            for variant in appVariants {
                let globalStorage = appSupport
                    .appendingPathComponent(variant.appName)
                    .appendingPathComponent("User")
                    .appendingPathComponent("globalStorage")

                let dbURL = globalStorage.appendingPathComponent("state.vscdb")
                if FileManager.default.fileExists(atPath: dbURL.path) {
                    stores.append(VSCodeStoreCandidate(databaseURL: dbURL, safeStorageService: variant.service))
                }

                let backupURL = globalStorage.appendingPathComponent("state.vscdb.backup")
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    stores.append(VSCodeStoreCandidate(databaseURL: backupURL, safeStorageService: variant.service))
                }
            }
        }
        return stores
    }

    private static func candidateHomes(environment: [String: String]) -> [URL] {
        var homes: [URL] = [FileManager.default.homeDirectoryForCurrentUser]
        if let userHome = NSHomeDirectoryForUser(NSUserName()) {
            homes.append(URL(fileURLWithPath: userHome))
        }
        if let envHome = environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envHome.isEmpty
        {
            homes.append(URL(fileURLWithPath: envHome))
        }

        var seen = Set<String>()
        return homes.filter { home in
            let path = home.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }

    private static func readSecretValue(from databaseURL: URL) -> Data? {
        var db: OpaquePointer?
        let openStatus = sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard openStatus == SQLITE_OK, let db else { return nil }
        defer { sqlite3_close(db) }

        let sql = "SELECT value FROM ItemTable WHERE key = ?1 LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (self.githubAuthSecretKey as NSString).utf8String, -1, self.sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

        let columnType = sqlite3_column_type(statement, 0)
        let byteCount = Int(sqlite3_column_bytes(statement, 0))
        guard byteCount > 0 else { return nil }

        switch columnType {
        case SQLITE_TEXT:
            guard let ptr = sqlite3_column_text(statement, 0) else { return nil }
            return Data(bytes: ptr, count: byteCount)
        case SQLITE_BLOB:
            guard let ptr = sqlite3_column_blob(statement, 0) else { return nil }
            return Data(bytes: ptr, count: byteCount)
        default:
            return nil
        }
    }

    private static func normalizeEncryptedPayload(_ valueData: Data) -> Data? {
        if valueData.count >= 3 {
            let prefix = valueData.prefix(3)
            if prefix == Data("v10".utf8) || prefix == Data("v11".utf8) {
                return valueData
            }
        }

        guard let decoded = try? JSONSerialization.jsonObject(with: valueData) as? [String: Any] else {
            guard let text = String(data: valueData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            else {
                return nil
            }
            if let base64 = Data(base64Encoded: text), !base64.isEmpty {
                return base64
            }
            return nil
        }

        guard let type = decoded["type"] as? String,
              type == "Buffer",
              let bufferData = decoded["data"] as? [Any]
        else {
            return nil
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(bufferData.count)
        for item in bufferData {
            guard let number = item as? NSNumber else { return nil }
            let value = number.intValue
            guard (0...255).contains(value) else { return nil }
            bytes.append(UInt8(value))
        }
        return bytes.isEmpty ? nil : Data(bytes)
    }

    private static func readSafeStoragePassword(service: String, allowUserInteraction: Bool) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        if allowUserInteraction {
            query[kSecUseAuthenticationUI as String] = "kSecUseAuthenticationUIAllow" as CFString
        } else {
            query[kSecUseAuthenticationUI as String] = "kSecUseAuthenticationUIFail" as CFString
            let authContext = LAContext()
            authContext.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = authContext
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func deriveLegacyKey(from password: String) -> Data? {
        let passwordBytes = Array(password.utf8)
        var key = Data(count: self.legacyKeyLength)
        let status = key.withUnsafeMutableBytes { keyBytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes,
                passwordBytes.count,
                [UInt8](self.pbkdf2Salt),
                self.pbkdf2Salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                self.pbkdf2Iterations,
                keyBytes.bindMemory(to: UInt8.self).baseAddress,
                self.legacyKeyLength)
        }
        guard status == kCCSuccess else { return nil }
        return key
    }

    private static func decryptSecretPayload(_ payload: Data, legacyKey: Data) -> String? {
        let encryptedPayload: Data = if payload.count >= 3,
                                        let prefix = String(data: payload.prefix(3), encoding: .utf8),
                                        prefix == "v10" || prefix == "v11"
        {
            Data(payload.dropFirst(3))
        } else {
            payload
        }

        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        if let cbc = self.decryptAESCBC(payload: encryptedPayload, key: legacyKey, iv: iv),
           let text = String(data: cbc, encoding: .utf8),
           !text.isEmpty
        {
            return text
        }

        if let gcm = self.decryptAESGCM(payload: encryptedPayload, key: legacyKey),
           let text = String(data: gcm, encoding: .utf8),
           !text.isEmpty
        {
            return text
        }

        return nil
    }

    private static func decryptAESCBC(payload: Data, key: Data, iv: Data) -> Data? {
        var outputLength: size_t = 0
        var output = Data(count: payload.count + kCCBlockSizeAES128)
        let outputCapacity = output.count
        let status = output.withUnsafeMutableBytes { outputBytes in
            payload.withUnsafeBytes { payloadBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            payloadBytes.baseAddress,
                            payload.count,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength)
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        output.removeSubrange(outputLength..<output.count)
        return output
    }

    private static func decryptAESGCM(payload: Data, key: Data) -> Data? {
        #if canImport(CryptoKit)
        guard payload.count >= 12 + 16 else { return nil }
        do {
            let nonce = try AES.GCM.Nonce(data: payload.prefix(12))
            let ciphertext = payload.dropFirst(12).dropLast(16)
            let tag = payload.suffix(16)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(sealedBox, using: SymmetricKey(data: key))
        } catch {
            self.log.debug("GCM decrypt failed: \(error.localizedDescription)")
            return nil
        }
        #else
        _ = payload
        _ = key
        return nil
        #endif
    }

    private static func extractToken(fromDecryptedJSON decryptedJSON: String) -> String? {
        guard let data = decryptedJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }
        return self.extractToken(fromJSONNode: root)
    }

    private static func extractToken(fromJSONNode node: Any) -> String? {
        if let dictionary = node as? [String: Any] {
            let directKeys = ["accessToken", "access_token", "oauthToken", "token"]
            for key in directKeys {
                if let token = self.validToken(dictionary[key] as? String) {
                    return token
                }
            }

            for value in dictionary.values {
                if value is [String: Any] || value is [Any] {
                    if let token = self.extractToken(fromJSONNode: value) {
                        return token
                    }
                }
            }
            return nil
        }

        if let array = node as? [Any] {
            for entry in array {
                if let token = self.extractToken(fromJSONNode: entry) {
                    return token
                }
            }
        }
        return nil
    }

    private static func validToken(_ raw: String?) -> String? {
        guard let token = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return nil
        }
        guard !token.contains(where: \.isWhitespace), token.count >= 20 else {
            return nil
        }

        let knownPrefixes = ["gho_", "ghp_", "ghu_", "ghs_", "github_pat_", "v1."]
        if knownPrefixes.contains(where: token.hasPrefix) {
            return token
        }

        if token.range(of: #"^[A-Za-z0-9._=-]{20,}$"#, options: .regularExpression) != nil {
            return token
        }
        return nil
    }
}

#else
public enum CopilotVSCodeTokenReader {
    public static func token(
        environment _: [String: String] = ProcessInfo.processInfo.environment,
        allowUserInteraction _: Bool = false) -> String?
    {
        nil
    }
}
#endif

#if DEBUG
extension CopilotVSCodeTokenReader {
    static func _normalizedPayloadForTesting(_ valueData: Data) -> Data? {
        #if os(macOS)
        self.normalizeEncryptedPayload(valueData)
        #else
        _ = valueData
        return nil
        #endif
    }

    static func _extractTokenFromDecryptedJSONForTesting(_ decryptedJSON: String) -> String? {
        #if os(macOS)
        self.extractToken(fromDecryptedJSON: decryptedJSON)
        #else
        _ = decryptedJSON
        return nil
        #endif
    }
}
#endif
