import Foundation
import SQLite3

/// Shared Firefox cookie reader for all platforms.
struct FirefoxCookieReader {
    func readCookies(store: BrowserCookieStore) throws -> [BrowserCookieRecord] {
        guard let databaseURL = store.databaseURL else {
            throw BrowserCookieError.notFound(
                browser: store.browser,
                details: "Missing cookie database URL.")
        }
        let snapshot = SQLiteSnapshot.prepare(from: databaseURL)
        defer { snapshot.cleanup() }

        var db: OpaquePointer?
        if sqlite3_open_v2(snapshot.readURL.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            throw BrowserCookieError.loadFailed(
                browser: store.browser,
                details: "Unable to open cookies database.")
        }
        defer { sqlite3_close(db) }

        let availableColumns = Self.fetchColumns(db: db, table: "moz_cookies")
        let hostOnlyColumn = Self.hostOnlyColumn(in: availableColumns)
        let selectColumns = Self.selectColumns(hostOnlyColumn: hostOnlyColumn, available: availableColumns)
        let query = "SELECT \(selectColumns.joined(separator: ", ")) FROM moz_cookies"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw BrowserCookieError.loadFailed(
                browser: store.browser,
                details: "Unable to read cookies table.")
        }
        defer { sqlite3_finalize(statement) }

        let index = Dictionary(uniqueKeysWithValues: selectColumns.enumerated().map { ($1, $0) })
        let hostOnlyIndex = hostOnlyColumn.flatMap { index[$0] }
        var records: [BrowserCookieRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let host = columnText(statement, index["host"] ?? 0) ?? ""
            let name = columnText(statement, index["name"] ?? 1) ?? ""
            let path = columnText(statement, index["path"] ?? 2) ?? ""
            let value = columnText(statement, index["value"] ?? 3) ?? ""
            let expirySeconds = columnInt64(statement, index["expiry"] ?? 4) ?? 0
            let isSecure = (columnInt(statement, index["isSecure"] ?? 5) ?? 0) != 0
            let isHttpOnly = (columnInt(statement, index["isHttpOnly"] ?? 6) ?? 0) != 0
            let sameSiteValue = columnInt(statement, index["sameSite"] ?? 7) ?? 0
            let isHostOnlyOverride: Bool?
            if hostOnlyColumn == "isHostOnly", let index = hostOnlyIndex {
                isHostOnlyOverride = (columnInt(statement, index) ?? 0) != 0
            } else if hostOnlyColumn == "isDomain", let index = hostOnlyIndex {
                let isDomain = (columnInt(statement, index) ?? 0) != 0
                isHostOnlyOverride = !isDomain
            } else {
                isHostOnlyOverride = nil
            }

            if host.isEmpty || name.isEmpty {
                continue
            }

            let expires = expirySeconds > 0 ? Date(timeIntervalSince1970: Double(expirySeconds)) : nil
            let sameSite = Self.sameSite(from: sameSiteValue)
            let createdAt = columnInt64(statement, index["creationTime"]).flatMap(Self.date(fromFirefoxTimestamp:))
            let lastAccessedAt = columnInt64(statement, index["lastAccessed"]).flatMap(Self.date(fromFirefoxTimestamp:))
            let priorityValue = columnInt(statement, index["priority"]).map { Int($0) }
            let priority = priorityValue.map(BrowserCookiePriority.init(rawValue:))
            let partitionKey = columnText(statement, index["partitionKey"])
            let isSameParty = columnInt(statement, index["isSameParty"]).map { $0 != 0 }

            records.append(BrowserCookieRecord(
                domain: host,
                name: name,
                path: path.isEmpty ? "/" : path,
                value: value,
                expires: expires,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
                isSecure: isSecure,
                isHTTPOnly: isHttpOnly,
                isHostOnly: isHostOnlyOverride,
                sameSite: sameSite,
                priority: priority,
                partitionKey: partitionKey,
                isSameParty: isSameParty))
        }

        return records
    }

    private static func sameSite(from value: Int32) -> BrowserCookieSameSite? {
        switch value {
        case 0:
            return BrowserCookieSameSite.none
        case 1:
            return .lax
        case 2:
            return .strict
        default:
            return nil
        }
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

    private static func hostOnlyColumn(in columns: Set<String>) -> String? {
        if columns.contains("isHostOnly") {
            return "isHostOnly"
        }
        if columns.contains("isDomain") {
            return "isDomain"
        }
        return nil
    }

    private static func selectColumns(hostOnlyColumn: String?, available: Set<String>) -> [String] {
        var columns = [
            "host",
            "name",
            "path",
            "value",
            "expiry",
            "isSecure",
            "isHttpOnly",
            "sameSite",
        ]
        if let hostOnlyColumn {
            columns.append(hostOnlyColumn)
        }
        for name in ["creationTime", "lastAccessed", "priority", "partitionKey", "isSameParty"] where available.contains(name) {
            columns.append(name)
        }
        return columns
    }

    private static func date(fromFirefoxTimestamp timestamp: Int64) -> Date? {
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(timestamp) / 1_000_000)
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
}
