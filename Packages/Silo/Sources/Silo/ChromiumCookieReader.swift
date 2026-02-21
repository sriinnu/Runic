import Foundation
import SQLite3

/// Shared Chromium cookie reader for all platforms.
/// Platform-specific decryptors are injected via `ChromiumCookieDecrypting`.
protocol ChromiumCookieDecrypting: Sendable {
    var hasKey: Bool { get }
    func decrypt(data: Data) -> String?
}

/// Reads Chromium-based cookie stores and returns normalized cookie records.
struct ChromiumCookieReader {
    func readCookies(
        store: BrowserCookieStore,
        browser: Browser,
        decryptor: ChromiumCookieDecrypting,
        decryptionFailurePolicy: BrowserCookieDecryptionFailurePolicy,
        requireKeyForEncrypted: Bool) throws -> [BrowserCookieRecord]
    {
        guard let databaseURL = store.databaseURL else {
            throw BrowserCookieError.notFound(
                browser: browser,
                details: "Missing cookie database URL.")
        }

        let snapshot = SQLiteSnapshot.prepare(from: databaseURL)
        defer { snapshot.cleanup() }

        var db: OpaquePointer?
        if sqlite3_open_v2(snapshot.readURL.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            throw BrowserCookieError.loadFailed(
                browser: browser,
                details: "Unable to open cookies database.")
        }
        defer { sqlite3_close(db) }

        let availableColumns = Self.fetchColumns(db: db, table: "cookies")
        let select = Self.selectColumns(available: availableColumns)
        let query = "SELECT \(select.columns.joined(separator: ", ")) FROM cookies"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw BrowserCookieError.loadFailed(
                browser: browser,
                details: "Unable to read cookies table.")
        }
        defer { sqlite3_finalize(statement) }

        let index = select.index
        let partitionKeyColumn = select.partitionKeyColumn
        var records: [BrowserCookieRecord] = []
        var usedEncryptedValues = false
        var failedDecryptions = 0

        while sqlite3_step(statement) == SQLITE_ROW {
            let hostKey = columnText(statement, index["host_key"] ?? 0) ?? ""
            let name = columnText(statement, index["name"] ?? 1) ?? ""
            let path = columnText(statement, index["path"] ?? 2) ?? ""
            let value = columnText(statement, index["value"] ?? 3) ?? ""
            let encrypted = columnBlob(statement, index["encrypted_value"] ?? 4)
            let encryptedLength = columnBlobLength(statement, index["encrypted_value"] ?? 4)
            let expiresUtc = columnInt64(statement, index["expires_utc"] ?? 5) ?? 0
            let isSecure = (columnInt(statement, index["is_secure"] ?? 6) ?? 0) != 0
            let isHttpOnly = (columnInt(statement, index["is_httponly"] ?? 7) ?? 0) != 0
            let sameSiteValue = columnInt(statement, index["samesite"] ?? 8) ?? 0

            let decryptedValue: String
            if value.isEmpty, let encrypted = encrypted, encryptedLength > 0 {
                usedEncryptedValues = true
                let data = Data(bytes: encrypted, count: encryptedLength)
                if let decrypted = decryptor.decrypt(data: data) {
                    decryptedValue = decrypted
                } else {
                    failedDecryptions += 1
                    continue
                }
            } else {
                decryptedValue = value
            }

            if hostKey.isEmpty || name.isEmpty {
                continue
            }

            let expires = Self.date(fromChromiumTimestamp: expiresUtc)
            let sameSite = Self.sameSite(from: sameSiteValue)
            let createdAt = columnInt64(statement, index["creation_utc"]).flatMap(Self.date(fromChromiumTimestamp:))
            let lastAccessedAt = columnInt64(statement, index["last_access_utc"]).flatMap(Self.date(fromChromiumTimestamp:))
            let priorityValue = columnInt(statement, index["priority"]).map { Int($0) }
            let priority = priorityValue.map(BrowserCookiePriority.init(rawValue:))
            let isSameParty = columnInt(statement, index["is_same_party"]).map { $0 != 0 }
            let partitionKey = partitionKeyColumn.flatMap { columnText(statement, index[$0]) }

            records.append(BrowserCookieRecord(
                domain: hostKey,
                name: name,
                path: path.isEmpty ? "/" : path,
                value: decryptedValue,
                expires: expires,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
                isSecure: isSecure,
                isHTTPOnly: isHttpOnly,
                sameSite: sameSite,
                priority: priority,
                partitionKey: partitionKey,
                isSameParty: isSameParty))
        }

