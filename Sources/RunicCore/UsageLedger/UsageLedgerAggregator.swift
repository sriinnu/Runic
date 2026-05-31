import Foundation

public enum UsageLedgerAggregator {
    struct DailyKey: Hashable {
        let provider: UsageProvider
        let projectID: String?
        let dayStart: Date
    }

    struct SessionKey: Hashable {
        let provider: UsageProvider
        let projectID: String?
        let sessionID: String
    }

    struct BlockKey: Hashable {
        let provider: UsageProvider
        let projectID: String?
        let sessionID: String?
    }

    struct ModelKey: Hashable {
        let provider: UsageProvider
        let projectKey: String?
        let model: String
    }

    struct ProjectKey: Hashable {
        let provider: UsageProvider
        let projectKey: String?
    }

    struct HourlyKey: Hashable {
        let provider: UsageProvider
        let projectID: String?
        let hourStart: Date
    }

    struct SpendForecastKey: Hashable {
        let provider: UsageProvider
        let projectKey: String?
    }

    struct CompactionKey: Hashable {
        let provider: UsageProvider
    }

    static func calendarFor(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func dayKeyString(from date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = self.calendarFor(timeZone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func hourKeyString(from date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = self.calendarFor(timeZone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:00:00"
        return formatter.string(from: date)
    }
}
