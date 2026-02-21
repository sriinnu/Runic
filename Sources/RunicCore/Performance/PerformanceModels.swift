import Foundation

// MARK: - Error Classification

public enum ErrorType: String, Codable, Sendable {
    case timeout
    case quota
    case auth
    case network
    case parsing
    case apiError
    case unknown
}

// MARK: - Quality Rating

/// User-submitted quality ratings for API responses
public struct QualityRating: Codable, Sendable, Identifiable {
    /// Unique identifier for this rating
    public let id: String

    /// Request ID linking this rating to a specific API call
    public let requestID: String

    /// Provider that handled the request
    public let provider: UsageProvider

    /// Model used for the request (if available)
    public let model: String?

    /// User rating on a scale of 1-5
    public let rating: Int

    /// Optional user comment about the response quality
    public let comment: String?

    /// When this rating was submitted
    public let timestamp: Date

    public init(
        id: String,
        requestID: String,
        provider: UsageProvider,
        model: String?,
        rating: Int,
        comment: String?,
        timestamp: Date)
    {
        self.id = id
        self.requestID = requestID
        self.provider = provider
        self.model = model
        self.rating = rating
        self.comment = comment
        self.timestamp = timestamp
    }
}

// MARK: - Latency Metric

/// API call timing metrics
public struct LatencyMetric: Codable, Sendable, Identifiable {
    /// Unique identifier for this metric
    public let id: String

    /// Unique request ID per API call
    public let requestID: String

    /// Provider that handled the request
    public let provider: UsageProvider

    /// Model used for the request (if available)
    public let model: String?

    /// When the API call started
    public let startTime: Date

    /// When the API call completed
    public let endTime: Date

    /// Duration of the API call in milliseconds
    public let durationMs: Int

    /// Whether the API call succeeded
    public let success: Bool

    /// When this metric was created
    public let createdAt: Date

    public init(
        id: String,
        requestID: String,
        provider: UsageProvider,
        model: String?,
        startTime: Date,
        endTime: Date,
        durationMs: Int,
        success: Bool,
        createdAt: Date)
    {
        self.id = id
        self.requestID = requestID
        self.provider = provider
        self.model = model
        self.startTime = startTime
        self.endTime = endTime
        self.durationMs = durationMs
        self.success = success
        self.createdAt = createdAt
    }
}

// MARK: - Error Event

/// API failure tracking
public struct ErrorEvent: Codable, Sendable, Identifiable {
    /// Unique identifier for this error event
    public let id: String

    /// Provider where the error occurred
    public let provider: UsageProvider

    /// Classification of the error type
    public let errorType: ErrorType

    /// Error message or description
    public let errorMessage: String?

    /// Number of retry attempts made
    public let retryCount: Int

    /// When this error occurred
    public let timestamp: Date

    public init(
        id: String,
        provider: UsageProvider,
        errorType: ErrorType,
        errorMessage: String?,
        retryCount: Int,
        timestamp: Date)
    {
        self.id = id
        self.provider = provider
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.retryCount = retryCount
        self.timestamp = timestamp
    }
}

// MARK: - Daily Performance Stats

/// Pre-aggregated daily performance statistics
public struct DailyPerformanceStats: Codable, Sendable, Identifiable {
    /// Computed identifier from provider-model-date
    public var id: String {
        let modelPart = model.map { "-\($0)" } ?? ""
        return "\(provider)\(modelPart)-\(date)"
    }

    /// Provider for these statistics
    public let provider: String

    /// Model for these statistics (if specific to a model)
    public let model: String?

    /// Date in YYYY-MM-DD format
    public let date: String

    /// Total number of API requests made
    public let totalRequests: Int

    /// Average latency in milliseconds
    public let avgLatencyMs: Int

    /// 50th percentile (median) latency in milliseconds
    public let p50LatencyMs: Int

    /// 95th percentile latency in milliseconds
    public let p95LatencyMs: Int

    /// 99th percentile latency in milliseconds
    public let p99LatencyMs: Int

    /// Average quality rating (1.0-5.0)
    public let avgQualityRating: Double

    /// Total number of quality ratings submitted
    public let totalRatings: Int

    /// Count of 1-star ratings
    public let rating1Count: Int

