struct UsageCommand {
    var verbose: Bool = false
    var json: Bool = false
    var pretty: Bool = false
    var noColor: Bool = false
    var provider: String?
    var format: String = "text"
}

struct CostCommand {
    var verbose: Bool = false
    var json: Bool = false
    var pretty: Bool = false
    var noColor: Bool = false
    var provider: String?
    var format: String = "text"
    var refresh: Bool = false
}

struct InsightsCommand {
    var json: Bool = false
    var pretty: Bool = false
    var noColor: Bool = false
    var provider: String?
    var view: String = "daily"
    var project: String?
    var timezone: String?
    var granularity: String?
    var gitDirectory: String?
    var budget: Bool = false
    var withCommits: Bool = false
}
