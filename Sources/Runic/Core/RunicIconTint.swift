import SwiftUI

enum RunicIconIntent {
    case action
    case data
    case destructive
    case info
    case navigation
    case statusGood
    case statusWarning
}

extension RunicThemePalette {
    func iconColor(
        forSystemImage systemImage: String?,
        selected: Bool = false,
        hovered: Bool = false)
        -> Color
    {
        self.iconColor(
            for: Self.iconIntent(forSystemImage: systemImage),
            systemImage: systemImage,
            selected: selected,
            hovered: hovered)
    }

    func iconColor(
        for intent: RunicIconIntent,
        systemImage: String? = nil,
        selected: Bool = false,
        hovered: Bool = false)
        -> Color
    {
        if self.isTerminalHUD {
            return self.terminalIconColor(for: intent, selected: selected, hovered: hovered)
        }

        switch intent {
        case .action:
            return selected || hovered ? self.accent : self.subduedSecondaryText
        case .data:
            return self.dataIconColor(forSystemImage: systemImage, selected: selected)
        case .destructive:
            return self.dangerIconColor
        case .info:
            return self.infoIconColor
        case .navigation:
            return selected ? self.accent : self.secondaryText
        case .statusGood:
            return self.successIconColor
        case .statusWarning:
            return self.warningIconColor
        }
    }

    static func iconIntent(forSystemImage systemImage: String?) -> RunicIconIntent {
        guard let name = systemImage else { return .action }
        if name.contains("trash") { return .destructive }
        if name.contains("exclamationmark") || name.contains("bell.badge") { return .statusWarning }
        if name.contains("checkmark") { return .statusGood }
        if name.contains("info") || name.contains("book") || name.contains("questionmark") { return .info }
        if name.contains("chevron") || name.contains("arrow.up.right") { return .navigation }
        if Self.dataIconNames.contains(name) || Self.dataIconPrefixes.contains(where: name.contains) {
            return .data
        }
        return .action
    }

    private static let dataIconNames: Set<String> = [
        "calendar", "clock", "curlybraces", "folder", "gauge.with.dots.needle.67percent",
        "rectangle.split.2x1", "server.rack", "speedometer", "tablecells",
    ]

    private static let dataIconPrefixes = [
        "chart", "cpu", "externaldrive", "paperplane", "waveform",
    ]

    private func dataIconColor(forSystemImage systemImage: String?, selected: Bool) -> Color {
        switch systemImage {
        case "tablecells":
            return self.successIconColor
        case "curlybraces", "cpu":
            return self.purpleIconColor
        case "calendar", "clock":
            return self.blueIconColor
        case "folder":
            return self.goldIconColor
        default:
            return selected ? self.accent : self.accent.opacity(self.id == "retro" ? 0.86 : 0.92)
        }
    }

    private func terminalIconColor(
        for intent: RunicIconIntent,
        selected: Bool,
        hovered: Bool)
        -> Color
    {
        switch intent {
        case .destructive:
            return self.warm
        case .statusWarning:
            return self.highlight
        case .info:
            return hovered || selected ? self.secondary : self.tertiary
        case .statusGood:
            return self.accent
        case .action, .data, .navigation:
            return selected || hovered ? self.accent : self.readableSecondaryText
        }
    }

    private var blueIconColor: Color {
        self.id == "retro" ? Color(red: 0.245, green: 0.365, blue: 0.620) : Color(red: 0.180, green: 0.450, blue: 0.940)
    }

    private var dangerIconColor: Color {
        self.id == "retro" ? Color(red: 0.730, green: 0.290, blue: 0.210) : Color(red: 0.930, green: 0.230, blue: 0.270)
    }

    private var goldIconColor: Color {
        self.id == "retro" ? Color(red: 0.615, green: 0.430, blue: 0.155) : Color(red: 0.920, green: 0.560, blue: 0.120)
    }

    private var infoIconColor: Color {
        self.id == "retro" ? self.blueIconColor : Color(red: 0.120, green: 0.520, blue: 0.900)
    }

    private var purpleIconColor: Color {
        self.id == "retro" ? Color(red: 0.450, green: 0.330, blue: 0.670) : Color(red: 0.560, green: 0.310, blue: 0.920)
    }

    private var successIconColor: Color {
        self.id == "retro" ? Color(red: 0.265, green: 0.520, blue: 0.380) : Color(red: 0.060, green: 0.610, blue: 0.380)
    }

    private var warningIconColor: Color {
        self.id == "retro" ? Color(red: 0.780, green: 0.410, blue: 0.220) : Color(red: 0.950, green: 0.610, blue: 0.150)
    }
}
