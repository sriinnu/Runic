import SwiftUI
import ActivityKit
import WidgetKit
import RunicCore

// MARK: - Live Activity Attributes

/// Attributes for Runic Live Activities
///
/// Defines the static and dynamic data for Live Activities showing active AI sessions.
struct RunicLiveActivityAttributes: ActivityAttributes {
    /// Static data that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        /// Current provider being used
        var provider: UsageProvider

        /// Provider display name
        var providerName: String

        /// Current usage percentage
        var usedPercent: Double

        /// Remaining percentage
        var remainingPercent: Double

        /// Session start time
        var sessionStartTime: Date

        /// Total tokens used in session (if available)
        var sessionTokens: Int?

        /// Estimated cost in USD (if available)
        var estimatedCost: Double?

        /// Reset time for the current window
        var resetsAt: Date?

        /// Session status
        var status: SessionStatus

        public enum SessionStatus: String, Codable {
            case active = "active"
            case paused = "paused"
            case nearLimit = "near_limit"
            case complete = "complete"
        }
    }

    /// Provider color for branding
    var providerColor: ProviderColorData

    /// Session identifier
    var sessionID: String

    /// Activity title
    var activityTitle: String
}

// MARK: - Live Activity Widget

/// Live Activity widget for active AI sessions
///
/// Shows real-time usage updates during active coding sessions.
@available(iOS 16.1, *)
struct RunicLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunicLiveActivityAttributes.self) { context in
            // Lock screen / banner UI
            LiveActivityView(context: context)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimal(context: context)
            }
            .keylineTint(providerColor(context: context))
        }
    }

    // MARK: - Lock Screen / Banner Views

    @ViewBuilder
    func LiveActivityView(context: ActivityViewContext<RunicLiveActivityAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                Circle().fill(providerColor(context: context)).frame(width: 10, height: 10)
                Text(context.state.providerName).font(RunicFont.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Spacer()
                statusBadge(for: context.state.status)
            }

            VStack(spacing: 6) {
                HStack {
                    Text("Session Usage").font(RunicFont.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(Int(context.state.remainingPercent))% remaining").font(RunicFont.system(size: 12, weight: .semibold)).foregroundColor(.white)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.15))
                        RoundedRectangle(cornerRadius: 4).fill(usageGradient(for: context.state.usedPercent))
                            .frame(width: geometry.size.width * (context.state.usedPercent / 100))
                    }
                }
                .frame(height: 8)
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill").font(RunicFont.system(size: 10)).foregroundColor(.white.opacity(0.6))
                    Text(sessionDuration(from: context.state.sessionStartTime)).font(RunicFont.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                if let tokens = context.state.sessionTokens {
                    HStack(spacing: 4) {
                        Image(systemName: "number").font(RunicFont.system(size: 10)).foregroundColor(.white.opacity(0.6))
                        Text(UsageFormatter.tokenCountString(tokens)).font(RunicFont.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.8))
                    }
                }
                if let cost = context.state.estimatedCost {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill").font(RunicFont.system(size: 10)).foregroundColor(.white.opacity(0.6))
                        Text(UsageFormatter.usdString(cost)).font(RunicFont.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }

    // MARK: - Dynamic Island Views

    @ViewBuilder
    func expandedLeading(context: ActivityViewContext<RunicLiveActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(context.state.providerName)
                .font(RunicFont.system(size: 14, weight: .semibold))

            Text(sessionDuration(from: context.state.sessionStartTime))
                .font(RunicFont.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    func expandedTrailing(context: ActivityViewContext<RunicLiveActivityAttributes>) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(Int(context.state.remainingPercent))%")
                .font(RunicFont.system(size: 18, weight: .bold))

            Text("remaining")
                .font(RunicFont.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    func expandedCenter(context: ActivityViewContext<RunicLiveActivityAttributes>) -> some View {
        EmptyView()
    }

    @ViewBuilder
    func expandedBottom(context: ActivityViewContext<RunicLiveActivityAttributes>) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(usageGradient(for: context.state.usedPercent))
                        .frame(width: geometry.size.width * (context.state.usedPercent / 100))
                }
            }
            .frame(height: 6)

            HStack {
                if let tokens = context.state.sessionTokens { statItem(icon: "number", value: UsageFormatter.tokenCountString(tokens)) }
                if let cost = context.state.estimatedCost { statItem(icon: "dollarsign.circle", value: UsageFormatter.usdString(cost)) }
                Spacer()
            }
            .font(RunicFont.system(size: 11))
        }
    }

    @ViewBuilder
    func compactLeading(context: ActivityViewContext<RunicLiveActivityAttributes>) -> some View {
        Circle()
            .fill(providerColor(context: context))
            .frame(width: 8, height: 8)
    }

    @ViewBuilder
    func compactTrailing(context: ActivityViewContext<RunicLiveActivityAttributes>) -> some View {
        Text("\(Int(context.state.remainingPercent))%")
            .font(RunicFont.system(size: 12, weight: .bold))
    }

    @ViewBuilder
    func minimal(context: ActivityViewContext<RunicLiveActivityAttributes>) -> some View {
        Circle()
            .fill(providerColor(context: context))
            .frame(width: 8, height: 8)
    }

    // MARK: - Helper Views & Methods

    private func statusBadge(for status: RunicLiveActivityAttributes.ContentState.SessionStatus) -> some View {
        let (text, color, icon) = status == .active ? ("Active", Color.green, "play.circle.fill") :
            status == .paused ? ("Paused", Color.orange, "pause.circle.fill") :
            status == .nearLimit ? ("Near Limit", Color.red, "exclamationmark.circle.fill") :
            ("Complete", Color.blue, "checkmark.circle.fill")

        return HStack(spacing: 4) {
            Image(systemName: icon).font(RunicFont.system(size: 10))
            Text(text).font(RunicFont.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.2))
        .clipShape(Capsule())
    }

    private func statItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(RunicFont.system(size: 10)).foregroundColor(.secondary)
            Text(value).font(RunicFont.system(size: 11, weight: .medium))
        }
    }

    private func sessionDuration(from startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func usageGradient(for usedPercent: Double) -> LinearGradient {
        let color: Color = usedPercent < 60 ? .green : usedPercent < 80 ? .yellow : usedPercent < 95 ? .orange : .red
        return LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
    }

    private func providerColor(context: ActivityViewContext<RunicLiveActivityAttributes>) -> Color {
        Color(red: context.attributes.providerColor.red, green: context.attributes.providerColor.green, blue: context.attributes.providerColor.blue)
    }
}