    /// Count of 2-star ratings
    public let rating2Count: Int

    /// Count of 3-star ratings
    public let rating3Count: Int

    /// Count of 4-star ratings
    public let rating4Count: Int

    /// Count of 5-star ratings
    public let rating5Count: Int

    /// Total number of errors
    public let errorCount: Int

    /// Error rate as a percentage (0.0-1.0)
    public let errorRate: Double

    /// Count of timeout errors
    public let timeoutCount: Int

    /// Count of quota/rate limit errors
    public let quotaCount: Int

    /// Count of network errors
    public let networkCount: Int

    /// Count of API errors
    public let apiErrorCount: Int

    /// When these statistics were created
    public let createdAt: Date

    public init(
        provider: String,
        model: String?,
        date: String,
        totalRequests: Int,
        avgLatencyMs: Int,
        p50LatencyMs: Int,
        p95LatencyMs: Int,
        p99LatencyMs: Int,
        avgQualityRating: Double,
        totalRatings: Int,
        rating1Count: Int,
        rating2Count: Int,
        rating3Count: Int,
        rating4Count: Int,
        rating5Count: Int,
        errorCount: Int,
        errorRate: Double,
        timeoutCount: Int,
        quotaCount: Int,
        networkCount: Int,
        apiErrorCount: Int,
        createdAt: Date)
    {
        self.provider = provider
        self.model = model
        self.date = date
        self.totalRequests = totalRequests
        self.avgLatencyMs = avgLatencyMs
        self.p50LatencyMs = p50LatencyMs
        self.p95LatencyMs = p95LatencyMs
        self.p99LatencyMs = p99LatencyMs
        self.avgQualityRating = avgQualityRating
        self.totalRatings = totalRatings
        self.rating1Count = rating1Count
        self.rating2Count = rating2Count
        self.rating3Count = rating3Count
        self.rating4Count = rating4Count
        self.rating5Count = rating5Count
        self.errorCount = errorCount
        self.errorRate = errorRate
        self.timeoutCount = timeoutCount
        self.quotaCount = quotaCount
        self.networkCount = networkCount
        self.apiErrorCount = apiErrorCount
        self.createdAt = createdAt
    }
}

// MARK: - Helper Extensions

extension QualityRating {
    /// Creates a new quality rating with a generated UUID
    public static func create(
        requestID: String,
        provider: UsageProvider,
        model: String?,
        rating: Int,
        comment: String?,
        timestamp: Date = Date()) -> QualityRating
    {
        QualityRating(
            id: UUID().uuidString,
            requestID: requestID,
            provider: provider,
            model: model,
            rating: rating,
            comment: comment,
            timestamp: timestamp)
    }

    /// Validates that the rating is within acceptable bounds (1-5)
    public var isValid: Bool {
        rating >= 1 && rating <= 5
    }
}

extension LatencyMetric {
    /// Creates a new latency metric with a generated UUID
    public static func create(
        requestID: String,
        provider: UsageProvider,
        model: String?,
        startTime: Date,
        endTime: Date,
        success: Bool) -> LatencyMetric
    {
        let duration = Int(endTime.timeIntervalSince(startTime) * 1000)
        return LatencyMetric(
            id: UUID().uuidString,
            requestID: requestID,
            provider: provider,
            model: model,
            startTime: startTime,
            endTime: endTime,
            durationMs: duration,
            success: success,
            createdAt: Date())
    }

    /// Computed duration in seconds
    public var durationSeconds: Double {
        Double(durationMs) / 1000.0
    }
}

extension ErrorEvent {
    /// Creates a new error event with a generated UUID
    public static func create(
        provider: UsageProvider,
        errorType: ErrorType,
        errorMessage: String?,
        retryCount: Int,
        timestamp: Date = Date()) -> ErrorEvent
    {
        ErrorEvent(
            id: UUID().uuidString,
            provider: provider,
            errorType: errorType,
            errorMessage: errorMessage,
            retryCount: retryCount,
            timestamp: timestamp)
    }
}

extension DailyPerformanceStats {
    /// Creates a date string in YYYY-MM-DD format
    public static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Parses a date string in YYYY-MM-DD format
    public static func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}
