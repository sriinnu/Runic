import SwiftUI
import WidgetKit

@main
struct RunicWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunicSwitcherWidget()
        RunicUsageWidget()
        RunicHistoryWidget()
        RunicCompactWidget()
    }
}

struct RunicSwitcherWidget: Widget {
    private let kind = "RunicSwitcherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: RunicSwitcherTimelineProvider())
        { entry in
            RunicSwitcherWidgetView(entry: entry)
        }
        .configurationDisplayName("Runic Switcher")
        .description("Usage widget with a provider switcher.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct RunicUsageWidget: Widget {
    private let kind = "RunicUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: RunicTimelineProvider())
        { entry in
            RunicUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("Runic Usage")
        .description("Session and weekly usage with credits and costs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct RunicHistoryWidget: Widget {
    private let kind = "RunicHistoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: RunicTimelineProvider())
        { entry in
            RunicHistoryWidgetView(entry: entry)
        }
        .configurationDisplayName("Runic History")
        .description("Usage history chart with recent totals.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct RunicCompactWidget: Widget {
    private let kind = "RunicCompactWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: CompactMetricSelectionIntent.self,
            provider: RunicCompactTimelineProvider())
        { entry in
            RunicCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("Runic Metric")
        .description("Compact widget for credits or cost.")
        .supportedFamilies([.systemSmall])
    }
}
