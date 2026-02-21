import Foundation
import SQLite3

/// Storage layer for performance metrics using SQLite
public final class PerformanceStorageImpl {

    // MARK: - Properties

    private var db: OpaquePointer?
    private let dbPath: URL

    // MARK: - Initialization

    public init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let runicDir = appSupport.appendingPathComponent("Runic")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: runicDir, withIntermediateDirectories: true)

        self.dbPath = runicDir.appendingPathComponent("performance.db")
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Connection

    private func open() throws {
        guard db == nil else { return }

        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(dbPath.path, &db, flags, nil)

        guard result == SQLITE_OK else {
            throw StorageError.openFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        try createTablesIfNeeded()
    }

    private func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    // MARK: - Schema Creation

    private func createTablesIfNeeded() throws {
        let schemas = [
            """
            CREATE TABLE IF NOT EXISTS latency_metrics (
                id TEXT PRIMARY KEY,
                request_id TEXT NOT NULL,
                provider TEXT NOT NULL,
                model TEXT,
                start_time REAL NOT NULL,
                end_time REAL NOT NULL,
                duration_ms INTEGER NOT NULL,
                success INTEGER NOT NULL,
                created_at REAL NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS quality_ratings (
                id TEXT PRIMARY KEY,
                request_id TEXT NOT NULL,
                provider TEXT NOT NULL,
                model TEXT,
                rating INTEGER NOT NULL,
                comment TEXT,
                timestamp REAL NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS error_events (
                id TEXT PRIMARY KEY,
                provider TEXT NOT NULL,
                error_type TEXT NOT NULL,
                error_message TEXT,
                retry_count INTEGER NOT NULL,
                timestamp REAL NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS daily_stats (
                provider TEXT NOT NULL,
                model TEXT,
                date TEXT NOT NULL,
                total_requests INTEGER NOT NULL,
                avg_latency_ms INTEGER NOT NULL,
                p50_latency_ms INTEGER NOT NULL,
                p95_latency_ms INTEGER NOT NULL,
                p99_latency_ms INTEGER NOT NULL,
                avg_quality_rating REAL NOT NULL,
                total_ratings INTEGER NOT NULL,
                rating_1_count INTEGER NOT NULL,
                rating_2_count INTEGER NOT NULL,
                rating_3_count INTEGER NOT NULL,
                rating_4_count INTEGER NOT NULL,
                rating_5_count INTEGER NOT NULL,
                error_count INTEGER NOT NULL,
                error_rate REAL NOT NULL,
                timeout_count INTEGER NOT NULL,
                quota_count INTEGER NOT NULL,
                network_count INTEGER NOT NULL,
                api_error_count INTEGER NOT NULL,
                created_at REAL NOT NULL,
                PRIMARY KEY (provider, model, date)
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_latency_created ON latency_metrics(created_at)",
            "CREATE INDEX IF NOT EXISTS idx_quality_timestamp ON quality_ratings(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_error_timestamp ON error_events(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_stats(date)"
        ]

        for schema in schemas {
            try execute(schema)
        }
    }

    // MARK: - Execute SQL

    private func execute(_ sql: String) throws {
        guard let db = db else {
            throw StorageError.notOpen
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)

        if result != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw StorageError.executionFailed(message: message)
        }
    }

    // MARK: - Save Metrics

    public func save(latency: LatencyMetric) async throws {
        try open()

        let sql = """
            INSERT OR REPLACE INTO latency_metrics
            (id, request_id, provider, model, start_time, end_time, duration_ms, success, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, latency.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, latency.requestID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 3, latency.provider.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        if let model = latency.model {
            sqlite3_bind_text(statement, 4, model, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 4)
        }

        sqlite3_bind_double(statement, 5, latency.startTime.timeIntervalSince1970)
        sqlite3_bind_double(statement, 6, latency.endTime.timeIntervalSince1970)
        sqlite3_bind_int(statement, 7, Int32(latency.durationMs))
        sqlite3_bind_int(statement, 8, latency.success ? 1 : 0)
        sqlite3_bind_double(statement, 9, latency.createdAt.timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.insertFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    public func save(rating: QualityRating) async throws {
        try open()

        let sql = """
            INSERT OR REPLACE INTO quality_ratings
            (id, request_id, provider, model, rating, comment, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, rating.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, rating.requestID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 3, rating.provider.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        if let model = rating.model {
            sqlite3_bind_text(statement, 4, model, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 4)
        }

        sqlite3_bind_int(statement, 5, Int32(rating.rating))

        if let comment = rating.comment {
            sqlite3_bind_text(statement, 6, comment, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 6)
        }

        sqlite3_bind_double(statement, 7, rating.timestamp.timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.insertFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    public func save(error: ErrorEvent) async throws {
        try open()

        let sql = """
            INSERT OR REPLACE INTO error_events
            (id, provider, error_type, error_message, retry_count, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, error.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, error.provider.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 3, error.errorType.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        if let message = error.errorMessage {
            sqlite3_bind_text(statement, 4, message, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 4)
        }

        sqlite3_bind_int(statement, 5, Int32(error.retryCount))
        sqlite3_bind_double(statement, 6, error.timestamp.timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.insertFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Fetch Daily Stats

    public func fetchDailyStats(
        timeRange: Int,
        provider: UsageProvider? = nil,
        model: String? = nil
    ) async throws -> [DailyPerformanceStats] {
        try open()

        var sql = "SELECT * FROM daily_stats WHERE date >= date('now', '-\(timeRange) days')"

        if let provider = provider {
            sql += " AND provider = '\(provider.rawValue)'"
        }

        if let model = model {
            sql += " AND model = '\(model)'"
        }

        sql += " ORDER BY date DESC"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        var stats: [DailyPerformanceStats] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let provider = String(cString: sqlite3_column_text(statement, 0))
            let model = sqlite3_column_type(statement, 1) == SQLITE_NULL
                ? nil
                : String(cString: sqlite3_column_text(statement, 1))
            let date = String(cString: sqlite3_column_text(statement, 2))
            let totalRequests = Int(sqlite3_column_int(statement, 3))
            let avgLatencyMs = Int(sqlite3_column_int(statement, 4))
            let p50LatencyMs = Int(sqlite3_column_int(statement, 5))
            let p95LatencyMs = Int(sqlite3_column_int(statement, 6))
            let p99LatencyMs = Int(sqlite3_column_int(statement, 7))
            let avgQualityRating = sqlite3_column_double(statement, 8)
            let totalRatings = Int(sqlite3_column_int(statement, 9))
            let rating1Count = Int(sqlite3_column_int(statement, 10))
            let rating2Count = Int(sqlite3_column_int(statement, 11))
            let rating3Count = Int(sqlite3_column_int(statement, 12))
            let rating4Count = Int(sqlite3_column_int(statement, 13))
            let rating5Count = Int(sqlite3_column_int(statement, 14))
            let errorCount = Int(sqlite3_column_int(statement, 15))
            let errorRate = sqlite3_column_double(statement, 16)
            let timeoutCount = Int(sqlite3_column_int(statement, 17))
            let quotaCount = Int(sqlite3_column_int(statement, 18))
            let networkCount = Int(sqlite3_column_int(statement, 19))
            let apiErrorCount = Int(sqlite3_column_int(statement, 20))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 21))

            let stat = DailyPerformanceStats(
                provider: provider,
                model: model,
                date: date,
                totalRequests: totalRequests,
                avgLatencyMs: avgLatencyMs,
                p50LatencyMs: p50LatencyMs,
                p95LatencyMs: p95LatencyMs,
                p99LatencyMs: p99LatencyMs,
                avgQualityRating: avgQualityRating,
                totalRatings: totalRatings,
                rating1Count: rating1Count,
                rating2Count: rating2Count,
                rating3Count: rating3Count,
                rating4Count: rating4Count,
                rating5Count: rating5Count,
                errorCount: errorCount,
                errorRate: errorRate,
                timeoutCount: timeoutCount,
                quotaCount: quotaCount,
                networkCount: networkCount,
                apiErrorCount: apiErrorCount,
                createdAt: createdAt
            )

            stats.append(stat)
        }

        return stats
    }

    // MARK: - Database Maintenance

    public func vacuum() async throws {
        try open()
        try execute("VACUUM")
    }

    public func deleteOldData(olderThan days: Int) async throws {
        try open()

        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        let cutoffTimestamp = cutoffDate.timeIntervalSince1970

        let queries = [
            "DELETE FROM latency_metrics WHERE created_at < \(cutoffTimestamp)",
            "DELETE FROM quality_ratings WHERE timestamp < \(cutoffTimestamp)",
            "DELETE FROM error_events WHERE timestamp < \(cutoffTimestamp)"
        ]

        for query in queries {
            try execute(query)
        }
    }

    // MARK: - Error Types

    public enum StorageError: Error, LocalizedError {
        case notOpen
        case openFailed(message: String)
        case prepareFailed(message: String)
        case executionFailed(message: String)
        case insertFailed(message: String)

        public var errorDescription: String? {
            switch self {
            case .notOpen:
                return "Database not open"
            case .openFailed(let message):
                return "Failed to open database: \(message)"
            case .prepareFailed(let message):
                return "Failed to prepare statement: \(message)"
            case .executionFailed(let message):
                return "Failed to execute statement: \(message)"
            case .insertFailed(let message):
                return "Failed to insert data: \(message)"
            }
        }
    }
}

// MARK: - Helper Extensions

extension String {
    fileprivate init(cString pointer: UnsafePointer<UInt8>?) {
        guard let pointer = pointer else {
            self = ""
            return
        }
        self = String(cString: pointer)
    }
}