        if usedEncryptedValues, requireKeyForEncrypted, !decryptor.hasKey {
            throw BrowserCookieError.accessDenied(
                browser: browser,
                details: "Keychain access required to decrypt cookies.")
        }

        if failedDecryptions > 0 {
            if decryptionFailurePolicy == .strict {
                throw BrowserCookieError.loadFailed(
                    browser: browser,
                    details: "Failed to decrypt \(failedDecryptions) cookie value(s).")
            }
            if usedEncryptedValues, records.isEmpty {
                throw BrowserCookieError.loadFailed(
                    browser: browser,
                    details: "Unable to decrypt cookie values.")
            }
        }

        return records
    }

    static func date(fromChromiumTimestamp timestamp: Int64) -> Date? {
        guard timestamp > 0 else { return nil }
        let seconds = Double(timestamp) / 1_000_000
        return chromiumEpoch.addingTimeInterval(seconds)
    }

    static func sameSite(from value: Int32) -> BrowserCookieSameSite? {
        switch value {
        case 1:
            return .lax
        case 2:
            return .strict
        case 3:
            return BrowserCookieSameSite.none
        default:
            return nil
        }
    }

    private static let chromiumEpoch: Date = {
        var components = DateComponents()
        components.year = 1601
        components.month = 1
        components.day = 1
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return components.date ?? Date(timeIntervalSince1970: 0)
    }()

    private struct ChromiumSelect {
        let columns: [String]
        let index: [String: Int]
        let partitionKeyColumn: String?
    }

    private static func fetchColumns(db: OpaquePointer?, table: String) -> Set<String> {
        guard let db else { return [] }
        var columns = Set<String>()
        let query = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let name = sqlite3_column_text(statement, 1) {
                    columns.insert(String(cString: name))
                }
            }
        }
        sqlite3_finalize(statement)
        return columns
    }

    private static func selectColumns(available: Set<String>) -> ChromiumSelect {
        var columns = [
            "host_key",
            "name",
            "path",
            "value",
            "encrypted_value",
            "expires_utc",
            "is_secure",
            "is_httponly",
            "samesite",
        ]

        for name in ["creation_utc", "last_access_utc", "priority", "is_same_party"] {
            if available.contains(name) {
                columns.append(name)
            }
        }

        var partitionKeyColumn: String?
        if available.contains("partition_key") {
            partitionKeyColumn = "partition_key"
            columns.append("partition_key")
        } else if available.contains("top_frame_site_key") {
            partitionKeyColumn = "top_frame_site_key"
            columns.append("top_frame_site_key")
        }

        let index = Dictionary(uniqueKeysWithValues: columns.enumerated().map { ($1, $0) })
        return ChromiumSelect(columns: columns, index: index, partitionKeyColumn: partitionKeyColumn)
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int?) -> String? {
        guard let index, sqlite3_column_type(statement, Int32(index)) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, Int32(index)) else {
            return nil
        }
        let value = String(cString: text)
        return value.isEmpty ? nil : value
    }

    private func columnInt(_ statement: OpaquePointer?, _ index: Int?) -> Int32? {
        guard let index, sqlite3_column_type(statement, Int32(index)) != SQLITE_NULL else { return nil }
        return sqlite3_column_int(statement, Int32(index))
    }

    private func columnInt64(_ statement: OpaquePointer?, _ index: Int?) -> Int64? {
        guard let index, sqlite3_column_type(statement, Int32(index)) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(statement, Int32(index))
    }

    private func columnBlob(_ statement: OpaquePointer?, _ index: Int) -> UnsafeRawPointer? {
        sqlite3_column_blob(statement, Int32(index))
    }

    private func columnBlobLength(_ statement: OpaquePointer?, _ index: Int) -> Int {
        Int(sqlite3_column_bytes(statement, Int32(index)))
    }
}
