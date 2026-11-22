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
    case system
    case dark
    case glass
    case atelier
    case meridian
    case relief
    case sumi
    case blueprint
    case terminal
    case gazette
    case flightdeck
    case departures

    /// Adaptive optical Liquid Glass — follows macOS light/dark out of the box.
    static let `default`: Theme = .glass

    /// Raw values that used to exist and are now retired. Migration code in
    /// `SettingsStore+DefaultsSnapshot` rewrites these on load via
    /// `migrated(fromRetired:)`.
    static let retiredRawValues: Set<String> = [
        "pine",
        "nocturne",
        "prism",
        "light",
        "daybreak",
        "noir",
        "retro",
        "receipt",
        "yantra",
    ]

    /// Nearest living theme for a retired one: the two light themes land on
    /// Sumi (the light theme with a point of view), the old dark ones on
    /// Blueprint, the prism showpiece on Glass, Retro on Relief, Receipt on
    /// Gazette, Yantra on Meridian, and anything else on the default.
    static func migrated(fromRetired raw: String) -> Theme {
        switch raw {
        case "light", "daybreak": .sumi
        case "nocturne", "noir": .blueprint
        case "prism": .glass
        case "retro": .relief
        case "receipt": .gazette
        case "yantra": .meridian
        default: .default
        }
    }

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .glass: "Glass"
        case .atelier: "Atelier"
        case .meridian: "Meridian"
        case .relief: "Relief"
        case .sumi: "Sumi"
        case .blueprint: "Blueprint"
        case .terminal: "Terminal"
        case .gazette: "Gazette"
        case .flightdeck: "Flight deck"
        case .departures: "Departures"
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
