import Foundation

enum RefreshFrequency: String, CaseIterable, Identifiable {
    case manual
    case oneMinute
    case twoMinutes
    case fiveMinutes
    case fifteenMinutes

    var id: String {
        self.rawValue
    }

    var seconds: TimeInterval? {
        switch self {
        case .manual: nil
        case .oneMinute: 60
        case .twoMinutes: 120
        case .fiveMinutes: 300
        case .fifteenMinutes: 900
        }
    }

    var label: String {
        switch self {
        case .manual: "Manual"
        case .oneMinute: "1 min"
        case .twoMinutes: "2 min"
        case .fiveMinutes: "5 min"
        case .fifteenMinutes: "15 min"
        }
    }
}

enum UsageMetricDisplayMode: String, CaseIterable, Identifiable {
    case barsAndPercent
    case barsOnly
    case percentOnly

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .barsAndPercent: "Bars + %"
        case .barsOnly: "Bars"
        case .percentOnly: "%"
        }
    }

    var showsBars: Bool {
        switch self {
        case .barsAndPercent, .barsOnly:
            true
        case .percentOnly:
            false
        }
    }

    var showsPercent: Bool {
        switch self {
        case .barsAndPercent, .percentOnly:
            true
        case .barsOnly:
            false
        }
    }
}

enum MenuMode: String, CaseIterable, Identifiable {
    case glance
    case analyst
    case `operator`

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .glance:
            "Glance"
        case .analyst:
            "Analyst"
        case .operator:
            "Operator"
        }
    }
}

enum ChartStyle: String, CaseIterable, Identifiable {
    case line
    case area
    case bar

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .line: "Line"
        case .area: "Area"
        case .bar: "Bar"
        }
    }
}

enum NumberFormat: String, CaseIterable, Identifiable {
    case abbreviated
    case full

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .abbreviated: "Abbreviated"
        case .full: "Full"
        }
    }
}

enum DateFormat: String, CaseIterable, Identifiable {
    case relative
    case absolute

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .relative: "Relative"
        case .absolute: "Absolute"
        }
    }
}

enum Theme: String, CaseIterable, Identifiable {
    case retro
    case system
    case light
    case dark
    case daybreak
    case glass
    case terminal

    /// The signature look — parchment + navy bevels, System-7 chrome with
    /// modern info architecture. New installs land here.
    static let `default`: Theme = .retro

    /// Raw values that used to exist and are now retired. Migration code in
    /// `SettingsStore.normalizeStoredTheme` rewrites these on load.
    static let retiredRawValues: Set<String> = ["pine", "nocturne", "prism"]

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .retro: "Retro"
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .daybreak: "Daybreak"
        case .glass: "Glass"
        case .terminal: "Terminal"
        }
    }
}

enum ProviderSwitcherLayout: String, CaseIterable, Identifiable {
    case top
    case sidebar

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .top: "Top"
        case .sidebar: "Sidebar"
        }
    }
}

enum ProviderSwitcherIconSize: String, CaseIterable, Identifiable {
    case small
    case medium

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        }
    }
}