// MARK: - Live Activity Manager

/// Manager for starting and updating Live Activities
@available(iOS 16.1, *)
public enum RunicLiveActivityManager {
    /// Start a new Live Activity for a coding session
    public static func startActivity(
        provider: UsageProvider,
        providerName: String,
        providerColor: ProviderColorData,
        usedPercent: Double
    ) async throws -> String {
        let attributes = RunicLiveActivityAttributes(
            providerColor: providerColor,
            sessionID: UUID().uuidString,
            activityTitle: "\(providerName) Session"
        )

        let initialState = RunicLiveActivityAttributes.ContentState(
            provider: provider,
            providerName: providerName,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            sessionStartTime: Date(),
            sessionTokens: nil,
            estimatedCost: nil,
            resetsAt: nil,
            status: .active
        )

        let activity = try Activity.request(
            attributes: attributes,
            contentState: initialState,
            pushType: nil
        )

        return activity.id
    }

    /// Update an existing Live Activity
    public static func updateActivity(
        activityID: String,
        usedPercent: Double,
        sessionTokens: Int?,
        estimatedCost: Double?,
        status: RunicLiveActivityAttributes.ContentState.SessionStatus
    ) async {
        for activity in Activity<RunicLiveActivityAttributes>.activities where activity.id == activityID {
            let updatedState = RunicLiveActivityAttributes.ContentState(
                provider: activity.contentState.provider,
                providerName: activity.contentState.providerName,
                usedPercent: usedPercent,
                remainingPercent: 100 - usedPercent,
                sessionStartTime: activity.contentState.sessionStartTime,
                sessionTokens: sessionTokens,
                estimatedCost: estimatedCost,
                resetsAt: activity.contentState.resetsAt,
                status: status
            )

            await activity.update(using: updatedState)
        }
    }

    /// End a Live Activity
    public static func endActivity(activityID: String) async {
        for activity in Activity<RunicLiveActivityAttributes>.activities where activity.id == activityID {
            await activity.end(dismissalPolicy: .default)
        }
    }

    /// End all active Runic Live Activities
    public static func endAllActivities() async {
        for activity in Activity<RunicLiveActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
